"""
results_figures_v2.py
──────────────────────────────────────────────────────────────────────────────
Three output figures for the thesis Results chapter:

  plot_tpr_fpr_bars.pdf
      Grouped bar chart — TPR (left) and FPR (right) across all four attack
      scenarios. No error bars: the box plot figures handle distribution.
      Mean values shown as white bold text inside bars.
      Percentage-point difference annotated above each pair.

  plot_tpr_boxplots.pdf
      2×2 grid — one subplot per attack scenario, showing the distribution
      of TPR across N=30 runs for RBF-DoW vs Gringotts.
      Shared y-axis across all four panels for direct comparison.
      Individual run dots (jittered) overlaid on each box.

  plot_fpr_boxplots.pdf
      Same structure as above but for FPR.

Seed: BASE_SEED = 42. All sampling deterministic.
Output: .pdf (vector, pdflatex) + .png
──────────────────────────────────────────────────────────────────────────────
"""

import os
import numpy as np
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from scipy.stats import chi2, ttest_rel, mannwhitneyu
from numpy.linalg import pinv
import joblib

# ── Print dimensions ──────────────────────────────────────────────────────────
TW = 6.30   # A4 text width in inches (~16 cm)

matplotlib.rcParams.update({
    'font.family':       'serif',
    'font.size':         9,
    'axes.titlesize':    10,
    'axes.labelsize':    9,
    'xtick.labelsize':   8,
    'ytick.labelsize':   8,
    'legend.fontsize':   8.5,
    'axes.linewidth':    0.7,
    'axes.spines.top':   False,
    'axes.spines.right': False,
    'figure.dpi':        150,
})

BASE_SEED = 42
N_RUNS    = 30
_jrng     = np.random.RandomState(BASE_SEED)   # fixed jitter seed

# ── File paths ────────────────────────────────────────────────────────────────
DATASETS = {
    'Continual\nInconsp.': r"C:\Users\carlp\Downloads\slow_leech.csv",
    'Geometric\nEscal.':   r"C:\Users\carlp\Downloads\geometric_attack.csv",
    'Blast\nDDoW':         r"C:\Users\carlp\Downloads\blast_attack.csv",
    'Random\nRate':        r"C:\Users\carlp\Downloads\random_rate.csv",
}
BASELINE_CSV = r"C:\Users\carlp\Downloads\normal_new.csv"
MODEL_PATH   = r"C:\Users\carlp\isolation_forest_baseline.pkl"
SCALER_PATH  = r"C:\Users\carlp\scaler_baseline.pkl"
OUT_DIR      = "thesis_plots"

# ── Constants ─────────────────────────────────────────────────────────────────
MIN_INVOCATIONS = 100
DELTA_CLIP      = 1000
WARNING_MARGIN  = 0.04

GRINGOTTS_FEATURES = [
    "avgDurationMs_login","avgDurationMs_search","avgDurationMs_product",
    "avgDurationMs_cart","avgDurationMs_checkout",
    "log_invocations_login","log_invocations_search","log_invocations_product",
    "log_invocations_cart","log_invocations_checkout",
    "hour_of_day",
]
IF_FEATURE_KEYS = [
    'checkoutToLoginRatio_stable','cartToSearchRatio_stable',
    'highValuePressure_stable','highMemFraction',
    'log_totalEstimatedCost','log_totalInvocations',
    'invocationEntropy','hour_of_day',
    'deltaTotalInvocations_clipped','isActive',
]

C_IF = '#4C9BE8'
C_G  = '#E8754C'

# ── Load models ───────────────────────────────────────────────────────────────
print("Loading models and baseline...")
iso_forest = joblib.load(MODEL_PATH)
scaler     = joblib.load(SCALER_PATH)

df_base = pd.read_csv(BASELINE_CSV)
df_base = df_base[df_base['totalInvocations'] > 0].copy()
df_base['ground_truth'] = 'NORMAL'

