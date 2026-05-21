"""
06_validate.py — Strict integrity check of processed/*.csv before 北太天元 ingestion.

Asserts that every downstream invariant 北太天元 relies on actually holds:
    1. file existence + non-empty
    2. panel column count == panel_columns.txt
    3. panel sort: rows are stably sorted by (zone_id, hour_index)
    4. for each top zone, hour_index is strictly contiguous (no missing hours)
    5. cost_matrix is K x K, diagonal == 0, off-diagonal > 0, finite
    6. test_hours are entirely inside the test split
    7. panel.split_id fractions are within tolerance of cfg defaults
    8. no NaN / no negative pickup/dropoff
    9. lag/rolling features have NO NaN (fill must have happened)
    10. top_zones.csv length matches cost_matrix dimension

If any assertion fails, exit with non-zero code and a clear error.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))

import _config as cfg  # noqa: E402


def fail(msg: str) -> None:
    print(f"\n[FAIL] {msg}")
    raise SystemExit(2)


def ok(msg: str) -> None:
    print(f"  [ok] {msg}")


def main() -> int:
    print("== data validation ==")
    P = cfg.PROCESSED_DIR

    # 1. files exist & non-empty
    required = [
        "panel_numeric.csv",
        "panel_numeric_noheader.csv",
        "panel_columns.txt",
        "zone_meta.csv",
        "top_zones.csv",
        "cost_matrix_topK.csv",
        "test_hours.csv",
    ]
    for name in required:
        p = P / name
        if not p.exists():
            fail(f"missing {p}")
        if p.stat().st_size == 0:
            fail(f"empty {p}")
        ok(f"{name} ({p.stat().st_size:,} bytes)")

    # 2. column count consistency
    col_names = [ln for ln in (P / "panel_columns.txt").read_text().splitlines() if ln.strip()]
    panel = pd.read_csv(P / "panel_numeric.csv")
    if list(panel.columns) != col_names:
        fail(f"panel columns mismatch:\n  csv: {list(panel.columns)}\n  txt: {col_names}")
    ok(f"panel has {len(col_names)} columns matching panel_columns.txt")

    panel_nh = pd.read_csv(P / "panel_numeric_noheader.csv", header=None)
    if panel_nh.shape != panel.shape:
        fail(f"noheader shape {panel_nh.shape} ≠ headered shape {panel.shape}")
    ok(f"noheader csv shape matches: {panel.shape}")

    # 3. sort order: (zone_id, hour_index) ascending, stable
    sort_key = list(zip(panel["zone_id"], panel["hour_index"]))
    is_sorted = all(sort_key[i] <= sort_key[i + 1] for i in range(len(sort_key) - 1))
    if not is_sorted:
        fail("panel is NOT sorted by (zone_id, hour_index) ascending")
    ok("panel rows sorted by (zone_id, hour_index) ascending")

    # 4. per-zone contiguous hours
    top_zones = pd.read_csv(P / "top_zones.csv")["zone_id"].astype(int).tolist()
    bad = []
    for z in top_zones:
        h = panel.loc[panel["zone_id"] == z, "hour_index"].to_numpy()
        if len(h) == 0:
            bad.append((z, "no rows"))
            continue
        diffs = np.diff(h)
        if (diffs != 1).any():
            bad.append((z, f"gaps={int((diffs != 1).sum())}"))
    if bad:
        fail(f"non-contiguous hours in {len(bad)} zones, e.g. {bad[:5]}")
    ok(f"all {len(top_zones)} zones have strictly contiguous hour_index")

    # 5. cost matrix sanity
    C = np.loadtxt(P / "cost_matrix_topK.csv", delimiter=",")
    K = len(top_zones)
    if C.shape != (K, K):
        fail(f"cost matrix {C.shape} ≠ ({K},{K})")
    if not np.allclose(np.diag(C), 0):
        fail("cost matrix diagonal not all zeros")
    off = C[~np.eye(K, dtype=bool)]
    if not np.isfinite(off).all():
        fail("cost matrix has NaN/inf off-diagonal entries")
    if (off <= 0).any():
        fail(f"cost matrix has non-positive off-diagonal entries (min={off.min()})")
    ok(f"cost matrix {K}x{K}, diag=0, off-diag finite > 0 (range {off.min():.3f} – {off.max():.3f})")

    # 6. test_hours inside test split
    th = pd.read_csv(P / "test_hours.csv")
    if "hour_index" not in th.columns:
        fail("test_hours.csv missing hour_index column")
    test_hours_set = set(th["hour_index"].astype(int).tolist())
    test_panel_hours = set(panel.loc[panel["split_id"] == 2, "hour_index"].astype(int).tolist())
    leaked = test_hours_set - test_panel_hours
    if leaked:
        fail(f"{len(leaked)} test_hours not in test split, e.g. {list(leaked)[:5]}")
    ok(f"{len(test_hours_set)} test_hours all lie in test split")

    # 7. split fractions
    n = len(panel)
    fr = [(panel["split_id"] == s).sum() / n for s in (0, 1, 2)]
    tol = 0.05
    target = (cfg.DEFAULT_TRAIN_FRAC, cfg.DEFAULT_VAL_FRAC, cfg.DEFAULT_TEST_FRAC)
    for i, (got, want) in enumerate(zip(fr, target)):
        if abs(got - want) > tol:
            fail(f"split[{i}] = {got:.4f}, want {want:.4f} ± {tol}")
    ok(f"split fractions train/val/test = {fr[0]:.3f}/{fr[1]:.3f}/{fr[2]:.3f}")

    # 8. no NaN, no negative counts
    if panel.isna().any().any():
        nans = panel.isna().sum()
        fail(f"NaN in panel: {nans[nans>0].to_dict()}")
    ok("panel has zero NaN cells")

    for c in ("pickup_count", "dropoff_count"):
        if (panel[c] < 0).any():
            fail(f"negative values in {c}")
    ok("pickup_count, dropoff_count ≥ 0")

    # 9. lag/rolling features fully filled
    feature_cols = [c for c in panel.columns
                    if c.startswith(("lag_", "rolling_", "same_hour_"))]
    nan_feat = panel[feature_cols].isna().sum()
    if (nan_feat > 0).any():
        fail(f"NaN in feature columns: {nan_feat[nan_feat>0].to_dict()}")
    ok(f"{len(feature_cols)} lag/rolling/same_hour features all filled")

    # 10. zone counts
    if len(top_zones) != C.shape[0]:
        fail(f"top_zones count {len(top_zones)} ≠ cost matrix dim {C.shape[0]}")
    if panel["zone_id"].nunique() != len(top_zones):
        fail(f"panel has {panel['zone_id'].nunique()} unique zones, top_zones has {len(top_zones)}")
    ok(f"top_zones / panel_zones / cost dim all agree at K={K}")

    # 11. cleaning_summary sanity
    cs_path = cfg.TABLES_DIR / "cleaning_summary.csv"
    if cs_path.exists():
        cs = pd.read_csv(cs_path)
        last_rows = cs.groupby("month")["rows"].last()
        first_rows = cs.groupby("month")["rows"].first()
        survived = (last_rows / first_rows).round(4)
        for m, frac in survived.items():
            if frac < 0.50:
                fail(f"month {m}: only {frac:.2%} rows survived cleaning — too aggressive?")
            if frac > 1.0:
                fail(f"month {m}: survival ratio {frac:.4f} > 1 — accounting bug")
        ok(f"cleaning survival ratios per month: {survived.to_dict()}")

    print("\n== ALL VALIDATIONS PASSED ==")
    print(f"  panel rows : {len(panel):,}")
    print(f"  panel cols : {len(col_names)}")
    print(f"  zones (K)  : {K}")
    print(f"  test hours : {len(test_hours_set)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
