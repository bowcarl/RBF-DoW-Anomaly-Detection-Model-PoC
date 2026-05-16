"""
fingerprint_aggregator.py  [WITH MITIGATION — THESIS FINAL]
────────────────────────────────────────────────────────────
Collects 5-minute CloudWatch telemetry, engineers relational features,
scores the window with Isolation Forest, sends SNS alerts, and applies
ratio-triggered adaptive throttling when an ALERT is detected.

MITIGATION STRATEGY:
    When the IF score crosses the ALERT threshold, reserved concurrency
    is reduced on the most expensive Lambda functions (checkout, cart).
    This stops the bot's high-cost calls at the AWS layer without touching
    application code or blocking legitimate low-cost traffic (login, search).

    On the next NORMAL-scoring window, concurrency is restored automatically.

    Novel contribution: the throttle target and trigger are both derived
    from cross-function relational anomaly — not absolute volume.

CONFIGURATION (edit these at the top, no logic changes needed):
    MITIGATION_DRY_RUN        — True = log only, no real throttling
    MITIGATION_TARGETS        — which functions to throttle and how much
    CLEAR_WINDOWS_REQUIRED    — clean windows before lifting throttle
    ALERT_SCORE_THRESHOLD     — score below which mitigation fires

TESTING:
    Pass {"test_override_score": -0.700, "test_override_tier": "ALERT"}
    as the Lambda event payload to simulate an ALERT without real traffic.
"""

import json
import math
import os
import boto3
import tempfile
import numpy as np
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from decimal import Decimal
import pickle
import sklearn
print(f"sklearn version: {sklearn.__version__}")

cloudwatch   = boto3.client('cloudwatch')
dynamodb_res = boto3.resource('dynamodb')
lambda_client = boto3.client('lambda')
s3           = boto3.client('s3')
sns          = boto3.client('sns')
table        = dynamodb_res.Table('fingerprints')
mitigation_table = dynamodb_res.Table('MitigationLog')

FUNCTIONS = ['login', 'search', 'product', 'cart', 'checkout']
MEMORY_MB = {'login': 128, 'search': 256, 'product': 256,
             'cart': 256, 'checkout': 512}
LAMBDA_PRICE_PER_GB_SECOND = 0.0000166667

SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
MODEL_BUCKET  = os.environ.get('MODEL_BUCKET', '')

MIN_INVOCATIONS_FOR_RATIOS = 100
DELTA_CLIP                 = 1000
WARNING_MARGIN             = 0.04

IF_FEATURE_KEYS = [
    'checkoutToLoginRatio_stable',
    'cartToSearchRatio_stable',
    'highValuePressure_stable',
    'highMemFraction',
    'log_totalEstimatedCost',
    'log_totalInvocations',
    'invocationEntropy',
    'hour_of_day',
    'deltaTotalInvocations_clipped',
    'isActive',
]

# ══════════════════════════════════════════════════════════════════
# MITIGATION CONFIGURATION
# Edit this block to adapt to a different application.
# No changes needed anywhere else.
# ══════════════════════════════════════════════════════════════════

# Set True during development/testing — logs decisions but makes no
# real AWS API calls. Set False for live mitigation.
MITIGATION_DRY_RUN = False

# How many consecutive NORMAL windows before throttle is lifted.
# 1 = lift after one clean window (responsive)
# 2 = more conservative, reduces flapping on borderline alerts
CLEAR_WINDOWS_REQUIRED = 1

# IF score below which mitigation fires (must be in ALERT tier).
# Matches your trained model's offset_ threshold.
ALERT_SCORE_THRESHOLD = -0.660

# Functions to throttle on ALERT, ordered most expensive first.
# throttle_to = reserved concurrency during alert window.
# To adopt for a different app: replace these entries only.
MITIGATION_TARGETS = [
    {
        'function_name': 'checkout',
        'throttle_to':   10,
        'cost_weight':   4.0,
        'description':   '512MB checkout — highest billing cost per call',
    },
    {
        'function_name': 'cart',
        'throttle_to':   20,
        'cost_weight':   2.0,
        'description':   '256MB cart — second highest billing cost',
    },
]

