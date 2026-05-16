import pandas as pd
import matplotlib.pyplot as plt

ds7 = pd.read_csv(r"C:\Users\carlp\Downloads\fingerprint_dataset(7).csv")
ds8 = pd.read_csv(r"C:\Users\carlp\Downloads\fingerprint_dataset(8).csv")

def compute_accumulated(df, reduction):
    cost = df['totalEstimatedCost'].values
    accumulated = []
    for detect_at in range(0, 25):
        total = sum(cost[:detect_at])
        total += sum(cost[detect_at:] * (1 - reduction))
        accumulated.append(total)
    return accumulated

minutes = [d * 5 for d in range(0, 25)]

ds7_costs = compute_accumulated(ds7, 0.602)
ds8_costs = compute_accumulated(ds8, 0.741)

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))

ax1.plot(minutes, ds7_costs, marker='o', markersize=3, color='steelblue')
ax1.axvline(x=0, color='green', linestyle='--', label='RBF-DoW (window 0)')
ax1.axvline(x=30, color='red', linestyle='--', label='Gringotts (window 6)')
ax1.set_xlabel('Detection latency (minutes)')
ax1.set_ylabel('Accumulated billing cost (USD)')
ax1.set_title('DS7 — Continual Inconspicuous DoW')
ax1.legend()

ax2.plot(minutes, ds8_costs, marker='o', markersize=3, color='steelblue')
ax2.axvline(x=0, color='green', linestyle='--', label='RBF-DoW (window 0)')
ax2.axvline(x=30, color='red', linestyle='--', label='Gringotts (window 6)')
ax2.set_xlabel('Detection latency (minutes)')
ax2.set_ylabel('Accumulated billing cost (USD)')
ax2.set_title('DS8 — Random Rate DoW')
ax2.legend()

plt.tight_layout()
plt.savefig(r'C:\Users\carlp\Downloads\cost_tradeoff_curve.png', dpi=150)
print("Saved to Downloads folder.")