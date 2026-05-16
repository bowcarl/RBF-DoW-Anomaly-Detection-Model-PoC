# ── at the top of your handler file, add this import ──────────────
from mitigation import evaluate_and_mitigate   # NEW

# ── inside your scoring loop, after tier is assigned ──────────────

tier  = assign_tier(if_score, if_threshold, if_warn_thr)
ts    = datetime.now(timezone.utc).isoformat()

# Existing SNS alert — unchanged
if tier == 'ALERT':
    sns_client.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Subject='DoW ALERT',
        Message=f"Anomaly score: {if_score:.4f} | "
                f"checkoutToLoginRatio: {checkout_login_ratio:.3f}"
    )

# NEW — mitigation decision (runs on every window, ALERT and NORMAL)
evaluate_and_mitigate(
    if_score       = if_score,
    ratio_features = {
        'checkoutToLoginRatio': checkout_login_ratio,
        'cartToSearchRatio':    cart_search_ratio,
    },
    window_ts      = ts
)