# ── In-memory mitigation state ────────────────────────────────────
# Resets on Lambda cold start — acceptable since the DynamoDB log
# provides the durable record and cold starts during attacks are rare.
_consecutive_normal_windows = 0
_currently_throttled        = False

# ══════════════════════════════════════════════════════════════════
# MODEL LOADING
# ══════════════════════════════════════════════════════════════════

_iso_forest = None
_scaler     = None


def load_model():
    global _iso_forest, _scaler
    if _iso_forest is not None and _scaler is not None:
        return _iso_forest, _scaler

    print("Loading model from S3 (cold start)...")
    tmp         = tempfile.gettempdir()
    model_path  = os.path.join(tmp, 'if_model_v2.pkl')
    scaler_path = os.path.join(tmp, 'scaler_v2.pkl')

    for p in [model_path, scaler_path]:
        if os.path.exists(p):
            os.remove(p)

    s3.download_file(MODEL_BUCKET, 'isolation_forest_baseline.pkl', model_path)
    print(f"Downloaded model: {os.path.getsize(model_path)} bytes")

    s3.download_file(MODEL_BUCKET, 'scaler_baseline.pkl', scaler_path)
    print(f"Downloaded scaler: {os.path.getsize(scaler_path)} bytes")

    with open(model_path,  'rb') as f: _iso_forest = pickle.load(f)
    with open(scaler_path, 'rb') as f: _scaler     = pickle.load(f)

    print("Model loaded successfully.")
    return _iso_forest, _scaler

# ══════════════════════════════════════════════════════════════════
# CLOUDWATCH HELPERS
# ══════════════════════════════════════════════════════════════════

def get_metric(fn, metric_name, stat, period, start, end):
    try:
        resp = cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName=metric_name,
            Dimensions=[{'Name': 'FunctionName', 'Value': fn}],
            StartTime=start, EndTime=end,
            Period=period, Statistics=[stat],
        )
        dps = resp.get('Datapoints', [])
        return sum(dp[stat] for dp in dps) if dps else 0
    except Exception as e:
        print(f"ERROR getting {metric_name} for {fn}: {e}")
        return 0


def estimate_cost(invocations, avg_duration_ms, memory_mb):
    gb_seconds = (memory_mb / 1024) * (avg_duration_ms / 1000) * invocations
    return gb_seconds * LAMBDA_PRICE_PER_GB_SECOND


def compute_entropy(counts):
    total = sum(counts)
    if total == 0:
        return 0.0
    probs = [c / total for c in counts]
    return -sum(p * math.log2(p) for p in probs if p > 0)

# ══════════════════════════════════════════════════════════════════
# ISOLATION FOREST SCORING
# ══════════════════════════════════════════════════════════════════

def score_window(fp, delta_inv, iso_forest, scaler):
    total_inv      = float(fp['totalInvocations'])
    stable         = total_inv >= MIN_INVOCATIONS_FOR_RATIOS
    checkout_ratio = float(fp['checkoutToLoginRatio'])
    cart_ratio     = float(fp['cartToSearchRatio'])
    hmf            = float(fp['highMemFraction'])
    cost           = float(fp['totalEstimatedCost'])
    entropy        = float(fp['invocationEntropy'])
    hour           = float(fp['hour_of_day'])

    features = {
        'checkoutToLoginRatio_stable': checkout_ratio if stable else 0.0,
        'cartToSearchRatio_stable':    cart_ratio     if stable else 0.0,
        'highValuePressure_stable':    (checkout_ratio * hmf) if stable else 0.0,
        'highMemFraction':             hmf,
        'log_totalEstimatedCost':      np.log1p(cost * 1e8),
        'log_totalInvocations':        np.log1p(total_inv),
        'invocationEntropy':           entropy,
        'hour_of_day':                 hour,
        'deltaTotalInvocations_clipped': max(-DELTA_CLIP, min(DELTA_CLIP, delta_inv)),
        'isActive':                    1.0 if total_inv > 0 else 0.0,
    }

    X         = np.array([[features[k] for k in IF_FEATURE_KEYS]])
    X_scaled  = scaler.transform(X)
    score     = float(iso_forest.score_samples(X_scaled)[0])
    threshold = iso_forest.offset_
    warn_thr  = threshold + WARNING_MARGIN

    if score < threshold:
        tier = 'ALERT'
    elif score < warn_thr:
        tier = 'WARNING'
    else:
        tier = 'NORMAL'

    return score, tier, threshold

