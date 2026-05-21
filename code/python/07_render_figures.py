"""
07_render_figures.py — Render the 6 required figures from CSVs written by
the 北太天元 pipeline (run_all.m → export_figure_data.m).

Inputs (under results/tables/):
    fig_data_demand_pattern.csv         7 x 24 mean pickup heatmap
    fig_data_supply_demand_gap.csv      K rows: Q, P_true, gap
    fig_data_dispatch_comparison.csv    H test hours x 3 policies
    fig_data_top_flows.csv              top-N LP flows
    fig_data_monte_carlo.csv            M scenarios x 3 policies
    sensitivity_lambda.csv              lambda sweep

Outputs (under results/figures/):
    fig_demand_pattern.png
    fig_supply_demand_gap.png
    fig_dispatch_comparison.png
    fig_top_flows.png
    fig_monte_carlo_boxplot.png
    fig_pareto_lambda.png              cost vs unmet — LP's Pareto frontier

This script is the *only* place matplotlib is invoked; it does not perform
any optimisation or modelling.  Re-run it after every 北太天元 run.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _config as cfg  # noqa: E402

# headless backend for batch / CI
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "xtick.labelsize": 10,
    "ytick.labelsize": 10,
    "legend.fontsize": 10,
    "figure.titlesize": 13,
})


def demand_pattern() -> None:
    p = cfg.TABLES_DIR / "fig_data_demand_pattern.csv"
    if not p.exists():
        print(f"  [skip] {p.name} missing")
        return
    df = pd.read_csv(p)
    weekdays = df["weekday"].to_numpy()
    grid = df.drop(columns=["weekday"]).to_numpy()

    fig, ax = plt.subplots(figsize=(10, 4))
    im = ax.imshow(grid, aspect="auto", cmap="viridis", origin="lower")
    ax.set_xlabel("hour of day")
    ax.set_ylabel("weekday (0 = Monday)")
    ax.set_xticks(range(0, 24, 2))
    ax.set_yticks(range(7))
    ax.set_yticklabels(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][:len(weekdays)])
    ax.set_title("Mean pickup count per zone-hour (training period, top-50 zones)")
    fig.colorbar(im, ax=ax, label="pickups / zone")
    out = cfg.FIGURES_DIR / "fig_demand_pattern.png"
    fig.tight_layout()
    fig.savefig(out, dpi=180)
    plt.close(fig)
    print(f"  → {out.name}")


def supply_demand_gap() -> None:
    p = cfg.TABLES_DIR / "fig_data_supply_demand_gap.csv"
    if not p.exists():
        print(f"  [skip] {p.name} missing")
        return
    df = pd.read_csv(p)
    df = df.sort_values("gap").reset_index(drop=True)
    K = len(df)
    hour_index = int(df["hour_index"].iloc[0])
    hour_ts = pd.Timestamp("1970-01-01") + pd.Timedelta(hours=hour_index)

    fig, ax = plt.subplots(figsize=(12, 4))
    colors = ["#d62728" if g < 0 else "#2ca02c" for g in df["gap"]]
    ax.bar(range(K), df["gap"], color=colors)
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_xlabel("zone rank (deficit → surplus)")
    ax.set_ylabel(r"$Q_{i,t} - P^{true}_{i,t+1}$")
    ax.set_title(f"Supply – demand gap at {hour_ts:%Y-%m-%d %H:00}  "
                 f"(red = deficit, green = surplus)")
    ax.grid(axis="y", alpha=0.3)
    fig.tight_layout()
    out = cfg.FIGURES_DIR / "fig_supply_demand_gap.png"
    fig.savefig(out, dpi=180)
    plt.close(fig)
    print(f"  → {out.name}")


def dispatch_comparison() -> None:
    p = cfg.TABLES_DIR / "fig_data_dispatch_comparison.csv"
    if not p.exists():
        print(f"  [skip] {p.name} missing")
        return
    df = pd.read_csv(p)
    H = len(df)
    x = np.arange(H)
    width = 0.28

    fig, axes = plt.subplots(2, 1, figsize=(12, 7), sharex=True)
    ax = axes[0]
    ax.bar(x - width, df["unmet_no"],     width=width, label="no rebalance",  color="#7f7f7f")
    ax.bar(x,         df["unmet_greedy"], width=width, label="greedy",        color="#ff7f0e")
    ax.bar(x + width, df["unmet_lp"],     width=width, label="LP",            color="#1f77b4")
    ax.set_ylabel("total real unmet demand")
    ax.set_title("Unmet demand across test hours (real next-hour pickup)")
    ax.grid(axis="y", alpha=0.3)
    ax.legend(loc="upper left")

    ax = axes[1]
    ax.bar(x - width, df["cost_no"],     width=width, label="no rebalance", color="#7f7f7f")
    ax.bar(x,         df["cost_greedy"], width=width, label="greedy",       color="#ff7f0e")
    ax.bar(x + width, df["cost_lp"],     width=width, label="LP",           color="#1f77b4")
    ax.set_xlabel("test hour")
    ax.set_ylabel("empty distance cost (miles)")
    ax.set_title("Empty distance cost across test hours")
    ax.grid(axis="y", alpha=0.3)

    fig.tight_layout()
    out = cfg.FIGURES_DIR / "fig_dispatch_comparison.png"
    fig.savefig(out, dpi=180)
    plt.close(fig)
    print(f"  → {out.name}")


def top_flows() -> None:
    p = cfg.TABLES_DIR / "fig_data_top_flows.csv"
    if not p.exists():
        print(f"  [skip] {p.name} missing")
        return
    df = pd.read_csv(p)
    df = df.head(15)
    if df.empty:
        print(f"  [skip] no LP flows recorded")
        return
    labels = [f"{r.src_name or r.src_zone_id} → {r.dst_name or r.dst_zone_id}"
              for r in df.itertuples()]
    # truncate labels for readability
    labels = [(l[:36] + "…") if len(l) > 38 else l for l in labels]

    fig, ax = plt.subplots(figsize=(11, 6))
    y = np.arange(len(labels))
    ax.barh(y, df["total_units"].to_numpy(), color="#1f77b4")
    ax.set_yticks(y)
    ax.set_yticklabels(labels)
    ax.invert_yaxis()
    ax.set_xlabel("Total dispatched units (sum across test hours)")
    ax.set_title(f"Top {len(df)} LP rebalancing flows")
    ax.grid(axis="x", alpha=0.3)
    fig.tight_layout()
    out = cfg.FIGURES_DIR / "fig_top_flows.png"
    fig.savefig(out, dpi=180)
    plt.close(fig)
    print(f"  → {out.name}")


def monte_carlo_boxplot() -> None:
    p = cfg.TABLES_DIR / "fig_data_monte_carlo.csv"
    if not p.exists():
        print(f"  [skip] {p.name} missing")
        return
    df = pd.read_csv(p)
    labels = ["no rebalance", "greedy", "LP"]

    fig, axes = plt.subplots(1, 2, figsize=(11, 4))
    axes[0].boxplot(
        [df["unmet_no"], df["unmet_greedy"], df["unmet_lp"]],
        tick_labels=labels, showmeans=True
    )
    axes[0].set_ylabel("total real unmet demand")
    axes[0].set_title("Unmet demand distribution under demand noise")
    axes[0].grid(axis="y", alpha=0.3)

    axes[1].boxplot(
        [df["srv_no"], df["srv_greedy"], df["srv_lp"]],
        tick_labels=labels, showmeans=True
    )
    axes[1].set_ylabel("service rate")
    axes[1].set_title("Service rate distribution")
    axes[1].grid(axis="y", alpha=0.3)

    fig.suptitle("Monte Carlo robustness on last test hour", y=1.02)
    fig.tight_layout()
    out = cfg.FIGURES_DIR / "fig_monte_carlo_boxplot.png"
    fig.savefig(out, dpi=180, bbox_inches="tight")
    plt.close(fig)
    print(f"  → {out.name}")


def pareto_lambda() -> None:
    p = cfg.TABLES_DIR / "sensitivity_lambda.csv"
    if not p.exists():
        print(f"  [skip] {p.name} missing")
        return
    df = pd.read_csv(p).sort_values("lambda")

    fig, ax1 = plt.subplots(figsize=(8, 5))
    color1 = "#1f77b4"
    ax1.plot(df["lambda"], df["total_unmet"], "o-", color=color1, label="unmet")
    ax1.set_xlabel(r"$\lambda$ (miles per unit unmet)")
    ax1.set_ylabel("total unmet demand", color=color1)
    ax1.tick_params(axis="y", labelcolor=color1)
    ax1.set_xscale("log")
    ax1.grid(True, which="both", alpha=0.3)

    ax2 = ax1.twinx()
    color2 = "#d62728"
    ax2.plot(df["lambda"], df["empty_cost"], "s--", color=color2, label="empty cost")
    ax2.set_ylabel("empty distance cost (miles)", color=color2)
    ax2.tick_params(axis="y", labelcolor=color2)

    ax1.set_title(
        r"LP cost-quality tradeoff: $\lambda$ sensitivity (last test hour)"
    )
    fig.tight_layout()
    out = cfg.FIGURES_DIR / "fig_pareto_lambda.png"
    fig.savefig(out, dpi=180)
    plt.close(fig)
    print(f"  → {out.name}")


def main() -> int:
    print("== rendering figures ==")
    demand_pattern()
    supply_demand_gap()
    dispatch_comparison()
    top_flows()
    monte_carlo_boxplot()
    pareto_lambda()
    print("\ndone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