# ── Fit Gringotts ─────────────────────────────────────────────────────────────
df_bt = df_base[df_base['deltaTotalInvocations'].abs() <= 2000].copy().fillna(0)
for fn in ['login','search','product','cart','checkout']:
    df_bt[f'log_invocations_{fn}'] = np.log1p(df_bt[f'invocations_{fn}'])

G_train    = df_bt[GRINGOTTS_FEATURES].values
mu         = G_train.mean(axis=0)
cov        = np.atleast_2d(np.cov(G_train, rowvar=False))
cov_inv    = pinv(cov + 1e-6 * np.eye(cov.shape[0]))
k          = len(GRINGOTTS_FEATURES)
chi2_alert = chi2.ppf(1 - 0.001, df=k)
chi2_warn  = chi2.ppf(1 - 0.01,  df=k)

# ── Feature engineering ───────────────────────────────────────────────────────
def engineer(df_in):
    df = df_in[df_in['deltaTotalInvocations'].abs() <= 2000].copy().fillna(0)
    df['isActive'] = (df['totalInvocations'] > 0).astype(float)
    df['deltaTotalInvocations_clipped'] = df['deltaTotalInvocations'].clip(
        -DELTA_CLIP, DELTA_CLIP)
    stable = df['totalInvocations'] >= MIN_INVOCATIONS
    df['checkoutToLoginRatio_stable'] = np.where(
        stable, df['checkoutToLoginRatio'], 0.0)
    df['cartToSearchRatio_stable'] = np.where(
        stable, df['cartToSearchRatio'], 0.0)
    df['highValuePressure_stable'] = np.where(
        stable, df['checkoutToLoginRatio'] * df['highMemFraction'], 0.0)
    df['log_totalInvocations']   = np.log1p(df['totalInvocations'])
    df['log_totalEstimatedCost'] = np.log1p(
        df['totalEstimatedCost'].astype(float) * 1e8)
    for fn in ['login','search','product','cart','checkout']:
        df[f'log_invocations_{fn}'] = np.log1p(df[f'invocations_{fn}'])
    return df

def score_if(df):
    Xs     = scaler.transform(df[IF_FEATURE_KEYS].values)
    scores = iso_forest.score_samples(Xs)
    thr    = iso_forest.offset_
    tiers  = np.where(scores < thr, 'ALERT',
             np.where(scores < thr + WARNING_MARGIN, 'WARNING', 'NORMAL'))
    return pd.Series(tiers, index=df.index)

def score_g(df):
    tiers = []
    for x in df[GRINGOTTS_FEATURES].values:
        d2 = float((x - mu) @ cov_inv @ (x - mu))
        tiers.append('ALERT' if d2 > chi2_alert else
                     'WARNING' if d2 > chi2_warn else 'NORMAL')
    return pd.Series(tiers, index=df.index)

def compute_metrics(tiers, gt):
    flagged = tiers.isin(['ALERT', 'WARNING'])
    atk = gt == 'ATTACK';  nrm = gt == 'NORMAL'
    tp = (flagged & atk).sum();  fn = (~flagged & atk).sum()
    fp = (flagged & nrm).sum();  tn = (~flagged & nrm).sum()
    tpr = tp / max(tp+fn, 1) * 100
    fpr = fp / max(fp+tn, 1) * 100
    pre = tp / max(tp+fp, 1) * 100
    f1  = 2*pre*tpr / max(pre+tpr, 1e-6)
    return tpr, fpr, pre, f1

# ── Evaluate ──────────────────────────────────────────────────────────────────
all_results = {}

