"""Independently verify Figure 4 ratios, aggregation, curves, and provenance."""
from pathlib import Path
import hashlib
import json
import tomllib

import numpy as np
import pandas as pd

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
ROOT = REPO / "code/downstream-evaluation"
DATA = ROOT / "results/variance-diagnostic"
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
metadata = tomllib.loads((DATA / "metadata.toml").read_text())
training = tomllib.loads((ROOT / "data/results-metadata.toml").read_text())
figure = tomllib.loads((DATA / "figure-metadata.toml").read_text())
assert metadata["training_signature"] == training["signature"]
assert metadata["training_cache_sha256"] == digest(ROOT / "data/results.jld2")
for name, expected in training["source_input_sha256"].items():
    assert digest(ROOT / name) == expected, name
for name, expected in training["artifact_sha256"].items():
    assert digest(ROOT / "data" / name) == expected, name
for record in (metadata, figure):
    for name, expected in record["source_sha256"].items():
        assert digest(ROOT / name) == expected, name
for name, expected in metadata["artifact_sha256"].items():
    assert digest(DATA / name) == expected, name
assert figure["diagnostic_metadata_sha256"] == digest(DATA / "metadata.toml")
assert figure["curve_sha256"] == digest(DATA / "figure-curves.csv")
for paper in ("arxiv-paper", "jfds-paper"):
    assert digest(REPO / paper / "figs/main/Fig06-Variance-Preservation.pdf") == figure["figure_sha256"]

paths = pd.read_csv(DATA / "paired-paths.csv", dtype={"ticker": str})
summary = pd.read_csv(DATA / "ticker-summary.csv", dtype={"ticker": str})
canonical = pd.read_csv(ROOT / "data/results.csv", dtype={"ticker": str})
canonical = canonical[canonical.composer.isin(["naive", "hybrid"])]
keys = ["ticker", "composer", "rep"]
assert len(paths) == len(canonical) == 84600
assert not paths.duplicated(keys).any()
counts = paths.groupby(["ticker", "composer"]).rep.agg(["count", "min", "max"])
assert (counts["count"] == 100).all() and (counts["min"] == 1).all() and (counts["max"] == 100).all()
joined = paths.merge(canonical, on=keys, validate="one_to_one", suffixes=("", "_canonical"))
np.testing.assert_array_equal(joined.variance_composed, joined.var_g)
np.testing.assert_array_equal(joined.ks_p, joined.ks_p_canonical)
np.testing.assert_array_equal(joined.beta_eff, joined.beta_eff_canonical)
assert (joined.loc[joined.composer == "hybrid", "branch"] == joined.loc[joined.composer == "hybrid", "flag"]).all()
for denominator in ("generator", "observed", "target"):
    np.testing.assert_allclose(paths[f"ratio_{denominator}"],
        paths.variance_composed / paths[f"variance_{denominator}"], rtol=2e-14)
np.testing.assert_allclose(paths.reference_generator, paths.variance_target / paths.variance_generator, rtol=2e-14)
np.testing.assert_allclose(paths.ratio_target - 1, paths.relative_cross_term, atol=1e-13, rtol=1e-11)
ordinary = paths[(paths.composer == "hybrid") & (paths.branch != "R2_PRESERVE")]
trackers = paths[(paths.composer == "hybrid") & (paths.branch == "R2_PRESERVE")]
naive = paths[paths.composer == "naive"]
assert ordinary.ticker.nunique() == 421 and set(trackers.ticker) == {"QQQ", "SPYG"}
assert set(ordinary.branch) == {"HYBRID"}
np.testing.assert_array_equal(ordinary.variance_target, ordinary.variance_generator)
np.testing.assert_allclose(trackers.variance_target,
    trackers.beta_cal**2 * trackers.variance_market / trackers.r2_cal, rtol=2e-14)
np.testing.assert_allclose(naive.reference_generator,
    1 + naive.beta_cal**2 * naive.variance_market / naive.variance_generator, rtol=2e-14)

paths["absolute_error"] = abs(paths.ratio_target - 1)
paths["ks_pass"] = (paths.ks_p > 0.05).astype(float)
group_keys = ["ticker", "composer", "branch"]
groups = paths.groupby(group_keys, sort=True)
expected = groups.agg(beta_cal=("beta_cal", "first"), ks_pass=("ks_pass", "mean"),
    ratio_generator=("ratio_generator", "median"), ratio_observed=("ratio_observed", "median"),
    ratio_target=("ratio_target", "median"), reference_generator=("reference_generator", "median"),
    median_absolute_target_error=("absolute_error", "median"),
    p95_absolute_target_error=("absolute_error", lambda x: x.quantile(0.95)))
actual = summary.set_index(group_keys).sort_index()
np.testing.assert_allclose(actual[expected.columns], expected, atol=2e-14, rtol=2e-13)

# Independently reproduce the plotted weighted medians, excluding trackers.
curves = pd.read_csv(DATA / "figure-curves.csv")
max_curve_error = 0.0
for (panel, method), curve in curves.groupby(["panel", "composer"]):
    subset = summary[(summary.composer == method) & (summary.branch != "R2_PRESERVE")]
    field = "ks_pass" if panel == "a" else "reference_generator"
    x, y = subset.beta_cal.to_numpy(), subset[field].to_numpy()
    grid = np.linspace(x.min(), x.max(), 80)
    np.testing.assert_allclose(curve.beta, grid, atol=1e-14)
    order = np.argsort(y, kind="stable")
    for point, value in zip(grid, curve.value):
        weights = np.exp(-0.5 * ((x - point) / 0.15)**2)[order]
        cumulative = np.cumsum(weights)
        prediction = y[order[np.searchsorted(cumulative, cumulative[-1] / 2)]]
        max_curve_error = max(max_curve_error, abs(value - prediction))
assert max_curve_error < 2e-14

hybrid_summary = summary[(summary.composer == "hybrid") & (summary.branch == "HYBRID")]
naive_summary = summary[(summary.composer == "naive") & (summary.branch == "HYBRID")]
report = {
    "paired_composed_paths": len(paths), "ordinary_assets": 421, "tracker_assets": ["QQQ", "SPYG"],
    "all_canonical_variances_ks_values_loadings_and_branches_match": True,
    "all_denominators_targets_and_covariance_identities_match": True,
    "all_846_ticker_method_summaries_match": True,
    "all_240_curve_points_match": True, "maximum_curve_difference": max_curve_error,
    "ordinary_naive_median_ticker_ratio": float(naive_summary.ratio_generator.median()),
    "ordinary_hybrid_median_ticker_ratio": float(hybrid_summary.ratio_generator.median()),
    "ordinary_hybrid_ticker_ratio_range": [float(hybrid_summary.ratio_generator.min()), float(hybrid_summary.ratio_generator.max())],
    "ordinary_hybrid_path_absolute_target_error_quantiles": np.quantile(abs(ordinary.ratio_target - 1), [0.5, 0.95, 1]).tolist(),
    "annualized_market_variance": metadata["annualized_market_variance"],
    "training_sources_and_artifacts_unchanged": True, "figure_sha256": figure["figure_sha256"],
}
(OUT / "numerical-checks.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
