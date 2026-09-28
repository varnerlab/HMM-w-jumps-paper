"""Independently aggregate canonical path CSVs and check all three table bodies."""
from pathlib import Path
import hashlib
import json
import tomllib

import numpy as np
import pandas as pd

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
ROOT = REPO / "code/downstream-evaluation"
DATA = ROOT / "data"
metadata = tomllib.loads((DATA / "results-metadata.toml").read_text())
for name, expected in metadata["artifact_sha256"].items():
    assert hashlib.sha256((DATA / name).read_bytes()).hexdigest() == expected, name
r = pd.read_csv(DATA / "results.csv", dtype={"ticker": str})
cal = pd.read_csv(DATA / "sim-calibration.csv", dtype={"ticker": str})
summary = pd.read_csv(DATA / "results-summary.csv")
assert len(r) == 250800
assert not r.duplicated(["ticker", "composer", "rep"]).any()
assert set(r.ticker) == set(cal.ticker)
order = ["naive", "gaussian", "hybrid", "residual_jumphmm", "block_bootstrap", "garch_t"]
display = ["Naive", "Gaussian SIM", "Hybrid", "JumpHMM-on-residuals", "Block bootstrap", "GARCH(1,1)-$t$"]
assert set(r.composer) == set(order)
eligibility = set(metadata["garch_eligible"])
assert set(r.loc[r.composer == "garch_t", "ticker"]) == eligibility
assert len(eligibility) == 393
counts = r.groupby(["ticker", "composer"]).rep.agg(["count", "min", "max"])
assert (counts["count"] == 100).all() and (counts["min"] == 1).all() and (counts["max"] == 100).all()
r = r.merge(cal[["ticker", "alpha", "beta", "r2_real"]], on="ticker", validate="many_to_one")
r["alpha_error"] = (r["α_hat"] - r.alpha).abs()
r["beta_error"] = (r["β_hat"] - r.beta).abs()
r["r2_error"] = (r["R²_hat"] - r.r2_real).abs()
r["ks_pass"] = 100 * (r.ks_p > .05)
r["ad_pass"] = 100 * (r.ad_p > .05)
generated = r.groupby("composer").agg(
    n_tickers=("ticker", "nunique"), n_paths=("rep", "size"),
    alpha_error=("alpha_error", "median"), beta_error=("beta_error", "median"),
    r2_error=("r2_error", "median"), ks_pct=("ks_pass", "mean"), ad_pct=("ad_pass", "mean"),
    w1=("w1", "median"), kurt=("kurt", "median"), hill=("hill_up", "median"),
).loc[order]
actual = summary.set_index("composer").loc[order]
assert generated.columns.tolist() == actual.columns.tolist()
np.testing.assert_allclose(generated.values, actual.values, atol=1e-12, rtol=1e-12)

def read_body(path):
    lines = path.read_text().splitlines()
    start = lines.index(r"\midrule") + 1
    end = lines.index(r"\bottomrule")
    return [[cell.strip() for cell in line.removesuffix(r"\\").split("&")]
            for line in lines[start:end]]

def numeric(row, names, precision=3):
    return [f"{row[name]:.{precision}f}" for name in names]

expected_tables = {}
expected_tables["table1_aggregate.tex"] = [
    [label] + numeric(generated.loc[method], ["alpha_error", "beta_error", "r2_error"])
    + numeric(generated.loc[method], ["ks_pct", "ad_pct"], 1)
    + numeric(generated.loc[method], ["w1", "kurt", "hill"])
    for method, label in zip(order, display)]
hybrid = r[r.composer == "hybrid"]
branches = hybrid.groupby("flag", sort=False).agg(
    assets=("ticker", "nunique"), beta_error=("beta_error", "median"),
    r2_error=("r2_error", "median"), ks_pct=("ks_pass", "mean"),
    w1=("w1", "median"), kurt=("kurt", "median"))
branch_labels = {"HYBRID": r"\texttt{hybrid}", "R2_PRESERVE": r"\texttt{r2-preserve}",
                 "HYBRID_CLIPPED": r"\texttt{hybrid-clipped}"}
expected_tables["table2_by_branch.tex"] = [
    [branch_labels[flag], str(int(row.assets))]
    + numeric(row, ["beta_error", "r2_error"]) + numeric(row, ["ks_pct"], 1)
    + numeric(row, ["w1", "kurt"]) for flag, row in branches.iterrows()]
quartiles = cal.beta.quantile([.25, .5, .75]).values
r["bucket"] = np.searchsorted(quartiles, r.beta.values, side="left")
buckets = r.groupby(["bucket", "composer"]).agg(
    beta_error=("beta_error", "median"), ks_pct=("ks_pass", "mean"),
    w1=("w1", "median"), kurt=("kurt", "median"), variance=("var_g", "median"))
labels = [r"Q1 (low $\beta$)", "Q2", "Q3", r"Q4 (high $\beta$)"]
expected_tables["table3_by_beta_bucket.tex"] = [
    [labels[bucket] if method == "naive" else "", label]
    + numeric(buckets.loc[(bucket, method)], ["beta_error"])
    + numeric(buckets.loc[(bucket, method)], ["ks_pct"], 1)
    + numeric(buckets.loc[(bucket, method)], ["w1", "kurt"])
    + numeric(buckets.loc[(bucket, method)], ["variance"], 1)
    for bucket in range(4) for method, label in zip(order, display)]
table_checks = {}
for name, expected in expected_tables.items():
    for paper in ("arxiv-paper", "jfds-paper"):
        path = REPO / paper / "sections/tables" / name
        body = read_body(path)
        assert body == expected, (path, body, expected)
        original = OUT / "before" / paper / "sections/tables" / name
        table_checks[f"{paper}/{name}"] = {
            "independent_aggregation_matches": True,
            "body_unchanged_from_manuscript": body == read_body(original),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
report = {"rows": len(r), "method_counts": r.groupby("composer").size().to_dict(),
    "summary_maximum_absolute_difference": float(np.max(np.abs(generated.values-actual.values))),
    "all_replication_keys_and_eligibility_valid": True, "table_checks": table_checks}
(OUT / "table-checks.json").write_text(json.dumps(report, indent=2) + "\n")
generated.to_csv(OUT / "verified-summary.csv")
print(generated.to_string())
print("All canonical hashes, 250,800 keys, six summary rows, and three table bodies in both trees agree.")