for label, path in DATASETS.items():
    print(f"\n{label.replace(chr(10),' ')} ...")
    df_atk = pd.read_csv(path)
    df_atk = df_atk[df_atk['totalInvocations'] > 0].copy()
    df_atk['ground_truth'] = 'ATTACK'
    n = int(min(len(df_atk), len(df_base)) * 0.8)

    runs = []
    for i in range(N_RUNS):
        da = df_atk.sample(n=n, random_state=BASE_SEED + i)
        dn = df_base.sample(n=n, random_state=BASE_SEED + i + N_RUNS)
        dr = pd.concat([da, dn], ignore_index=True)
        dr = engineer(dr)
        dr['if_tier'] = score_if(dr).values
        dr['g_tier']  = score_g(dr).values
        if_tpr, if_fpr, if_pre, if_f1 = compute_metrics(
            dr['if_tier'], dr['ground_truth'])
        g_tpr, g_fpr, g_pre, g_f1 = compute_metrics(
            dr['g_tier'], dr['ground_truth'])
        runs.append({'if_tpr':if_tpr,'if_fpr':if_fpr,'if_pre':if_pre,'if_f1':if_f1,
                     'g_tpr':g_tpr,  'g_fpr':g_fpr,  'g_pre':g_pre, 'g_f1':g_f1})

    rdf = pd.DataFrame(runs)
    all_results[label] = rdf
    print(f"  IF TPR={rdf['if_tpr'].mean():.1f}±{rdf['if_tpr'].std():.2f}  "
          f"FPR={rdf['if_fpr'].mean():.1f}±{rdf['if_fpr'].std():.2f}  "
          f"Pre={rdf['if_pre'].mean():.1f}±{rdf['if_pre'].std():.2f}  "
          f"F1={rdf['if_f1'].mean():.1f}±{rdf['if_f1'].std():.2f}")
    print(f"  G  TPR={rdf['g_tpr'].mean():.1f}±{rdf['g_tpr'].std():.2f}  "
          f"FPR={rdf['g_fpr'].mean():.1f}±{rdf['g_fpr'].std():.2f}  "
          f"Pre={rdf['g_pre'].mean():.1f}±{rdf['g_pre'].std():.2f}  "
          f"F1={rdf['g_f1'].mean():.1f}±{rdf['g_f1'].std():.2f}")

os.makedirs(OUT_DIR, exist_ok=True)
labels     = list(all_results.keys())
n_scen     = len(labels)
clean_lbls = [l.replace('\n', ' ') for l in labels]

def save_fig(name):
    plt.savefig(f"{OUT_DIR}/{name}.pdf", format='pdf', bbox_inches='tight')
    plt.savefig(f"{OUT_DIR}/{name}.png", dpi=200,      bbox_inches='tight')
    plt.close()
    print(f"  Saved → {OUT_DIR}/{name}.pdf / .png")


# ═══════════════════════════════════════════════════════════════════════════════
# FIGURE 1 — TPR + FPR bar chart  (NO error bars — box plots handle that)
# ═══════════════════════════════════════════════════════════════════════════════
print("\nFigure 1: TPR + FPR bar chart (no error bars)...")

fig, (ax_tpr, ax_fpr) = plt.subplots(1, 2, figsize=(TW, TW * 0.50),
                                      constrained_layout=True)
x = np.arange(n_scen)
w = 0.34

for ax, if_col, g_col, ylabel, title in [
    (ax_tpr, 'if_tpr', 'g_tpr', 'True Positive Rate (%)', 'TPR'),
    (ax_fpr, 'if_fpr', 'g_fpr', 'False Positive Rate (%)', 'FPR'),
]:
    if_means = np.array([all_results[l][if_col].mean() for l in labels])
    g_means  = np.array([all_results[l][g_col].mean()  for l in labels])

    # Clean bars — no error bars, box plots tell the distribution story
    b1 = ax.bar(x - w/2, if_means, w,
                color=C_IF, edgecolor='black', linewidth=0.4, alpha=0.9)
    b2 = ax.bar(x + w/2, g_means,  w,
                color=C_G,  edgecolor='black', linewidth=0.4, alpha=0.9)

    # Labels: all above bars, black bold, small gap from bar top
    for bar in list(b1) + list(b2):
        h  = bar.get_height()
        cx = bar.get_x() + bar.get_width() / 2
        ax.text(cx, h + 1.2, f'{h:.1f}',
                ha='center', va='bottom',
                fontsize=7.5, fontweight='bold', color='black', zorder=6)

    ax.set_xticks(x)
    ax.set_xticklabels(clean_lbls, rotation=15, ha='right')
    ax.set_ylabel(ylabel)
    ax.set_title(title, fontweight='bold', pad=4)
    ax.yaxis.grid(True, linestyle='--', alpha=0.35, linewidth=0.5)
    ax.set_axisbelow(True)
    ax.set_ylim(0, 115)