# ══════════════════════════════════════════════════════════════════
# SNS ALERTING
# ══════════════════════════════════════════════════════════════════

TEST_MODE = True
def publish_alert(fp, tier, score, threshold, window_start):
    if TEST_MODE:
        print(f"TEST_MODE — skipping SNS: {tier} score={score:.4f}")
        return

    if tier == 'NORMAL' or not SNS_TOPIC_ARN:
        return

    checkout_ratio = float(fp['checkoutToLoginRatio'])
    total_inv      = float(fp['totalInvocations'])
    cost           = float(fp['totalEstimatedCost'])

    subject = f"[{tier}] DoW Anomaly Detected — {window_start}"
    message = (
        f"{tier}: Behavioural anomaly detected.\n\n"
        f"Window      : {window_start}\n"
        f"Score       : {score:.4f}  (threshold {threshold:.4f})\n"
        f"Invocations : {total_inv:.0f}\n"
        f"Checkout/Login Ratio: {checkout_ratio:.3f}\n"
        f"Window Cost : ${cost:.8f}\n"
        f"Mitigation  : {'DRY RUN' if MITIGATION_DRY_RUN else 'ACTIVE'}"
    )

    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message,
            MessageAttributes={
                'tier':        {'DataType': 'String', 'StringValue': tier},
                'anomalyScore':{'DataType': 'Number',
                                'StringValue': str(round(score, 6))},
            },
        )
        print(f"SNS published: {tier} — window {window_start}")
    except Exception as e:
        print(f"ERROR publishing SNS: {e}")

# ══════════════════════════════════════════════════════════════════
# MITIGATION ENGINE
# ══════════════════════════════════════════════════════════════════

def evaluate_and_mitigate(if_score: float,
                           ratio_features: dict,
                           window_ts: str):
    """
    Called on every window after scoring.
    Applies or lifts throttle based on IF score and in-memory state.

    ratio_features is logged to DynamoDB for evaluation and plotting.
    It should contain the key relational features that triggered the decision,
    e.g. {'checkoutToLoginRatio': 0.41, 'cartToSearchRatio': 0.18}
    """
    global _consecutive_normal_windows, _currently_throttled

    if if_score < ALERT_SCORE_THRESHOLD:
        # ── ALERT: apply throttle ─────────────────────────────────
        _consecutive_normal_windows = 0
        _apply_throttle(if_score, ratio_features, window_ts)

    else:
        # ── NORMAL or WARNING: count clean windows ────────────────
        if _currently_throttled:
            _consecutive_normal_windows += 1
            print(f"[mitigation] Clean window "
                  f"{_consecutive_normal_windows}/{CLEAR_WINDOWS_REQUIRED}")

            if _consecutive_normal_windows >= CLEAR_WINDOWS_REQUIRED:
                _lift_throttle(window_ts)
                _consecutive_normal_windows = 0
        else:
            print(f"[mitigation] Window NORMAL — no throttle active.")


def _apply_throttle(if_score: float, ratio_features: dict, window_ts: str):
    global _currently_throttled

    if _currently_throttled:
        print("[mitigation] Throttle already active — maintaining.")
        _log_mitigation('THROTTLE_MAINTAINED', if_score,
                        ratio_features, window_ts)
        return

    failures = []
    for target in MITIGATION_TARGETS:
        fn  = target['function_name']
        lvl = target['throttle_to']

        if MITIGATION_DRY_RUN:
            print(f"[mitigation DRY RUN] Would throttle {fn} → {lvl}")
        else:
            try:
                lambda_client.put_function_concurrency(
                    FunctionName=fn,
                    ReservedConcurrentExecutions=lvl
                )
                print(f"[mitigation] THROTTLED {fn} → {lvl} concurrent executions")
            except Exception as e:
                print(f"[mitigation] ERROR throttling {fn}: {e}")
                failures.append(fn)

    _currently_throttled = len(failures) < len(MITIGATION_TARGETS)
    _log_mitigation('THROTTLE_APPLIED', if_score, ratio_features,
                    window_ts, failures)


