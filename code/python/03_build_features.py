"""
03_build_features.py — 从 trips_clean.parquet 构造 zone-hour 面板与特征。

步骤：
    1. 聚合 pickup_count / dropoff_count 到 (zone, hour)。
    2. 从 train 期 pickup 总量选 top K zones。
    3. 构造完整网格 top_zones × all_hours（缺失填 0）。
    4. 构造 lag / rolling / same_hour_prev_day 等时间特征。
    5. 输出：
         panel_numeric.csv           带 header
         panel_numeric_noheader.csv  不带 header（北太天元 csvread 兜底）
         panel_columns.txt           列名清单
         zone_meta.csv               zone_id / zone_name / borough
         top_zones.csv               入选 zone_id
         test_hours.csv              代表性测试小时
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
DROPOFF_COL = "tpep_dropoff_datetime"
PU_COL = "PULocationID"
DO_COL = "DOLocationID"

OUTPUT_COLS = [
    "zone_id", "hour_index",
    "pickup_count", "dropoff_count",
    "lag_pickup_1h", "lag_pickup_2h",
    "lag_dropoff_1h", "lag_dropoff_2h",
    "rolling_pickup_mean_6h", "rolling_pickup_mean_24h",
    "rolling_dropoff_mean_6h",
    "same_hour_prev_day_pickup", "same_hour_prev_week_pickup",
    "hour_of_day", "weekday", "is_weekend",
    "hour_sin", "hour_cos",
    "split_id",          # 0 = train, 1 = val, 2 = test
]


def _aggregate_zone_hour(trips: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Returns (pickup_panel, dropoff_panel) both indexed by (zone, hour)."""
    pickups = trips[[PICKUP_COL, PU_COL]].copy()
    pickups["hour"] = pickups[PICKUP_COL].dt.floor("h")
    pu = (
        pickups.groupby([PU_COL, "hour"])
        .size()
        .rename("pickup_count")
        .reset_index()
        .rename(columns={PU_COL: "zone_id"})
    )

    dropoffs = trips[[DROPOFF_COL, DO_COL]].copy()
    dropoffs["hour"] = dropoffs[DROPOFF_COL].dt.floor("h")
    do = (
        dropoffs.groupby([DO_COL, "hour"])
        .size()
        .rename("dropoff_count")
        .reset_index()
        .rename(columns={DO_COL: "zone_id"})
    )
    return pu, do


# TLC code 264 = "Unknown", 265 = "Outside of NYC" — pathological catch-all
# location IDs that absorb every unidentifiable trip. Excluding them keeps the
# rebalancing model focused on real, navigable taxi zones.
_EXCLUDED_ZONE_IDS = {264, 265}


def _select_top_zones(pu: pd.DataFrame, train_end: pd.Timestamp, k: int) -> list[int]:
    """top K zone by training-period pickup volume — train info only, no leak.

    Pathological zone IDs (264 = Unknown, 265 = Outside of NYC) are excluded.
    """
    train_pu = pu[(pu["hour"] < train_end)
                  & (~pu["zone_id"].isin(_EXCLUDED_ZONE_IDS))]
    totals = train_pu.groupby("zone_id")["pickup_count"].sum().sort_values(ascending=False)
    return totals.head(k).index.astype(int).tolist()


def _build_full_grid(zones: list[int], hours: pd.DatetimeIndex) -> pd.DataFrame:
    grid = pd.MultiIndex.from_product([zones, hours], names=["zone_id", "hour"])
    return pd.DataFrame(index=grid).reset_index()


def _add_time_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.sort_values(["zone_id", "hour"]).reset_index(drop=True)
    df["hour_of_day"] = df["hour"].dt.hour.astype("int16")
    df["weekday"] = df["hour"].dt.weekday.astype("int16")
    df["is_weekend"] = (df["weekday"] >= 5).astype("int16")
    df["hour_sin"] = np.sin(2 * np.pi * df["hour_of_day"] / 24.0)
    df["hour_cos"] = np.cos(2 * np.pi * df["hour_of_day"] / 24.0)
    return df