fig.legend(
    handles=[Patch(facecolor=C_IF, alpha=0.9, label='RBF-DoW (Isolation Forest)'),
             Patch(facecolor=C_G,  alpha=0.9, label='Gringotts reimplementation')],
    loc='lower center', ncol=2, frameon=False,
    bbox_to_anchor=(0.5, -0.10)
)
save_fig("plot_tpr_fpr_bars")


# ═══════════════════════════════════════════════════════════════════════════════
# FIGURES 2 & 3 — Box plot grids: 4 subplots (one per attack), one figure per metric
# Shared y-axis across all 4 panels so distributions are directly comparable.
# Individual run dots (jittered, seed=42) overlaid on each box.
# ═══════════════════════════════════════════════════════════════════════════════

def make_boxplot_grid(metric_name, if_col, g_col, fname):
    print(f"\n{fname}: {metric_name} box plots (4 subplots)...")

    # Shared y range: global min/max across all scenarios + both detectors
    all_vals = np.concatenate(
        [all_results[l][if_col].values for l in labels] +
        [all_results[l][g_col].values  for l in labels]
    )
    lo  = all_vals.min()
    hi  = all_vals.max()
    pad = max((hi - lo) * 0.14, 3.0)
    y_lo = max(lo - pad, -1.0)
    y_hi = hi + pad * 1.8   # extra headroom for mean annotation

    fig, axes = plt.subplots(2, 2, figsize=(TW, TW * 0.90),
                             constrained_layout=True,
                             sharey=True)   # shared y-axis — key for comparison
    axes = axes.flatten()

    for ax, label in zip(axes, labels):
        rdf     = all_results[label]
        data_if = rdf[if_col].values
        data_g  = rdf[g_col].values

        # ── Box plots ────────────────────────────────────────────────────────
        bp = ax.boxplot(
            [data_if, data_g],
            positions=[1, 2],
            widths=0.52,
            patch_artist=True,
            medianprops=dict(color='black', linewidth=1.8),
            whiskerprops=dict(linewidth=0.9, linestyle='--'),
            capprops=dict(linewidth=0.9),
            flierprops=dict(marker='', markersize=0),  # hide default fliers
            manage_ticks=False,
            zorder=3,
        )
        colors = [C_IF, C_G]
        for patch, c in zip(bp['boxes'], colors):
            patch.set_facecolor(c)
            patch.set_alpha(0.72)

        # ── Jittered individual run dots (all 30 visible) ─────────────────
        for pos, data, c in zip([1, 2], [data_if, data_g], colors):
            jitter = _jrng.uniform(-0.16, 0.16, len(data))
            ax.scatter(pos + jitter, data,
                       s=8, color=c, alpha=0.40,
                       linewidths=0, zorder=2)

        # ── White mean dot ────────────────────────────────────────────────
        for pos, data in zip([1, 2], [data_if, data_g]):
            ax.plot(pos, np.mean(data),
                    marker='o', color='white', markersize=5.5,
                    zorder=6, markeredgecolor='black', markeredgewidth=0.8)

        # ── Mean value label above each box ──────────────────────────────
        for pos, data, c in zip([1, 2], [data_if, data_g], colors):
            m = np.mean(data)
            ax.text(pos, hi + pad * 0.25, f'{m:.1f}',
                    ha='center', va='bottom',
                    fontsize=7, fontweight='bold', color=c)

        ax.set_xticks([1, 2])
        ax.set_xticklabels(['RBF-DoW', 'Gringotts'], fontsize=8)
        ax.set_title(label.replace('\n', ' '), fontweight='bold', pad=5)
        ax.yaxis.grid(True, linestyle='--', alpha=0.35, linewidth=0.5)
        ax.set_axisbelow(True)
        ax.set_xlim(0.4, 2.6)
        ax.set_ylim(y_lo, y_hi)

    # Shared y-axis label on the left column only (sharey handles ticks)
    for ax in [axes[0], axes[2]]:
        ax.set_ylabel(f'{metric_name} (%)', fontsize=9)

    fig.legend(
        handles=[Patch(facecolor=C_IF, alpha=0.72, label='RBF-DoW (Isolation Forest)'),
                 Patch(facecolor=C_G,  alpha=0.72, label='Gringotts reimplementation')],
        loc='lower center', ncol=2, frameon=False,
        bbox_to_anchor=(0.5, -0.05)
    )
    save_fig(fname)


