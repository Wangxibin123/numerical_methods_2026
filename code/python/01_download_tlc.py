"""
01_download_tlc.py — 下载 NYC TLC trip data + taxi zone lookup。

用法：
    python code/python/01_download_tlc.py --year 2024 --months 1 2 3 --taxi-type yellow

如果下载失败，会提示手动从 NYC TLC 官方页面下载到 data/raw/。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import requests
from tqdm import tqdm

sys.path.insert(0, str(Path(__file__).resolve().parent))

import _config as cfg  # noqa: E402


def _download(url: str, dest: Path, chunk_size: int = 1 << 20) -> bool:
    """Stream-download with progress bar. Returns True on success."""
    if dest.exists() and dest.stat().st_size > 0:
        print(f"  [skip] already exists: {dest.name} ({dest.stat().st_size / 1e6:.1f} MB)")
        return True

    try:
        with requests.get(url, stream=True, timeout=30) as r:
            r.raise_for_status()
            total = int(r.headers.get("Content-Length", 0))
            dest.parent.mkdir(parents=True, exist_ok=True)
            tmp = dest.with_suffix(dest.suffix + ".part")
            with open(tmp, "wb") as f, tqdm(
                total=total, unit="B", unit_scale=True, desc=dest.name
            ) as pbar:
                for chunk in r.iter_content(chunk_size=chunk_size):
                    if not chunk:
                        continue
                    f.write(chunk)
                    pbar.update(len(chunk))
            tmp.rename(dest)
        return True
    except Exception as exc:  # noqa: BLE001
        print(f"  [fail] {url}")
        print(f"         {exc!r}")
        return False


def download_lookup() -> bool:
    print("Taxi zone lookup CSV ...")
    return _download(cfg.TAXI_ZONE_LOOKUP_URL, cfg.lookup_raw_path())


def download_trip(year: int, month: int, taxi_type: str) -> bool:
    url = cfg.trip_url(year, month, taxi_type)
    dest = cfg.trip_raw_path(year, month, taxi_type)
    print(f"Trip data {taxi_type} {year}-{month:02d} ...")
    return _download(url, dest)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Download NYC TLC trip data")
    p.add_argument("--year", type=int, default=cfg.DEFAULT_YEAR)
    p.add_argument("--months", type=int, nargs="+", default=cfg.DEFAULT_MONTHS)
    p.add_argument(
        "--taxi-type",
        choices=("yellow", "green", "fhv", "fhvhv"),
        default=cfg.DEFAULT_TAXI_TYPE,
    )
    p.add_argument(
        "--skip-lookup",
        action="store_true",
        help="Do not download taxi_zone_lookup.csv",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()

    print(f"Target: {args.taxi_type} {args.year} months={args.months}")
    print(f"Output: {cfg.RAW_DIR}")
    print()

    failures: list[str] = []

    if not args.skip_lookup:
        if not download_lookup():
            failures.append("taxi_zone_lookup.csv")

    for m in args.months:
        if not download_trip(args.year, m, args.taxi_type):
            failures.append(f"{args.taxi_type}_tripdata_{args.year}-{m:02d}.parquet")

    if failures:
        print()
        print("=" * 60)
        print("Some downloads failed. Please grab them manually from")
        print("    https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page")
        print("and place into", cfg.RAW_DIR)
        print()
        for f in failures:
            print(f"  - {f}")
        return 1

    print()
    print("All downloads complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
