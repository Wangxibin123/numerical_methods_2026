"""
05_optional_maps.py — 可选地图可视化（仅在 geopandas 可用且有 Shapefile 时执行）。

不强制依赖。该脚本输出的图是 *补充* 性质的，不会被北太天元主流水线使用，
仅用于报告附录中的“NYC 地图 + top-K zone 着色”。

如果未提供 Shapefile，会打印一条说明并退出 0。
"""

from __future__ import annotations

import argparse
import sys
import warnings
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import _config as cfg  # noqa: E402


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Optional NYC taxi zone map render")
    p.add_argument("--shapefile", type=Path,
                   default=cfg.RAW_DIR / "taxi_zones" / "taxi_zones.shp")
    p.add_argument("--zones", type=Path,
                   default=cfg.PROCESSED_DIR / "top_zones.csv")
    p.add_argument("--out", type=Path,
                   default=cfg.FIGURES_DIR / "fig_map_topk_zones.png")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if not args.shapefile.exists():
        print(f"shapefile not found: {args.shapefile}")
        print("Skipping map. To enable: download Taxi Zone Shapefile from")
        print("    https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page")
        print(f"and extract to {args.shapefile.parent}")
        return 0

    try:
        import geopandas as gpd  # type: ignore
        import matplotlib.pyplot as plt
        import pandas as pd
    except Exception as exc:  # noqa: BLE001
        print("geopandas / matplotlib not available — skip optional map.")
        print(f"  {exc!r}")
        return 0

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        gdf = gpd.read_file(args.shapefile)

    top = set(pd.read_csv(args.zones)["zone_id"].astype(int).tolist())
    gdf["is_top"] = gdf["LocationID"].astype(int).isin(top)

    fig, ax = plt.subplots(figsize=(8, 10))
    gdf.plot(ax=ax, color="#cccccc", edgecolor="white", linewidth=0.3)
    gdf[gdf["is_top"]].plot(ax=ax, color="#1f77b4", edgecolor="white", linewidth=0.5)
    ax.set_title(f"NYC TLC top {len(top)} taxi zones (training-period pickup volume)")
    ax.set_axis_off()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.out, dpi=180, bbox_inches="tight")
    print(f"  → {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
