"""
mitigation_analysis.py
Compares estimated cost before, during, and after mitigation
using fingerprints_mitigation.csv and mitigation_log.csv
"""

import pandas as pd
import matplotlib.pyplot as plt
import os

OUT_DIR = "thesis_plots"
os.makedirs(OUT_DIR, exist_ok=True)

# ── Load data ─────────────────────────────────────────────────────
df_fp  = pd.read_csv(r"C:\Users\carlp\Downloads\random_rate.csv") # Switch bettween leech_attack.csv and mitigation_log.csv (to see the other results)
df_mit = pd.read_csv(r"C:\Users\carlp\Downloads\mitigation_log(1).csv")

df_fp['totalEstimatedCost'] = df_fp['totalEstimatedCost'].astype(float) * 1000 # Multiplied with 1000, only for this dataset to get price per GB seconds and not per MS


df_fp = df_fp.sort_values('windowStart').reset_index(drop=True)

# ── Mark which windows had throttle active ────────────────────────
throttle_on  = set(df_mit[df_mit['event_type'].isin(
    ['THROTTLE_APPLIED', 'THROTTLE_MAINTAINED'])]['timestamp'].tolist())
throttle_off = set(df_mit[df_mit['event_type'] == 'THROTTLE_LIFTED'
    ]['timestamp'].tolist())

df_fp['throttled'] = df_fp['windowStart'].isin(throttle_on)

# ── Core metrics ──────────────────────────────────────────────────
cost_unthrottled = df_fp[~df_fp['throttled']]['totalEstimatedCost'].mean()
cost_throttled   = df_fp[ df_fp['throttled']]['totalEstimatedCost'].mean()
reduction_pct    = (1 - cost_throttled / cost_unthrottled) * 100

print("== Mitigation Evaluation Results ==")
print(f"Total windows        : {len(df_fp)}")
print(f"Throttled windows    : {df_fp['throttled'].sum()}")
print(f"Unthrottled windows  : {(~df_fp['throttled']).sum()}")
print()
print(f"Mean cost/window (unthrottled) : ${cost_unthrottled:.8f}")
print(f"Mean cost/window (throttled)   : ${cost_throttled:.8f}")
print(f"Cost reduction                 : {reduction_pct:.1f}%")

# ── Mitigation latency ────────────────────────────────────────────
first_throttle = df_mit[df_mit['event_type'] == 'THROTTLE_APPLIED'
    ]['timestamp'].min()
first_alert    = df_fp[df_fp['anomalyTier'] == 'ALERT']['windowStart'].min()

df_sorted     = df_fp.sort_values('windowStart').reset_index(drop=True)
alert_idx     = df_sorted[df_sorted['windowStart'] >= first_alert].index[0]
mitigate_idx  = df_sorted[df_sorted['windowStart'] >= first_throttle].index[0]
windows_to_mitigation = mitigate_idx - alert_idx

print()
print(f"Windows from attack start to first throttle : {windows_to_mitigation}")
print(f"Wall-clock exposure time                    : {windows_to_mitigation * 5} minutes")

# ── False throttle rate ───────────────────────────────────────────
normal_windows   = df_fp[df_fp['anomalyTier'] == 'NORMAL']['windowStart'].tolist()
false_throttles  = df_mit[
    (df_mit['event_type'] == 'THROTTLE_APPLIED') &
    (df_mit['timestamp'].isin(normal_windows))
]
false_throttle_rate = len(false_throttles) / max(len(normal_windows), 1) * 100

print()
print(f"False throttle rate : {false_throttle_rate:.2f}%")

# ── Plot: cost per window over time ───────────────────────────────
fig, ax = plt.subplots(figsize=(12, 4))

colors = ['#D0021B' if t else '#4C9BE8' for t in df_fp['throttled']]
ax.bar(range(len(df_fp)), df_fp['totalEstimatedCost'],
       color=colors, width=1.0, alpha=0.8)

ax.set_xlabel('Window index')
ax.set_ylabel('Estimated cost (USD)')
ax.yaxis.grid(True, linestyle='--', alpha=0.5)
ax.set_axisbelow(True)

from matplotlib.patches import Patch
ax.legend(handles=[
    Patch(color='#D0021B', label='Throttle active'),
    Patch(color='#4C9BE8', label='No throttle'),
], frameon=False)

plt.tight_layout()
plt.savefig(f"{OUT_DIR}/plot_mitigation_cost.eps", format='eps', bbox_inches='tight')
plt.savefig(f"{OUT_DIR}/plot_mitigation_cost.png", dpi=150, bbox_inches='tight')
plt.close()
print(f"\nPlot saved -> {OUT_DIR}/plot_mitigation_cost.eps / .png")

print()
print("Suggested caption:")
print(
    f"Estimated billing cost per 5-minute window during the 24-hour "
    f"mixed-traffic attack evaluation. Red bars indicate windows where "
    f"the mitigation system had active concurrency throttling applied to "
    f"the checkout and cart functions. Mean cost per window was reduced "
    f"by {reduction_pct:.1f}% during throttled periods. "
    f"Mitigation triggered within {windows_to_mitigation * 5} minutes "
    f"of attack onset."
)
