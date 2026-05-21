"""
run_preprocess.py — 一键串起 01 → 02 → 03 → 04（→ 05 可选）。

用法：
    python code/python/run_preprocess.py --year 2024 --months 1 2 3 --topk 50

如果原始 parquet 已经下载好，可加 --skip-download 跳过第一步。
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import _config as cfg  # noqa: E402


def _run(script: str, *args: str) -> None:
    cmd = [sys.executable, str(HERE / script), *args]
    print(f"\n$ {' '.join(cmd)}")
    res = subprocess.run(cmd, check=False)
    if res.returncode != 0:
        raise SystemExit(f"step failed: {script} (exit {res.returncode})")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run full preprocess pipeline")
    p.add_argument("--year", type=int, default=cfg.DEFAULT_YEAR)
    p.add_argument("--months", type=int, nargs="+", default=cfg.DEFAULT_MONTHS)
    p.add_argument("--taxi-type", default=cfg.DEFAULT_TAXI_TYPE)
    p.add_argument("--topk", type=int, default=cfg.DEFAULT_TOPK)
    p.add_argument("--skip-download", action="store_true")
    p.add_argument("--skip-maps", action="store_true", default=True,
                   help="default true — maps are optional and need shapefile")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    months = [str(m) for m in args.months]

    if not args.skip_download:
        _run("01_download_tlc.py",
             "--year", str(args.year),
             "--months", *months,
             "--taxi-type", args.taxi_type)
    else:
        print("[skip] 01_download_tlc.py")

    _run("02_preprocess_trips.py",
         "--year", str(args.year),
         "--months", *months,
         "--taxi-type", args.taxi_type)

    _run("03_build_features.py",
         "--topk", str(args.topk))

    _run("04_build_cost_matrix.py")

    if not args.skip_maps:
        _run("05_optional_maps.py")

    print()
    print("=" * 60)
    print("preprocessing complete")
    print("=" * 60)
    print(f"processed dir: {cfg.PROCESSED_DIR}")
    print("Next step: open 北太天元, cd code/beita, run `run_all`")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
