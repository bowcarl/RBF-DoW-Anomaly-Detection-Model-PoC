"""
retrain_baseline.py (Pickle Version)
────────────────────────────────────────────────────────────────────────────────
Retrains the Isolation Forest model and scaler using standard pickle.
Matches the loading logic in your AWS Lambda exactly.
────────────────────────────────────────────────────────────────────────────────
"""

import pandas as pd
import numpy as np
import pickle
import os
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

# ══════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════

# Point this at your NEW baseline CSV
BASELINE_CSV_PATH = r"C:\Users\carlp\Downloads\normal_new.csv"

MODEL_OUT  = "isolation_forest_baseline.pkl"
SCALER_OUT = "scaler_baseline.pkl"
STATS_OUT  = "baseline_stats.txt"

MIN_INVOCATIONS_FOR_RATIOS = 100
DELTA_CLIP                 = 1000

IF_CONTAMINATION = 0.01
IF_N_ESTIMATORS  = 200
IF_RANDOM_STATE  = 42

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
# 1. LOAD AND CLEAN
# ══════════════════════════════════════════════════════════════════

print("Loading baseline CSV...")
df = pd.read_csv(BASELINE_CSV_PATH)

# Cleanup
df = df[df['totalInvocations'] > 0].copy()
df = df[df['deltaTotalInvocations'].abs() <= 2000].copy()
df = df.fillna(0)
df['isActive'] = (df['totalInvocations'] > 0).astype(float)

# ══════════════════════════════════════════════════════════════════
# 2. FEATURE ENGINEERING
# ══════════════════════════════════════════════════════════════════

df['deltaTotalInvocations_clipped'] = df['deltaTotalInvocations'].clip(-DELTA_CLIP, DELTA_CLIP)
stable = df['totalInvocations'] >= MIN_INVOCATIONS_FOR_RATIOS

df['checkoutToLoginRatio_stable'] = np.where(stable, df['checkoutToLoginRatio'], 0.0)
df['cartToSearchRatio_stable']    = np.where(stable, df['cartToSearchRatio'],    0.0)
df['highValuePressure_stable']    = np.where(stable, df['checkoutToLoginRatio'] * df['highMemFraction'], 0.0)
df['log_totalInvocations']        = np.log1p(df['totalInvocations'])
df['log_totalEstimatedCost']      = np.log1p(df['totalEstimatedCost'].astype(float) * 1e8)

X = df[IF_FEATURE_KEYS].values

# ══════════════════════════════════════════════════════════════════
# 3. FIT & SAVE (USING PICKLE)
# ══════════════════════════════════════════════════════════════════

# --- Scaler ---
print("\nFitting scaler...")
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

with open(SCALER_OUT, 'wb') as f:
    # protocol=4 is the "sweet spot" for Python 3.8 - 3.12 compatibility
    pickle.dump(scaler, f, protocol=4)
print(f"  Scaler saved via Pickle → {SCALER_OUT}")

# --- Isolation Forest ---
print("Fitting Isolation Forest...")
iso_forest = IsolationForest(
    n_estimators  = IF_N_ESTIMATORS,
    contamination = IF_CONTAMINATION,
    random_state  = IF_RANDOM_STATE,
)
iso_forest.fit(X_scaled)

with open(MODEL_OUT, 'wb') as f:
    pickle.dump(iso_forest, f, protocol=4)
print(f"  Model saved via Pickle → {MODEL_OUT}")

# ══════════════════════════════════════════════════════════════════
# 4. STATS & VERIFICATION
# ══════════════════════════════════════════════════════════════════

print(f"\nDecision threshold (offset_): {iso_forest.offset_:.4f}")
train_scores = iso_forest.score_samples(X_scaled)
flagged = (train_scores < iso_forest.offset_).sum()
print(f"Windows flagged: {flagged} / {len(df)} ({flagged/len(df)*100:.1f}%)")

# Save stats to file (standard text processing)
with open(STATS_OUT, 'w', encoding='utf-8') as f:
    f.write(f"Mean highMemFraction: {df['highMemFraction'].mean():.4f}\n")
    f.write(f"Model Offset: {iso_forest.offset_:.4f}\n")

print(f"\nDone. Upload {MODEL_OUT} and {SCALER_OUT} to S3 bucket: {os.environ.get('MODEL_BUCKET', 'YOUR_BUCKET')}")