def _lift_throttle(window_ts: str):
    global _currently_throttled

    failures = []
    for target in MITIGATION_TARGETS:
        fn = target['function_name']

        if MITIGATION_DRY_RUN:
            print(f"[mitigation DRY RUN] Would restore {fn} → unrestricted")
        else:
            try:
                lambda_client.delete_function_concurrency(FunctionName=fn)
                print(f"[mitigation] RESTORED {fn} → unrestricted")
            except Exception as e:
                print(f"[mitigation] ERROR restoring {fn}: {e}")
                failures.append(fn)

    _currently_throttled = len(failures) > 0
    _log_mitigation('THROTTLE_LIFTED', 0.0, {}, window_ts, failures)


def _log_mitigation(event_type: str,
                    if_score: float,
                    ratio_features: dict,
                    window_ts: str,
                    failed_targets: list = None):
    """Write every mitigation decision to DynamoDB for thesis evaluation."""
    item = {
        'timestamp':   window_ts,
        'event_type':  event_type,
        'if_score':    str(round(if_score, 4)),
        'dry_run':     str(MITIGATION_DRY_RUN),
        'targets':     str([t['function_name'] for t in MITIGATION_TARGETS]),
        'failed':      str(failed_targets or []),
    }
    for feature_name, value in ratio_features.items():
        item[feature_name] = str(round(float(value), 4))

    try:
        mitigation_table.put_item(Item=item)
        print(f"[mitigation] Logged {event_type} to MitigationLog")
    except Exception as e:
        print(f"[mitigation] DynamoDB log failed: {e}")

# ══════════════════════════════════════════════════════════════════
# LAMBDA HANDLER
# ══════════════════════════════════════════════════════════════════

