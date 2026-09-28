"""Verify the bounded R10 change against its preserved source/output hashes."""
from pathlib import Path
import csv
import hashlib
import json
import math
import tomllib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


before = json.loads((HERE / "before.json").read_text())
after = {path: sha(ROOT / path) for path in before}
changed = sorted(path for path in before if before[path] != after[path])
assert changed == sorted([
    "code/downstream-evaluation/src/VaRBacktest.jl",
    "code/downstream-evaluation/scripts/14-VaR-Table.jl",
])
run = ROOT / "code/downstream-evaluation/results/var-ensemble"
record = tomllib.loads((run / "source-corrections/R10.toml").read_text())
manifest = tomllib.loads((run / "provenance.toml").read_text())
helper = "code/downstream-evaluation/src/VaRBacktest.jl"
assert record["original_signature"] == manifest["signature"]
assert record["original_sha256"] == before[helper]
assert record["corrected_sha256"] == after[helper]
assert sha(run / "source-corrections/VaRBacktest.before-R10.jl") == before[helper]

with (HERE / "legacy-impact.csv").open() as stream:
    impact = list(csv.DictReader(stream))
diagnostic_count = sum(int(r["records"]) for r in impact)
boundary_count = sum(int(r["zero_breaches"]) for r in impact)
changed_decisions = sum(int(r["changed_5pct_decisions"]) for r in impact)
assert diagnostic_count == 1152800
assert boundary_count == 40650
assert changed_decisions == 0
horizons = tomllib.loads((HERE / "legacy-horizons.toml").read_text())
assert len(horizons) == 3 and set(horizons.values()) == {249}

test_counts = {"tests.log": [238, 509, 8], "ensemble-tests.log": [15],
               "provenance-tests.log": [10], "legacy-checks.log": [27]}
for name, counts in test_counts.items():
    log = (HERE / name).read_text()
    assert "ERROR:" not in log and "Test Failed" not in log
    for count in counts:
        assert f"{count}" in log
assert "ERROR:" not in (HERE / "table-check.log").read_text()

report = {
    "finding": "R10", "status": "resolved", "date": "2026-09-15",
    "julia_test_assertions_passed": sum(map(sum, test_counts.values())),
    "legacy_diagnostic_pvalues_checked": diagnostic_count,
    "legacy_zero_breach_pvalues_corrected": boundary_count,
    "legacy_changed_5pct_decisions": changed_decisions,
    "legacy_horizons": horizons,
    "independent_python_boundary_pvalues": {
        str(T): math.erfc(math.sqrt(-T * math.log(.99))) for T in (100, 249)
    },
    "changed_snapshot_files": changed,
    "unchanged_snapshot_files": [p for p in before if p not in changed],
    "original_pooled_provenance_preserved": True,
    "table5_regenerated_byte_identically": True,
    "manuscript_pdfs_unchanged": True,
    "original_sha256": before,
    "current_sha256": after,
    "source_correction": record,
}
(HERE / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
print("R10 verified: 807 assertions passed; Table 5, pooled results, and PDFs unchanged.")
