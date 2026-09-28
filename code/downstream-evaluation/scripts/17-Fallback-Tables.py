"""Format the checked fallback inventory and sensitivity in both paper trees."""
from pathlib import Path
import csv
import hashlib
import json
import tomllib

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
DATA = ROOT / "results/fallback-diagnostic"
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
metadata = tomllib.loads((DATA / "metadata.toml").read_text())
training = tomllib.loads((ROOT / "data/results-metadata.toml").read_text())
assert metadata["training_signature"] == training["signature"]
assert digest(ROOT / "data/results.jld2") == metadata["training_cache_sha256"]
for name, expected in metadata["artifact_sha256"].items():
    assert digest(DATA / name) == expected, name
for name, expected in metadata["source_sha256"].items():
    assert digest(ROOT / name) == expected, name
for name, expected in training["source_input_sha256"].items():
    assert digest(ROOT / name) == expected, name

def rows(name):
    with (DATA / name).open(newline="") as stream:
        return list(csv.DictReader(stream))

def table(spec, header, body):
    return "\n".join([r"\begin{tabular}{" + spec + "}", r"\toprule",
        header + r" \\", r"\midrule", *body, r"\bottomrule", r"\end{tabular}", ""])

inventory = []
for row in rows("affected-assets.csv"):
    assert int(row["near_constant_states"]) == 1
    inventory.append(" & ".join([row["ticker"], row["near_constant_observations"],
        row["empty_states"], row["singleton_states"],
        f'{100*float(row["fallback_stationary_mass"]):.3f}',
        f'{100*float(row["relative_mixture_variance_change"]):.3f}']) + r" \\")
assets_table = table("@{}lrrrrr@{}", r"Ticker & $n_{\rm c}$ & $n_0$ & $n_1$ & Fallback mass (\%) & $\Delta V$ (\%)", inventory)

metrics = {"ks_pass": ("KS pass (\\%)", 2), "ad_pass": ("AD pass (\\%)", 2),
    "w1": (r"$W_1$ ($\mathrm{yr}^{-1}$)", 4),
    "variance_ratio_observed": ("Variance / observed", 4),
    "acf_mae25": (r"ACF-MAE$_{25}$", 5)}
methods = {"uncomposed": "Uncomposed", "naive": "Naive", "hybrid": "Hybrid"}
body = []
previous = None
for row in rows("sensitivity-summary.csv"):
    method = row["method"]
    if previous is not None and previous != method:
        body.append(r"\midrule")
    label, precision = metrics[row["metric"]]
    fmt = lambda key: f'{float(row[key]):.{precision}f}'
    body.append(" & ".join([methods[method] if method != previous else "", label,
        fmt("as_fitted"), fmt("empirical_scale"),
        f'{float(row["paired_difference"]):+.{precision}f} ({fmt("paired_mc_se")})']) + r" \\")
    previous = method
sensitivity_table = table("@{}llrrr@{}",
    "Output & Metric & As fitted & Empirical scale & Paired change (SE)", body)

outputs = {}
for name, text in (("tableS_fallback_assets.tex", assets_table),
                   ("tableS_fallback_sensitivity.tex", sensitivity_table)):
    for paper in ("arxiv-paper", "jfds-paper"):
        path = REPO / paper / "sections/tables" / name
        path.write_text(text)
        outputs[str(path.relative_to(REPO))] = digest(path)
(DATA / "tables-metadata.json").write_text(json.dumps({
    "formatter_sha256": digest(Path(__file__)), "diagnostic_metadata_sha256": digest(DATA / "metadata.toml"),
    "table_sha256": outputs}, indent=2) + "\n")
print("Wrote fallback inventory and sensitivity tables in arXiv and JFDS.")