def _add_lag_rolling(df: pd.DataFrame) -> pd.DataFrame:
    g = df.groupby("zone_id", sort=False)
    for col, lags in (("pickup_count", (1, 2)), ("dropoff_count", (1, 2))):
        for lag in lags:
            df[f"lag_{col.replace('_count','')}_{lag}h"] = g[col].shift(lag)

    df["rolling_pickup_mean_6h"] = g["pickup_count"].transform(
        lambda s: s.shift(1).rolling(6, min_periods=1).mean()
    )
    df["rolling_pickup_mean_24h"] = g["pickup_count"].transform(
        lambda s: s.shift(1).rolling(24, min_periods=1).mean()
    )
    df["rolling_dropoff_mean_6h"] = g["dropoff_count"].transform(
        lambda s: s.shift(1).rolling(6, min_periods=1).mean()
    )
    df["same_hour_prev_day_pickup"] = g["pickup_count"].shift(24)
    df["same_hour_prev_week_pickup"] = g["pickup_count"].shift(24 * 7)

    # any feature column has NaN at the very beginning — fill with 0.0 sentinel
    feature_cols = [c for c in df.columns
                    if c.startswith(("lag_", "rolling_", "same_hour_"))]
    df[feature_cols] = df[feature_cols].fillna(0.0)
    return df


def _assign_split(df: pd.DataFrame, hours: pd.DatetimeIndex,
                  train_frac: float, val_frac: float) -> pd.DataFrame:
    n = len(hours)
    train_end_idx = int(n * train_frac)
    val_end_idx = int(n * (train_frac + val_frac))
    train_end = hours[train_end_idx - 1]
    val_end = hours[val_end_idx - 1]

    cond_train = df["hour"] <= train_end
    cond_val = (df["hour"] > train_end) & (df["hour"] <= val_end)
    df["split_id"] = np.where(cond_train, 0, np.where(cond_val, 1, 2)).astype("int8")
    return df


def _load_zone_meta() -> pd.DataFrame:
    p = cfg.lookup_raw_path()
    if not p.exists():
        # synthesize a stub if the lookup wasn't downloaded
        return pd.DataFrame(columns=["LocationID", "Borough", "Zone", "service_zone"])
    return pd.read_csv(p)


