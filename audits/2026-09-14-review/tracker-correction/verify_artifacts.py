"""Check R11 source preservation, table values, synchronized prose, and PDF builds."""
from pathlib import Path
import csv
import hashlib
import json
import re
import tomllib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


before = json.loads((HERE / "before.json").read_text())
after = {p: sha(ROOT / p) for p in before}
unchanged = [p for p in before if before[p] == after[p]]
for p in before:
    if p.startswith("code/") and not p.endswith("08-Synthetic-Tracker-Eval.jl"):
        assert p in unchanged, p
    if "/figs/" in p:
        assert p in unchanged, p
script = "code/downstream-evaluation/scripts/08-Synthetic-Tracker-Eval.jl"
assert sha(HERE / "08-Synthetic-Tracker-Eval.before.jl") == before[script]
grid = tomllib.loads((HERE / "grid-checks.toml").read_text())
assert grid["rows"] == 1500 and grid["cells"] == 15 and grid["horizon"] == 2766
assert grid["all_saved_values_reproduced_exactly"] and grid["script_executable_code_unchanged"]

with (ROOT / "code/downstream-evaluation/data/synth-tracker-summary.csv").open() as stream:
    summary = list(csv.DictReader(stream))
blocks = {}
for paper in ("arxiv-paper", "jfds-paper"):
    source = (ROOT / paper / "sections/appendix.tex").read_text()
    a = source.index("% --- Table: restricted Gaussian tracker check ---")
    b = source.index("\\end{table}", a)
    blocks[paper] = source[a:b]
    rows = re.findall(r"^\$\d[^\n]+", source[source.index("\\label{tab:tracker_grid}"):b], re.M)
    assert len(rows) == 15
    for row, values in zip(rows, summary):
        observed = re.findall(r"\d+\.\d+", row)
        expected = [f"{float(values['beta_true']):.1f}", f"{float(values['r2_true']):.2f}"]
        expected += [f"{float(values[c]):.4f}" for c in
                     ("median_beta_hat", "sd_beta_hat", "median_r2_hat", "sd_r2_hat")]
        expected += [f"{float(values['ks_pass_pct']):.1f}"]
        assert observed == expected, (row, expected)
    old = (HERE / "before" / paper / "sections/appendix.tex").read_text()
    old_part = old[old.index("\\label{tab:tracker_grid}"):]
    old_rows = re.findall(r"^\$\d[^\n]+", old_part[:old_part.index("\\end{table}")], re.M)
    assert rows == old_rows
assert blocks["arxiv-paper"] == blocks["jfds-paper"]
for section, start, end in (
    ("results", "We used a Gaussian synthetic-tracker grid", "Greater market exposure made"),
    ("discussion", "Only two tracker", "generating asset and market draws independently."),
):
    excerpts = []
    for paper in ("arxiv-paper", "jfds-paper"):
        text = (ROOT / paper / f"sections/{section}.tex").read_text()
        text = text[text.index(start):text.index(end, text.index(start))]
        excerpts.append(" ".join(text.replace("Supplementary ", "").split()))
    assert excerpts[0] == excerpts[1]

render = json.loads((HERE / "pdf-qa/render-manifest.json").read_text())
logs = {}
for name, stem in (("arxiv", "arxiv-paper/Paper_v1"), ("jfds", "jfds-paper/Paper_v1"),
                   ("supplement", "jfds-paper/Supplement_v1")):
    log = (ROOT / f"{stem}.log").read_text()
    assert not re.search(r"undefined|multiply defined|^!", log, re.I | re.M)
    warnings = re.findall(r"Overfull [^\n]+", log)
    logs[name] = {"sha256": sha(ROOT / f"{stem}.log"), "overfull_boxes": warnings}
    assert len(warnings) == {"arxiv": 0, "jfds": 1, "supplement": 3}[name]
    assert sha(ROOT / render[name]["pdf"]) == after[render[name]["pdf"]]
    assert render[name]["pages"] == {"arxiv": 53, "jfds": 32, "supplement": 41}[name]
for built, installed in (("Paper_v1.pdf", "JFDS_Anonymous_Manuscript.pdf"),
                         ("Supplement_v1.pdf", "JFDS_Supplementary_Material.pdf")):
    assert sha(ROOT / "jfds-paper" / built) == sha(ROOT / "jfds-paper/output/pdf" / installed)
for name, expected in (("branch-tests.log", [(468, 468), (6, 6)]), ("replay.log", [(18, 18)])):
    log = (HERE / name).read_text()
    assert "ERROR" not in log and "Test Failed" not in log
    counts = [(int(a), int(b)) for a, b in re.findall(r"\|\s+(\d+)\s+(\d+)\s+[\d.]+s", log)]
    assert counts == expected, (name, counts)

report = {
    "finding": "R11", "status": "resolved_by_scope_qualification", "date": "2026-09-15",
    "julia_assertions_passed": 492, "grid_replay": grid,
    "all_15_table_rows_verified": True, "table_numeric_rows_unchanged": True,
    "manuscript_changes_synchronized": True, "jfds_installed_outputs_match": True,
    "builds_passed": ["make -C arxiv-paper pdf", "make -C jfds-paper all"],
    "logs": logs, "accepted_figure4_assets_unchanged": True,
    "original_sha256": before, "current_sha256": after, "unchanged_snapshot_files": unchanged,
    "visual_checks": {"pages": render, "total_pages": 126, "contact_sheets_inspected": 12,
        "all_rendered_pages_inspected": True, "detail_pages_inspected": 8, "detail_dpi": 120,
        "result": "No new clipping, overlap, detached captions, or single-line paragraph widows/orphans observed."},
    "scope_limits": ["No full-return HMM fitted on the synthetic grid", "No KS size calibration claimed",
        "No temporal validation claimed by the grid or new unit tests", "Additional audit follow-ups remain",
        "Release archives not regenerated; changes uncommitted"],
}
(HERE / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
print("R11 verified: 492 assertions, exact 1,500-row replay, unchanged table values, synchronized manuscripts.")