def lambda_handler(event, context):

    # ── Test override: inject a fake score to test mitigation ─────
    # Pass {"test_override_score": -0.700, "test_override_tier": "ALERT"}
    # as the event payload to test mitigation without real traffic.
    test_score = event.get('test_override_score', None)
    test_tier  = event.get('test_override_tier',  None)

    norway           = ZoneInfo("Europe/Oslo")
    end_time_local   = datetime.now(norway).replace(second=0, microsecond=0)
    start_time_local = end_time_local - timedelta(minutes=5)
    end_time_utc     = end_time_local.astimezone(ZoneInfo("UTC"))
    start_time_utc   = start_time_local.astimezone(ZoneInfo("UTC"))
    period           = 300

    try:
        iso_forest, scaler = load_model()
    except Exception as e:
        print(f"Model load failed: {e}")
        return {'statusCode': 500, 'body': f"Model load failed: {e}"}

    # ── Collect CloudWatch metrics ────────────────────────────────
    func_data = {}
    for fn in FUNCTIONS:
        inv  = get_metric(fn, 'Invocations', 'Sum',
                          period, start_time_utc, end_time_utc)
        dur  = get_metric(fn, 'Duration',    'Sum',
                          period, start_time_utc, end_time_utc)
        avg  = (dur / inv) if inv > 0 else 0.0
        cost = estimate_cost(inv, avg, MEMORY_MB[fn])
        func_data[fn] = {
            'invocations':   Decimal(str(inv)),
            'avgDurationMs': Decimal(str(round(avg, 2))),
            'estimatedCost': Decimal(str(round(cost, 8))),
        }

    counts       = [float(func_data[fn]['invocations']) for fn in FUNCTIONS]
    total_inv    = sum(counts)
    high_mem_inv = float(func_data['cart']['invocations'] +
                         func_data['checkout']['invocations'])
    login_inv    = float(func_data['login']['invocations'])
    checkout_inv = float(func_data['checkout']['invocations'])
    search_inv   = float(func_data['search']['invocations'])
    cart_inv     = float(func_data['cart']['invocations'])
    total_cost   = sum(float(func_data[fn]['estimatedCost']) for fn in FUNCTIONS)

    prev_window_start = (start_time_local - timedelta(minutes=5)).isoformat()
    try:
        prev_item  = table.get_item(
            Key={'windowStart': prev_window_start}).get('Item')
        prev_total = float(prev_item['totalInvocations']) if prev_item else total_inv
    except Exception:
        prev_total = total_inv
    delta_total_inv = total_inv - prev_total

    checkout_ratio = round(checkout_inv / login_inv, 4) if login_inv > 0 else 0.0
    cart_ratio     = round(cart_inv / search_inv, 4)    if search_inv > 0 else 0.0
    high_mem_frac  = round(high_mem_inv / total_inv, 4) if total_inv > 0 else 0.0
    entropy        = compute_entropy(counts)
    hour           = start_time_local.hour
    is_night       = hour < 6 or hour >= 22

    fingerprint = {
        'windowStart':           start_time_local.isoformat(),
        'windowEnd':             end_time_local.isoformat(),
        'checkoutToLoginRatio':  Decimal(str(checkout_ratio)),
        'cartToSearchRatio':     Decimal(str(cart_ratio)),
        'highMemFraction':       Decimal(str(high_mem_frac)),
        'totalInvocations':      Decimal(str(total_inv)),
        'deltaTotalInvocations': Decimal(str(round(delta_total_inv, 2))),
        'totalEstimatedCost':    Decimal(str(round(total_cost, 8))),
        'invocationEntropy':     Decimal(str(round(entropy, 4))),
        'hour_of_day':           hour,
        'isNight':               is_night,
        'invocations_login':     func_data['login']['invocations'],
        'invocations_search':    func_data['search']['invocations'],
        'invocations_product':   func_data['product']['invocations'],
        'invocations_cart':      func_data['cart']['invocations'],
        'invocations_checkout':  func_data['checkout']['invocations'],
        'avgDurationMs_login':   func_data['login']['avgDurationMs'],
        'avgDurationMs_search':  func_data['search']['avgDurationMs'],
        'avgDurationMs_product': func_data['product']['avgDurationMs'],
        'avgDurationMs_cart':    func_data['cart']['avgDurationMs'],
        'avgDurationMs_checkout':func_data['checkout']['avgDurationMs'],
        'estimatedCost_login':   func_data['login']['estimatedCost'],
        'estimatedCost_search':  func_data['search']['estimatedCost'],
        'estimatedCost_product': func_data['product']['estimatedCost'],
        'estimatedCost_cart':    func_data['cart']['estimatedCost'],
        'estimatedCost_checkout':func_data['checkout']['estimatedCost'],
    }

    # ── Score window (or use test override) ───────────────────────
    try:
        if test_score is not None and test_tier is not None:
            score     = float(test_score)
            tier      = test_tier
            threshold = iso_forest.offset_
            print(f"[TEST OVERRIDE] score={score:.4f}  tier={tier}")
        else:
            score, tier, threshold = score_window(
                fingerprint, delta_total_inv, iso_forest, scaler)

        fingerprint['anomalyScore'] = Decimal(str(round(score, 6)))
        fingerprint['anomalyTier']  = tier
        print(f"Window {fingerprint['windowStart']} "
              f"— score={score:.4f}  tier={tier}")

        # ── SNS alert (existing behaviour) ───────────────────────
        publish_alert(fingerprint, tier, score, threshold,
                      fingerprint['windowStart'])

        # ── Mitigation (new) ─────────────────────────────────────
        evaluate_and_mitigate(
            if_score       = score,
            ratio_features = {
                'checkoutToLoginRatio': checkout_ratio,
                'cartToSearchRatio':    cart_ratio,
            },
            window_ts      = fingerprint['windowStart'],
        )

    except Exception as e:
        print(f"Scoring/mitigation failed: {e}")

    # ── Write fingerprint to DynamoDB ─────────────────────────────
    try:
        table.put_item(Item=fingerprint)
        print("Fingerprint written to DynamoDB")
    except Exception as e:
        print(f"ERROR writing fingerprint: {e}")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'window':      fingerprint['windowStart'],
            'tier':        fingerprint.get('anomalyTier', 'UNSCORED'),
            'score':       float(fingerprint.get('anomalyScore', 0)),
            'threshold':   round(iso_forest.offset_, 6),
            'throttled':   _currently_throttled,
            'dry_run':     MITIGATION_DRY_RUN,
        }),
    }
