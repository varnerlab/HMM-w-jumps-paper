"""Read-only checks of published CSV summaries and source fingerprints.

Run from the repository root: python3 audits/2026-09-14-review/verify_artifacts.py
Requires Python 3.11+, pandas and numpy.
"""
from pathlib import Path
import hashlib
import tomllib
import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "code/downstream-evaluation"
DIRECTORY = ROOT / "results/jump-ablation"

settings = tomllib.loads((DIRECTORY / "settings.toml").read_text())
for key, name in (
    ("ablation_source_sha256", "src/JumpAblation.jl"),
    ("composer_source_sha256", "src/Composers.jl"),
    ("metrics_source_sha256", "src/Metrics.jl"),
    ("pipeline_source_sha256", "src/Pipeline.jl"),
    ("manifest_sha256", "Manifest.toml"),
    ("base_config_sha256", "config.toml"),
    ("universe_sha256", "data/universe.jld2"),
    ("calibration_sha256", "data/sim-calibration.jld2"),
):
    matches = settings["provenance"][key] == hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    print("Fingerprint", name, matches)
    assert matches

replications = pd.read_csv(DIRECTORY / "replication-metrics.csv")
tickers = pd.read_csv(DIRECTORY / "ticker-metrics.csv")
summary = pd.read_csv(DIRECTORY / "summary.csv")
contrasts = pd.read_csv(DIRECTORY / "paired-contrasts.csv")
keys = ["window", "scenario", "method"]
metrics = [name for name in summary.columns if name not in keys]
published = summary.set_index(keys).sort_index()
by_rep = replications.groupby(keys)[metrics].mean().sort_index()
by_ticker = tickers.groupby(keys)[metrics].mean().sort_index()
print("Jump data shapes", replications.shape, tickers.shape, summary.shape, contrasts.shape)
print("Replication aggregation maximum error", np.max(np.abs(published.values - by_rep.values)))
print("Ticker aggregation maximum error", np.max(np.abs(published.values - by_ticker.values)))
assert np.allclose(published.values, by_rep.values, atol=1e-12)
assert np.allclose(published.values, by_ticker.values, atol=1e-12)

errors = []
for _, row in contrasts.iterrows():
    before_case, before_method = row.baseline.split("/")
    after_case, after_method = row.changed.split("/")
    def values(case, method):
        return replications[
            (replications.window == row.window)
            & (replications.scenario == case)
            & (replications.method == method)
        ].sort_values(["seed", "rep"])[row.metric].values
    delta = values(after_case, after_method) - values(before_case, before_method)
    se = delta.std(ddof=1) / len(delta) ** 0.5
    errors.append(max(abs(delta.mean() - row.mean_difference), abs(se - row.mc_se)))
print("Paired contrast and SE maximum error", max(errors))
assert max(errors) < 1e-12

old = pd.read_csv(ROOT / "data/results-summary.csv")
print("\nTraining CSV rows and methods", len(old), sorted(old.composer.unique()))
print(old.groupby("composer").agg(
    assets=("ticker", "nunique"), paths=("rep", "size"),
    KS=("ks_p", lambda x: 100 * (x > 0.05).mean()), W1=("w1", "median"),
).to_string())
print("\nPublished holdout summary")
print(pd.read_csv(ROOT / "data/results-oos-summary.csv").to_string(index=False))
print("\nPublished holdout VaR summary")
print(pd.read_csv(ROOT / "data/var-backtest-oos-summary.csv").to_string(index=False))
