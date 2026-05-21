"""
_config.py — 真正可被其它脚本 `from _config import ...` 的全局配置。

`00_config.py` 是同内容的可独立运行入口（数字开头无法 import），
两者保持一致；如要改默认值，**改这里**。
"""

from __future__ import annotations

from pathlib import Path

# ----------------------------- paths ---------------------------------------
THIS_FILE = Path(__file__).resolve()
REPO_ROOT = THIS_FILE.parent.parent.parent

DATA_DIR = REPO_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"

RESULTS_DIR = REPO_ROOT / "results"
TABLES_DIR = RESULTS_DIR / "tables"
FIGURES_DIR = RESULTS_DIR / "figures"

for _p in (RAW_DIR, PROCESSED_DIR, TABLES_DIR, FIGURES_DIR):
    _p.mkdir(parents=True, exist_ok=True)

# ----------------------------- TLC source ----------------------------------
TLC_CLOUDFRONT = "https://d37ci6vzurychx.cloudfront.net"
TLC_TRIP_PREFIX = f"{TLC_CLOUDFRONT}/trip-data"
TLC_MISC_PREFIX = f"{TLC_CLOUDFRONT}/misc"
TAXI_ZONE_LOOKUP_URL = f"{TLC_MISC_PREFIX}/taxi_zone_lookup.csv"

# ----------------------------- defaults ------------------------------------
DEFAULT_TAXI_TYPE = "yellow"           # yellow | green | fhv | fhvhv
DEFAULT_YEAR = 2024
DEFAULT_MONTHS = [1, 2, 3]
DEFAULT_TOPK = 50
DEFAULT_TIME_RESOLUTION = "1h"

DEFAULT_TRAIN_FRAC = 0.70
DEFAULT_VAL_FRAC = 0.15
DEFAULT_TEST_FRAC = 0.15

COST_DIAGONAL = 0.0
COST_GLOBAL_FALLBACK_MULTIPLIER = 1.5

TRIP_DISTANCE_MIN = 0.0
TRIP_DISTANCE_MAX = 100.0
TRIP_DURATION_MIN_MINUTES = 1.0
TRIP_DURATION_MAX_MINUTES = 180.0
FARE_AMOUNT_MIN = 0.0
TOTAL_AMOUNT_MIN = 0.0

N_TEST_HOURS = 24
RANDOM_SEED = 20260521


def trip_url(year: int, month: int, taxi_type: str = DEFAULT_TAXI_TYPE) -> str:
    """Cloudfront direct link, e.g. yellow_tripdata_2024-01.parquet."""
    fname = f"{taxi_type}_tripdata_{year:04d}-{month:02d}.parquet"
    return f"{TLC_TRIP_PREFIX}/{fname}"


def trip_raw_path(year: int, month: int, taxi_type: str = DEFAULT_TAXI_TYPE) -> Path:
    fname = f"{taxi_type}_tripdata_{year:04d}-{month:02d}.parquet"
    return RAW_DIR / fname


def lookup_raw_path() -> Path:
    return RAW_DIR / "taxi_zone_lookup.csv"
