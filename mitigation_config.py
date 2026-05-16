"""
mitigation_config.py
────────────────────
Defines which functions are protected and how aggressively.
Edit ONLY this file to adapt the mitigation system to a different application.

THROTTLE_TARGETS is a list of functions ordered by cost (most expensive first).
When an ALERT fires, ALL listed functions are throttled proportionally.
When the window clears, ALL are restored.

Fields per entry:
  function_name     : exact AWS Lambda function name
  throttle_to       : reserved concurrency during an alert
  cost_weight       : relative billing cost (used for logging/reporting only)
  description       : human-readable reason this function is a target
"""

MITIGATION_CONFIG = {

    # ── Alert behaviour ──────────────────────────────────────────
    # How many consecutive NORMAL windows must pass before lifting throttle.
    # 1 = lift immediately after one clean window (aggressive recovery)
    # 2 = more conservative, reduces flapping on borderline windows
    "clear_windows_required": 1,

    # ── Functions to throttle on ALERT ───────────────────────────
    # Ordered by cost descending — most expensive first.
    # For a different application: replace these entries entirely.
    "throttle_targets": [
        {
            "function_name": "checkout",
            "throttle_to":   10,        # concurrent executions during alert
            "cost_weight":   4.0,       # relative to cheapest function
            "description":   "512MB checkout — highest billing cost per call",
        },
        {
            "function_name": "cart",
            "throttle_to":   20,        # cart is cheaper so less aggressive
            "cost_weight":   2.0,
            "description":   "256MB cart — second highest billing cost",
        },
    ],

    # ── DynamoDB logging ─────────────────────────────────────────
    "mitigation_log_table": "MitigationLog",

    # ── Minimum anomaly score to trigger mitigation ───────────────
    # Throttle only fires if IF score is below this value.
    # This means WARNING tier alone does NOT trigger mitigation —
    # only ALERT does. Adjust if you want WARNING to also throttle.
    "alert_score_threshold": -0.660,
}
