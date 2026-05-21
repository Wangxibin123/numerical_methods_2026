"""
00_config.py — 可独立运行的配置检查脚本。

Python 不允许 `import 00_config`（数字开头），真正可导入的同名配置在
`_config.py`。请勿在此文件添加常量，否则其它脚本读不到。

用法：
    python code/python/00_config.py     # 打印当前默认配置和路径
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import _config as cfg  # noqa: E402


def main() -> None:
    print("=" * 60)
    print("NYC TLC Taxi Rebalancing — Project Config")
    print("=" * 60)
    print(f"REPO_ROOT     : {cfg.REPO_ROOT}")
    print(f"RAW_DIR       : {cfg.RAW_DIR}")
    print(f"PROCESSED_DIR : {cfg.PROCESSED_DIR}")
    print(f"TABLES_DIR    : {cfg.TABLES_DIR}")
    print(f"FIGURES_DIR   : {cfg.FIGURES_DIR}")
    print()
    print(f"taxi_type     : {cfg.DEFAULT_TAXI_TYPE}")
    print(f"year / months : {cfg.DEFAULT_YEAR} / {cfg.DEFAULT_MONTHS}")
    print(f"topK          : {cfg.DEFAULT_TOPK}")
    print(f"time resol.   : {cfg.DEFAULT_TIME_RESOLUTION}")
    print(f"train / val / test : {cfg.DEFAULT_TRAIN_FRAC} / "
          f"{cfg.DEFAULT_VAL_FRAC} / {cfg.DEFAULT_TEST_FRAC}")
    print(f"random seed   : {cfg.RANDOM_SEED}")
    print()
    print(f"Trip URL (sample): {cfg.trip_url(cfg.DEFAULT_YEAR, cfg.DEFAULT_MONTHS[0])}")
    print(f"Zone lookup URL  : {cfg.TAXI_ZONE_LOOKUP_URL}")


if __name__ == "__main__":
    main()
