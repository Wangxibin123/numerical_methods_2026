"""
02_preprocess_trips.py — 读取原始 parquet，按既定规则清洗，输出干净的 trip 表。

清洗规则（与 README/data 文档一致）：
    pickup/dropoff 时间缺失 → 删
    PULocationID / DOLocationID 缺失 → 删
    trip_distance <= 0 或 > 100 → 删
    duration_min < 1 或 > 180 → 删
    fare_amount <= 0 → 删
    total_amount <= 0 → 删
    pickup 不在目标月份 → 删

每一步都把剩余行数追加到 results/tables/cleaning_summary.csv。

输出：
    data/processed/trips_clean.parquet   全部月份合并后的干净行程
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))

import _config as cfg  # noqa: E402

# --- TLC v2 yellow taxi field names (2024-) -------------------------------
PICKUP_COL = "tpep_pickup_datetime"
DROPOFF_COL = "tpep_dropoff_datetime"
PU_COL = "PULocationID"
DO_COL = "DOLocationID"
DIST_COL = "trip_distance"
FARE_COL = "fare_amount"
TOTAL_COL = "total_amount"

USE_COLS = [PICKUP_COL, DROPOFF_COL, PU_COL, DO_COL,
            DIST_COL, FARE_COL, TOTAL_COL]


def _read_month(year: int, month: int, taxi_type: str) -> pd.DataFrame:
    path = cfg.trip_raw_path(year, month, taxi_type)
    if not path.exists():
        raise FileNotFoundError(
            f"missing parquet: {path}\nrun 01_download_tlc.py first"
        )
    print(f"  reading {path.name} ...", end=" ", flush=True)
    df = pd.read_parquet(path, columns=USE_COLS)
    print(f"{len(df):,} rows")
    return df


def _step(name: str, df: pd.DataFrame, log: list[dict]) -> None:
    log.append({"step": name, "rows": len(df)})


def _clean(df: pd.DataFrame, year: int, month: int, log: list[dict]) -> pd.DataFrame:
    _step("raw", df, log)

    df = df.dropna(subset=[PICKUP_COL, DROPOFF_COL])
    _step("drop_null_times", df, log)

    df = df.dropna(subset=[PU_COL, DO_COL])
    df[PU_COL] = df[PU_COL].astype("int32")
    df[DO_COL] = df[DO_COL].astype("int32")
    _step("drop_null_locations", df, log)

    df = df[(df[DIST_COL] > cfg.TRIP_DISTANCE_MIN)
            & (df[DIST_COL] <= cfg.TRIP_DISTANCE_MAX)]
    _step("trip_distance_in_range", df, log)

    duration_min = (df[DROPOFF_COL] - df[PICKUP_COL]).dt.total_seconds() / 60.0
    df = df[(duration_min >= cfg.TRIP_DURATION_MIN_MINUTES)
            & (duration_min <= cfg.TRIP_DURATION_MAX_MINUTES)]
    _step("duration_in_range", df, log)

    df = df[df[FARE_COL] > cfg.FARE_AMOUNT_MIN]
    _step("fare_positive", df, log)

    df = df[df[TOTAL_COL] > cfg.TOTAL_AMOUNT_MIN]
    _step("total_positive", df, log)

    period_start = pd.Timestamp(year=year, month=month, day=1)
    if month == 12:
        period_end = pd.Timestamp(year=year + 1, month=1, day=1)
    else:
        period_end = pd.Timestamp(year=year, month=month + 1, day=1)
    df = df[(df[PICKUP_COL] >= period_start) & (df[PICKUP_COL] < period_end)]
    _step("pickup_in_target_month", df, log)

    return df


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Clean and merge TLC trip parquet")
    p.add_argument("--year", type=int, default=cfg.DEFAULT_YEAR)
    p.add_argument("--months", type=int, nargs="+", default=cfg.DEFAULT_MONTHS)
    p.add_argument("--taxi-type", default=cfg.DEFAULT_TAXI_TYPE)
    p.add_argument("--out", type=Path, default=cfg.PROCESSED_DIR / "trips_clean.parquet")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    log: list[dict] = []
    frames: list[pd.DataFrame] = []
    for m in args.months:
        print(f"month {args.year}-{m:02d}")
        raw = _read_month(args.year, m, args.taxi_type)
        sub_log: list[dict] = []
        cleaned = _clean(raw, args.year, m, sub_log)
        for row in sub_log:
            row["month"] = f"{args.year}-{m:02d}"
            log.append(row)
        frames.append(cleaned)

    merged = pd.concat(frames, ignore_index=True)
    print()
    print(f"merged total: {len(merged):,} rows")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    merged.to_parquet(args.out, index=False)
    print(f"written → {args.out}")

    log_df = pd.DataFrame(log)[["month", "step", "rows"]]
    summary_path = cfg.TABLES_DIR / "cleaning_summary.csv"
    log_df.to_csv(summary_path, index=False)
    print(f"cleaning summary → {summary_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
