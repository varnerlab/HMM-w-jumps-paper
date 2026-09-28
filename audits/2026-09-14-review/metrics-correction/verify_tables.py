"""Check printed GRU values, unchanged numeric rows, and frozen source hashes."""
from pathlib import Path
import csv
import hashlib
import json
import re
import tomllib

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
metadata = tomllib.loads((OUT / "gru-rerun-metrics/metric-metadata.toml").read_text())
for name, expected in metadata["source_input_sha256"].items():
    assert digest(REPO / name) == expected, name
before = json.loads((OUT / "before-manifest.json").read_text())
frozen = [name for name in before if name.endswith(".jl") or name.endswith("train_gru.py")]
for name in frozen:
    assert digest(REPO / name) == before[name], name

models = ("Bootstrap", "Gaussian", "Laplace", "GARCH(1,1)", "GRU", "HSMM", "HMM-NJ", "HMM-WJ")
mean_keys = ("ks_pass", "ad_pass", "kurt", "acf_mae", "coverage", "w1", "hellinger")
se_keys = ("ks_se", "ad_se", "kurt_se", "acf_se", "coverage_se", "w1_se", "hellinger_se")
checked = 0
for paper in ("arxiv-paper", "jfds-paper"):
    name = f"{paper}/sections/tables/table2_model_comparison.tex"
    current = (REPO / name).read_text()
    original = (OUT / "before" / name).read_text()
    rows = lambda text: [line for line in text.splitlines() if any(line.startswith(model+" ") for model in models)]
    assert rows(current) == rows(original) and len(rows(current)) == 16
    gru_rows = [line for line in current.splitlines() if line.startswith("GRU ")]
    assert len(gru_rows) == 2
    for window, row in zip(("is", "oos"), gru_rows):
        cells = row.split(" & ")[1:]
        assert len(cells) == 7
        for cell, mean_key, se_key in zip(cells, mean_keys, se_keys):
            values = re.findall(r"[+-]?\d+\.\d+", cell)
            assert len(values) == 2
            for index, (printed, key) in enumerate(zip(values, (mean_key, se_key))):
                value = metadata["results"][window][key]
                if index == 1 and "<" in cell:
                    assert value < float(printed)
                else:
                    decimals = len(printed.split(".")[1])
                    assert abs(float(printed)-value) <= 0.5*10**(-decimals)+1e-12, (paper, window, key)
                checked += 1

training = tomllib.loads((REPO / "code/downstream-evaluation/data/results-metadata.toml").read_text())
root = REPO / "code/downstream-evaluation"
for group, directory in (("source_input_sha256",root), ("artifact_sha256",root/"data"),
                         ("fitted_cache_sha256",root/"data")):
    for name, expected in training[group].items():
        assert digest(directory/name) == expected
report = {"printed_GRU_fields_verified":checked,"all_16_Table2_numeric_rows_unchanged_in_both_papers":True,
    "original_scoring_and_training_sources_unchanged":True,
    "canonical_multiasset_inputs_sources_scores_and_fits_unchanged":True,
    "metric_metadata_sha256":digest(OUT/"gru-rerun-metrics/metric-metadata.toml")}
(OUT/"table-verification.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report,indent=2))
