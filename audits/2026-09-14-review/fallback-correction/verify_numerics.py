"""Independent inventory, paired-score, Monte Carlo SE, and table checks."""
from pathlib import Path
import hashlib
import json
import re
import tomllib
import numpy as np
import pandas as pd

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
ROOT = REPO / "code/downstream-evaluation"
DATA = ROOT / "results/fallback-diagnostic"
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
meta = tomllib.loads((DATA / "metadata.toml").read_text())
training = tomllib.loads((ROOT / "data/results-metadata.toml").read_text())
assert meta["training_signature"] == training["signature"]
for key, directory, record in (("source_sha256", ROOT, meta), ("artifact_sha256", DATA, meta),
    ("source_input_sha256", ROOT, training), ("artifact_sha256", ROOT / "data", training),
    ("fitted_cache_sha256", ROOT / "data", training)):
    for name, expected in record[key].items():
        assert digest(directory / name) == expected, name

read = lambda name: pd.read_csv(DATA / name, dtype={"ticker": str})
full, residual = read("state-inventory.csv"), read("residual-state-inventory.csv")
assets, residual_assets = read("asset-summary.csv"), read("residual-asset-summary.csv")
for states, summary, count in ((full, assets, 424), (residual, residual_assets, 423)):
    assert len(states) == 100*count and len(summary) == count
    assert not states.duplicated(["ticker", "state"]).any()
    assert (states.groupby("ticker").observations.sum() == 2766).all()
    assert (states.groupby("ticker").outgoing_count.sum() == 2765).all()
    np.testing.assert_allclose(states.groupby("ticker").stationary_mass.sum(), 1, atol=2e-14)
    expected_reason = np.where(states.observations < 2, "sparse",
        np.where(states.empirical_scale < 1e-12, "near_constant", "none"))
    np.testing.assert_array_equal(states.reason, expected_reason)
    np.testing.assert_array_equal(states.uniform_transition, states.outgoing_count == 0)
    sparse = states[states.reason == "sparse"]
    dense = states[states.reason == "near_constant"]
    regular = states[states.reason == "none"]
    np.testing.assert_array_equal(sparse.fitted_mean, sparse.global_mean)
    np.testing.assert_array_equal(sparse.fitted_scale, sparse.global_scale)
    np.testing.assert_array_equal(dense.fitted_mean, dense.empirical_mean)
    np.testing.assert_array_equal(dense.fitted_scale, dense.global_scale)
    np.testing.assert_array_equal(regular.fitted_mean, regular.empirical_mean)
    np.testing.assert_array_equal(regular.fitted_scale, regular.empirical_scale)
    for ticker, state in states.groupby("ticker"):
        row = summary.set_index("ticker").loc[ticker]
        fallback = state[state.reason != "none"]
        tied = state[state.reason == "near_constant"]
        assert len(fallback) == row.fallback_states and len(tied) == row.near_constant_states
        assert tied.observations.sum() == row.near_constant_observations
        assert (state.observations == 0).sum() == row.empty_states
        assert (state.observations == 1).sum() == row.singleton_states
        assert state.uniform_transition.sum() == row.uniform_transition_rows
        np.testing.assert_allclose(fallback.stationary_mass.sum(), row.fallback_stationary_mass, atol=2e-15)
        mean = (state.stationary_mass * state.fitted_mean).sum()
        original = (state.stationary_mass * ((state.fitted_mean-mean)**2
            + state.fitted_scale**2 * state.nu/(state.nu-2))).sum()
        new_scale = np.where(state.reason == "near_constant", state.empirical_scale, state.fitted_scale)
        alternative = (state.stationary_mass * ((state.fitted_mean-mean)**2
            + new_scale**2 * state.nu/(state.nu-2))).sum()
        np.testing.assert_allclose([row.fitted_mixture_variance, row.alternative_mixture_variance],
            [original, alternative], rtol=3e-14)
        np.testing.assert_allclose(row.relative_mixture_variance_change,
            (alternative-original)/original, atol=2e-14)
assert full.reason.value_counts().to_dict() == {"none": 42350, "near_constant": 39, "sparse": 11}
assert (full.loc[full.reason == "near_constant", "distinct_observations"] == 1).all()
assert (residual.reason == "none").all()
affected = assets[assets.fallback_states > 0]
assert len(affected) == 39

paths = read("paired-paths.csv")
assert len(paths) == 23400 and not paths.duplicated(["ticker", "rep", "method", "treatment"]).any()
assert set(paths.ticker) == set(affected.ticker)
counts = paths.groupby(["ticker", "method", "treatment"]).rep.agg(["count", "min", "max"])
assert (counts["count"] == 100).all() and (counts["min"] == 1).all() and (counts["max"] == 100).all()
canonical = pd.read_csv(ROOT / "data/results.csv", dtype={"ticker": str})
original = paths[(paths.treatment == "as_fitted") & (paths.method != "uncomposed")]
joined = original.merge(canonical, left_on=["ticker", "method", "rep"],
    right_on=["ticker", "composer", "rep"], validate="one_to_one", suffixes=("", "_cache"))