make_boxplot_grid('TPR', 'if_tpr', 'g_tpr', 'plot_tpr_boxplots')
make_boxplot_grid('FPR', 'if_fpr', 'g_fpr', 'plot_fpr_boxplots')


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNIFICANCE TABLE — TPR and FPR, ready-to-paste LaTeX
# ═══════════════════════════════════════════════════════════════════════════════

def fmt_p(p):
    if   p < 0.0001: return r"$< 0.0001$"
    elif p < 0.001:  return r"$< 0.001$"
    elif p < 0.01:   return r"$< 0.01$"
    elif p < 0.05:   return r"$< 0.05$"
    else:            return f"${p:.3f}$"

print("\n" + "=" * 70)
print(f"SIGNIFICANCE TABLE  (seed={BASE_SEED}, N={N_RUNS})")
print("Positive t on TPR = RBF-DoW detects more attacks")
print("Negative t on FPR = RBF-DoW produces fewer false alarms")
print("=" * 70)
print(f"\n{'Scenario':<26} {'TPR t':>8} {'TPR p':>12} {'FPR t':>8} {'FPR p':>12}")
print("-" * 70)

print("\n--- LaTeX rows (paste into Table 7.2 body) ---")
print(r"""\begin{tabular}{lrrrr}
\toprule
\textbf{Scenario} & \textbf{TPR $t$} & \textbf{TPR $p$} & \textbf{FPR $t$} & \textbf{FPR $p$} \\
\midrule""")

for label in labels:
    rdf = all_results[label]
    lbl = label.replace('\n', ' ')
    tpr_t, tpr_p = ttest_rel(rdf['if_tpr'].values, rdf['g_tpr'].values)
    fpr_t, fpr_p = ttest_rel(rdf['if_fpr'].values, rdf['g_fpr'].values)
    mw_tpr = mannwhitneyu(rdf['if_tpr'].values, rdf['g_tpr'].values,
                          alternative='two-sided')
    mw_fpr = mannwhitneyu(rdf['if_fpr'].values, rdf['g_fpr'].values,
                          alternative='two-sided')

    print(f"  {lbl} & ${tpr_t:+.2f}$ & {fmt_p(tpr_p)} & "
          f"${fpr_t:+.2f}$ & {fmt_p(fpr_p)} \\\\")

    plain_p = lambda p: ('< 0.0001' if p < 0.0001 else
                         '< 0.001'  if p < 0.001  else
                         '< 0.01'   if p < 0.01   else f'{p:.3f}')
    print(f"    [plain] TPR: t={tpr_t:+.2f} p={plain_p(tpr_p)}  "
          f"FPR: t={fpr_t:+.2f} p={plain_p(fpr_p)}  "
          f"MW-U TPR p={plain_p(mw_tpr.pvalue)} FPR p={plain_p(mw_fpr.pvalue)}")

print(r"""\bottomrule
\end{tabular}""")

print(f"\nAll three figures saved to ./{OUT_DIR}/")
print("Include in Overleaf (no extension needed):")
print("  \\includegraphics[width=\\textwidth]{thesis_plots/plot_tpr_fpr_bars}")
print("  \\includegraphics[width=\\textwidth]{thesis_plots/plot_tpr_boxplots}")
print("  \\includegraphics[width=\\textwidth]{thesis_plots/plot_fpr_boxplots}")
