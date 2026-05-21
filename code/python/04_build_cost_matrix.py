"""
04_build_cost_matrix.py — 构造 top K zone 之间的 OD 成本矩阵 C[i,j]。

方法：
    c_ij = median(trip_distance) 在训练期内 i → j 的所有行程
    若该 OD 对在训练期无行程：
        - i == j         → 0
        - 同 borough     → 同 borough 的 median
        - 其他           → global median × 1.5

输出：data/processed/cost_matrix_topK.csv （K × K，无 header / index，纯数字）
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))

import _config as cfg  # noqa: E402

PICKUP_COL = "tpep_pickup_datetime"
PU_COL = "PULocationID"
DO_COL = "DOLocationID"
DIST_COL = "trip_distance"


def _train_end_from_panel(panel: pd.DataFrame) -> int:
    """Hour-index where train ends (split_id == 0 last hour)."""
    return int(panel.loc[panel["split_id"] == 0, "hour_index"].max())


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="OD cost matrix in train window")
    p.add_argument("--trips", type=Path,
                   default=cfg.PROCESSED_DIR / "trips_clean.parquet")
    p.add_argument("--panel", type=Path,
                   default=cfg.PROCESSED_DIR / "panel_numeric.csv")
    p.add_argument("--zones", type=Path,
                   default=cfg.PROCESSED_DIR / "top_zones.csv")
    p.add_argument("--zone-meta", type=Path,
                   default=cfg.PROCESSED_DIR / "zone_meta.csv")
    p.add_argument("--out", type=Path,
                   default=cfg.PROCESSED_DIR / "cost_matrix_topK.csv")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    for f in (args.trips, args.panel, args.zones):
        if not f.exists():
            raise FileNotFoundError(
                f"missing {f}; run 02_preprocess_trips.py & 03_build_features.py first"
            )

    top_zones = pd.read_csv(args.zones)["zone_id"].astype(int).tolist()
    zone_index = {z: i for i, z in enumerate(top_zones)}
    K = len(top_zones)
    print(f"K = {K} zones")

    panel = pd.read_csv(args.panel, usecols=["hour_index", "split_id"])
    train_end_hour = _train_end_from_panel(panel)
    epoch = pd.Timestamp("1970-01-01")
    train_end_ts = epoch + pd.Timedelta(hours=int(train_end_hour))
    print(f"train end (inclusive): {train_end_ts}")

    print("reading trips ...")
    trips = pd.read_parquet(
        args.trips, columns=[PICKUP_COL, PU_COL, DO_COL, DIST_COL]
    )
    trips = trips[
        (trips[PU_COL].isin(top_zones))
        & (trips[DO_COL].isin(top_zones))
        & (trips[PICKUP_COL] <= train_end_ts)
    ].copy()
    print(f"  train-window top-K trips: {len(trips):,}")

    print("computing OD median trip_distance ...")
    od_med = (
        trips.groupby([PU_COL, DO_COL])[DIST_COL]
        .median()
        .reset_index()
        .rename(columns={PU_COL: "pu", DO_COL: "do", DIST_COL: "med"})
    )

    C = np.full((K, K), np.nan, dtype=np.float64)
    for _, row in od_med.iterrows():
        i = zone_index[int(row["pu"])]
        j = zone_index[int(row["do"])]
        C[i, j] = float(row["med"])

    # diagonal = 0
    np.fill_diagonal(C, cfg.COST_DIAGONAL)

    # borough fallback
    if args.zone_meta.exists():
        meta = pd.read_csv(args.zone_meta)
        zone_to_borough = dict(zip(meta["zone_id"].astype(int), meta["borough"]))
    else:
        zone_to_borough = {z: "Unknown" for z in top_zones}

    boroughs = [zone_to_borough.get(z, "Unknown") for z in top_zones]
    unique_boroughs = sorted(set(boroughs))

    # global median over all known cells (non-NaN, non-diagonal)
    mask = ~np.isnan(C) & ~np.eye(K, dtype=bool)
    global_med = float(np.nanmedian(C[mask])) if mask.any() else 1.0
    print(f"  global OD median: {global_med:.3f} mi")

    # borough medians from known cells
    borough_meds: dict[tuple[str, str], float] = {}
    for ba in unique_boroughs:
        for bb in unique_boroughs:
            sub = []
            for i in range(K):
                for j in range(K):
                    if i == j or np.isnan(C[i, j]):
                        continue
                    if boroughs[i] == ba and boroughs[j] == bb:
                        sub.append(C[i, j])
            if sub:
                borough_meds[(ba, bb)] = float(np.median(sub))

    # fill remaining NaNs
    n_filled_borough = 0
    n_filled_global = 0
    for i in range(K):
        for j in range(K):
            if np.isnan(C[i, j]):
                bm = borough_meds.get((boroughs[i], boroughs[j]))
                if bm is not None:
                    C[i, j] = bm
                    n_filled_borough += 1
                else:
                    C[i, j] = global_med * cfg.COST_GLOBAL_FALLBACK_MULTIPLIER
                    n_filled_global += 1
    print(f"  filled by borough median   : {n_filled_borough}")
    print(f"  filled by global * {cfg.COST_GLOBAL_FALLBACK_MULTIPLIER}: {n_filled_global}")

    np.fill_diagonal(C, cfg.COST_DIAGONAL)

    # write — no header, no index, just K x K numeric
    args.out.parent.mkdir(parents=True, exist_ok=True)
    np.savetxt(args.out, C, fmt="%.6f", delimiter=",")
    print(f"  → {args.out} ({K}×{K})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