assert len(joined) == 7800
for name in ["α_hat", "β_hat", "R²_hat", "ks_p", "ad_p", "w1", "hill_up", "kurt", "var_g", "beta_eff"]:
    np.testing.assert_array_equal(joined[name], joined[name+"_cache"])
np.testing.assert_array_equal(joined.branch, joined.flag)
np.testing.assert_array_equal(paths.ks_pass, (paths.ks_p > .05).astype(float))
np.testing.assert_array_equal(paths.ad_pass, (paths.ad_p > .05).astype(float))

results = read("sensitivity-summary.csv")
max_summary_error = 0.0
for row in results.itertuples():
    pairs = paths[paths.method == row.method].pivot(index=["ticker", "rep"], columns="treatment", values=row.metric)
    multiplier = 100 if row.metric in ("ks_pass", "ad_pass") else 1
    difference = multiplier*(pairs.empirical_scale-pairs.as_fitted)
    replication_means = difference.groupby("rep").mean()
    expected = [multiplier*pairs.as_fitted.mean(), multiplier*pairs.empirical_scale.mean(),
        difference.mean(), replication_means.std(ddof=1)/np.sqrt(100)]
    actual = [row.as_fitted, row.empirical_scale, row.paired_difference, row.paired_mc_se]
    np.testing.assert_allclose(actual, expected, atol=2e-13, rtol=2e-13)
    max_summary_error = max(max_summary_error, float(np.max(np.abs(np.array(actual)-expected))))

table_metadata = json.loads((DATA / "tables-metadata.json").read_text())
assert digest(ROOT / "scripts/17-Fallback-Tables.py") == table_metadata["formatter_sha256"]
assert digest(DATA / "metadata.toml") == table_metadata["diagnostic_metadata_sha256"]
for name, expected in table_metadata["table_sha256"].items():
    assert digest(REPO / name) == expected, name
for row in affected.itertuples():
    expected = " & ".join([row.ticker, str(row.near_constant_observations), str(row.empty_states),
        str(row.singleton_states), f"{100*row.fallback_stationary_mass:.3f}",
        f"{100*row.relative_mixture_variance_change:.3f}"]) + " " + chr(92)*2
    for paper in ("arxiv-paper", "jfds-paper"):
        assert expected in (REPO / paper / "sections/tables/tableS_fallback_assets.tex").read_text()

for paper in ("arxiv-paper", "jfds-paper"):
    printed = (REPO / paper / "sections/tables/tableS_fallback_sensitivity.tex").read_text()
    checked = set()
    method = None
    metric_names = {"KS pass": "ks_pass", "AD pass": "ad_pass", "$W_1$": "w1",
        "Variance / observed": "variance_ratio_observed", "ACF-MAE": "acf_mae25"}
    for line in printed.splitlines():
        if " & " not in line or line.startswith("Output &"):
            continue
        cells = [cell.strip() for cell in line.removesuffix(chr(92)*2).split(" & ")]
        if cells[0]:
            method = cells[0].lower()
        metric = next(value for label, value in metric_names.items() if cells[1].startswith(label))
        key = (method, metric)
        assert key not in checked
        checked.add(key)
        row = results[(results.method == method) & (results.metric == metric)].iloc[0]
        numbers = cells[2:4] + re.findall(r"[+-]?\d+\.\d+", cells[4])
        assert len(numbers) == 4
        for number, name in zip(numbers, ("as_fitted", "empirical_scale", "paired_difference", "paired_mc_se")):
            decimals = len(number.split(".")[1])
            assert abs(float(number)-row[name]) <= 0.5*10**(-decimals)+1e-12, (paper, key, name)
    assert checked == set(zip(results.method, results.metric)) and len(checked) == 15

hybrid = paths[paths.method == "hybrid"].pivot(index=["ticker", "rep"], columns="treatment", values="ks_pass")
asset_changes = (100*(hybrid.empirical_scale-hybrid.as_fitted)).groupby("ticker").mean()
report = {"full_return_states": len(full), "residual_states": len(residual),
    "fallback_models": 39, "fallback_states": 50, "constant_states": 39, "empty_states": 7, "singleton_states": 4,
    "canonical_paths_replayed": len(joined), "all_nine_metrics_and_loadings_exact": True,
    "paired_score_rows": len(paths), "all_15_comparisons_and_standard_errors_match": True,
    "maximum_summary_difference": max_summary_error,
    "asset_hybrid_ks_changes": {"increased": int((asset_changes>0).sum()), "unchanged": int((asset_changes==0).sum()),
        "decreased": int((asset_changes<0).sum()), "range_percentage_points": [float(asset_changes.min()),float(asset_changes.max())]},
    "fallback_mass_range": [float(affected.fallback_stationary_mass.min()),float(affected.fallback_stationary_mass.max())],
    "sparse_mass_maximum": float(affected.sparse_stationary_mass.max()),
    "mixture_variance_change_range": [float(affected.relative_mixture_variance_change.min()),float(affected.relative_mixture_variance_change.max())],
    "training_sources_and_artifacts_unchanged": True, "tables_match": True}
(OUT / "numerical-checks.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report,indent=2))