def _select_test_hours(df: pd.DataFrame, n: int, seed: int) -> list[pd.Timestamp]:
    """Pick n representative test hours that span a full day cycle.

    Strategy: walk forward from the first test hour until we find a midnight,
    then take the next 24 contiguous hours so the dispatch simulation covers
    every hour-of-day exactly once. If the test window is too short, fall back
    to the first n contiguous test hours, then to a uniform sample.
    """
    test_hours = sorted(df.loc[df["split_id"] == 2, "hour"].unique())
    if not test_hours:
        return []
    in_set = {pd.Timestamp(h) for h in test_hours}

    if len(test_hours) >= n:
        # find first midnight that has all n following hours inside the test set
        first = pd.Timestamp(test_hours[0])
        last = pd.Timestamp(test_hours[-1])
        # start from the FIRST full calendar day inside the test window
        day = first.floor("D")
        if day < first:
            day = day + pd.Timedelta(days=1)
        while day + pd.Timedelta(hours=n - 1) <= last:
            candidate = [day + pd.Timedelta(hours=k) for k in range(n)]
            if all(c in in_set for c in candidate):
                return candidate
            day = day + pd.Timedelta(days=1)
        # second-best: first n contiguous hours starting at the test window's start
        if pd.Timestamp(test_hours[n - 1]) == first + pd.Timedelta(hours=n - 1):
            return [first + pd.Timedelta(hours=k) for k in range(n)]
        # last resort: deterministic uniform sample
        rng = np.random.default_rng(seed)
        idx = rng.choice(len(test_hours), size=n, replace=False)
        return [pd.Timestamp(test_hours[i]) for i in sorted(idx)]
    return [pd.Timestamp(h) for h in test_hours]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build zone-hour panel features")
    p.add_argument("--trips", type=Path,
                   default=cfg.PROCESSED_DIR / "trips_clean.parquet")
    p.add_argument("--topk", type=int, default=cfg.DEFAULT_TOPK)
    p.add_argument("--train-frac", type=float, default=cfg.DEFAULT_TRAIN_FRAC)
    p.add_argument("--val-frac", type=float, default=cfg.DEFAULT_VAL_FRAC)
    p.add_argument("--n-test-hours", type=int, default=cfg.N_TEST_HOURS)
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if not args.trips.exists():
        raise FileNotFoundError(
            f"missing {args.trips}; run 02_preprocess_trips.py first"
        )

    print(f"reading {args.trips} ...")
    trips = pd.read_parquet(args.trips)
    print(f"  {len(trips):,} trips")

    print("aggregating to (zone, hour) ...")
    pu, do = _aggregate_zone_hour(trips)
    print(f"  pickup rows : {len(pu):,}")
    print(f"  dropoff rows: {len(do):,}")

    all_hours = pd.date_range(
        start=min(pu["hour"].min(), do["hour"].min()).floor("h"),
        end=max(pu["hour"].max(), do["hour"].max()).ceil("h"),
        freq=cfg.DEFAULT_TIME_RESOLUTION,
    )
    n_hours = len(all_hours)
    train_end = all_hours[int(n_hours * args.train_frac) - 1]
    print(f"  hours total : {n_hours}; train ends at {train_end}")

    print(f"selecting top {args.topk} zones (train-only) ...")
    top_zones = _select_top_zones(pu, train_end, args.topk)
    print(f"  e.g. {top_zones[:10]} ...")

    grid = _build_full_grid(top_zones, all_hours)
    grid = grid.merge(pu, on=["zone_id", "hour"], how="left")
    grid = grid.merge(do, on=["zone_id", "hour"], how="left")
    grid[["pickup_count", "dropoff_count"]] = grid[
        ["pickup_count", "dropoff_count"]
    ].fillna(0).astype("int64")

    print("building time / lag / rolling features ...")
    grid = _add_time_features(grid)
    grid = _add_lag_rolling(grid)
    grid = _assign_split(grid, all_hours, args.train_frac, args.val_frac)

    # encode hour as integer hour_index (Unix hour) so 北太天元 can csvread it
    epoch = pd.Timestamp("1970-01-01")
    grid["hour_index"] = (
        (grid["hour"] - epoch).dt.total_seconds() // 3600
    ).astype("int64")

    out = grid[OUTPUT_COLS].copy()

    panel_csv = cfg.PROCESSED_DIR / "panel_numeric.csv"
    panel_noheader = cfg.PROCESSED_DIR / "panel_numeric_noheader.csv"
    panel_cols = cfg.PROCESSED_DIR / "panel_columns.txt"

    print(f"writing panel ... ({len(out):,} rows × {len(OUTPUT_COLS)} cols)")
    out.to_csv(panel_csv, index=False)
    out.to_csv(panel_noheader, index=False, header=False)
    panel_cols.write_text("\n".join(OUTPUT_COLS) + "\n", encoding="utf-8")

    # zone meta — defensive fill so empty names never propagate downstream
    lookup = _load_zone_meta()
    if not lookup.empty:
        meta = (
            lookup.rename(columns={
                "LocationID": "zone_id",
                "Zone": "zone_name",
                "Borough": "borough",
            })
            .loc[lambda d: d["zone_id"].isin(top_zones)]
            [["zone_id", "zone_name", "borough"]]
            .copy()
        )
        # ensure every selected top zone is represented (lookup may be missing)
        present = set(meta["zone_id"].astype(int).tolist())
        missing_rows = [{"zone_id": z, "zone_name": f"Zone_{z}", "borough": "Unknown"}
                        for z in top_zones if z not in present]
        if missing_rows:
            meta = pd.concat([meta, pd.DataFrame(missing_rows)], ignore_index=True)
        # fill any NaN / empty cells
        meta["zone_name"] = meta["zone_name"].fillna("").astype(str)
        meta.loc[meta["zone_name"].str.strip() == "", "zone_name"] = (
            "Zone_" + meta.loc[meta["zone_name"].str.strip() == "", "zone_id"].astype(str)
        )
        meta["borough"] = meta["borough"].fillna("Unknown").astype(str)
        # remove commas to keep CSV clean
        meta["zone_name"] = meta["zone_name"].str.replace(",", " ", regex=False)
        meta["borough"]   = meta["borough"].str.replace(",", " ", regex=False)
    else:
        meta = pd.DataFrame({
            "zone_id": top_zones,
            "zone_name": [f"Zone_{z}" for z in top_zones],
            "borough": ["Unknown"] * len(top_zones),
        })
    meta.to_csv(cfg.PROCESSED_DIR / "zone_meta.csv", index=False)

    pd.DataFrame({"zone_id": top_zones}).to_csv(
        cfg.PROCESSED_DIR / "top_zones.csv", index=False
    )

    test_hours = _select_test_hours(grid, args.n_test_hours, cfg.RANDOM_SEED)
    th = pd.DataFrame({
        "hour_iso": [t.isoformat() for t in test_hours],
        "hour_index": [int((t - epoch).total_seconds() // 3600) for t in test_hours],
    })
    th.to_csv(cfg.PROCESSED_DIR / "test_hours.csv", index=False)
    print(f"selected {len(test_hours)} test hours, first: {test_hours[:3]}")

    print()
    print("done.")
    print(f"  → {panel_csv}")
    print(f"  → {panel_noheader}")
    print(f"  → {panel_cols}")
    print(f"  → {cfg.PROCESSED_DIR / 'zone_meta.csv'}")
    print(f"  → {cfg.PROCESSED_DIR / 'top_zones.csv'}")
    print(f"  → {cfg.PROCESSED_DIR / 'test_hours.csv'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
