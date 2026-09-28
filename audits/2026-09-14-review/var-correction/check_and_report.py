"""Independently aggregate saved counts and render the convergence supplement."""
import csv
import json
import math
import statistics as st
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
OUTPUT = REPO / "code/downstream-evaluation/results/var-ensemble"
METHODS = ["naive", "gaussian", "hybrid", "residual_jumphmm", "block_bootstrap", "garch_t"]
NAMES = ["Naive", "Gaussian SIM", "Hybrid", "JumpHMM-on-residuals", "Block bootstrap", r"GARCH(1,1)-$t$"]


def read(path):
    with path.open() as f:
        return list(csv.DictReader(f))


def percentile(x, p):
    ordered = sorted(x)
    pos = (len(x) - 1) * p
    lo = math.floor(pos)
    return ordered[lo] + (pos - lo) * (ordered[math.ceil(pos)] - ordered[lo])


thresholds = read(OUTPUT / "thresholds.csv")
scores = read(OUTPUT / "scores.csv")
summaries = read(OUTPUT / "summary.csv")
old = read(HERE / "summary_before.csv")
assert len(thresholds) == (423 * 5 + 393) * 2 * 5
assert len(scores) == (416 * 5 + 386) * 2 * 5
assert len({r["ticker"] for r in scores}) == 416
assert len({(r["ticker"], r["composer"], r["alpha_level"], r["calibration_paths"]) for r in scores}) == len(scores)
lookup = {(r["ticker"], r["composer"], r["alpha_level"], r["calibration_paths"]): r for r in thresholds}
for r in scores:
    assert int(r["horizon"]) == int(r["observations"]) == 249
    assert float(r["rate"]) == int(r["breaches"]) / 249
    assert r["threshold"] == lookup[(r["ticker"], r["composer"], r["alpha_level"], r["calibration_paths"])]["threshold"]
common = {r["ticker"] for r in scores if r["composer"] == "garch_t"}
for row in summaries:
    selected = [r for r in scores if all(r[k] == row[k] for k in ("composer", "alpha_level", "calibration_paths"))
                and (row["population"] == "available" or r["ticker"] in common)]
    assert len(selected) == int(row["n_tickers"])
    for key, computed in (("mean_rate", st.mean(float(r["rate"]) for r in selected)),
                          ("sd_rate", st.stdev(float(r["rate"]) for r in selected)),
                          ("validation_rate", st.mean(float(r["validation_rate"]) for r in selected))):
        assert math.isclose(float(row[key]), computed, abs_tol=1e-14)

report = []
for method in METHODS:
    for alpha in ("0.95", "0.99"):
        selected = [r for r in scores if r["composer"] == method and r["alpha_level"] == alpha
                    and r["calibration_paths"] == "5000"]
        drifts = [100 * abs(float(r["threshold"]) - float(lookup[(r["ticker"], method, alpha, "2500")]["threshold"]))
                  / abs(float(r["threshold"])) for r in selected]
        row = next(r for r in summaries if r["composer"] == method and r["alpha_level"] == alpha
                   and r["calibration_paths"] == "5000" and r["population"] == "available")
        previous = next(r for r in old if r["composer"] == method and r["alpha_level"] == alpha)
        smaller = next(r for r in summaries if r["composer"] == method and r["alpha_level"] == alpha
                       and r["calibration_paths"] == "2500" and r["population"] == "available")
        common_row = next(r for r in summaries if r["composer"] == method and r["alpha_level"] == alpha
                         and r["calibration_paths"] == "5000" and r["population"] == "common")
        report.append(dict(method=method, alpha=float(alpha), assets=len(selected),
                           old_rate=100*float(previous["mean_rate"]), new_rate=100*float(row["mean_rate"]),
                           sd_pp=100*float(row["sd_rate"]), common_rate=100*float(common_row["mean_rate"]),
                           relative_threshold_change_median_pct=st.median(drifts),
                           relative_threshold_change_p95_pct=percentile(drifts,.95),
                           relative_threshold_change_max_pct=max(drifts),
                           mean_rate_change_pp=100*abs(float(row["mean_rate"])-float(smaller["mean_rate"])),
                           validation_rate=100*float(row["validation_rate"])))
(HERE / "numerical-checks.json").write_text(json.dumps(dict(
    calibration_rows=len(thresholds), scored_rows=len(scores), holdout_assets=416, common_assets=386,
    independent_summary_recalculation=True, per_asset_unique_thresholds=True, results=report), indent=2)+"\n")

table = [r"\begin{tabular}{lrrrr}", r"\toprule",
         r" & \multicolumn{2}{c}{Relative threshold change (\%)} & \multicolumn{2}{c}{Simulation rate (\%)} \\",
         r"\cmidrule(lr){2-3} \cmidrule(lr){4-5}",
         r"Method & $95\%$: median / P95 & $99\%$: median / P95 & $95\%$ & $99\%$ \\", r"\midrule"]
for method, name in zip(METHODS, NAMES):
    a, b = [next(r for r in report if r["method"] == method and r["alpha"] == alpha) for alpha in (.95,.99)]
    vals = [name, *(f'{r["relative_threshold_change_median_pct"]:.2f} / {r["relative_threshold_change_p95_pct"]:.2f}' for r in (a,b)),
            f'{a["validation_rate"]:.2f}', f'{b["validation_rate"]:.2f}']
    table.append(" & ".join(vals) + r" \\")
table += [r"\bottomrule", r"\end{tabular}"]
for paper in ("arxiv-paper", "jfds-paper"):
    (REPO / paper / "sections/tables/tableS_var_convergence.tex").write_text("\n".join(table)+"\n")
common_table = [r"\begin{tabular}{lrrrr}", r"\toprule",
                r" & \multicolumn{2}{c}{$\alpha = 0.95$} & \multicolumn{2}{c}{$\alpha = 0.99$} \\",
                r"\cmidrule(lr){2-3} \cmidrule(lr){4-5}",
                r"Method & rate (\%) & SD (pp) & rate (\%) & SD (pp) \\", r"\midrule"]
for method, name in zip(METHODS, NAMES):
    vals = [name]
    for alpha in ("0.95", "0.99"):
        row = next(r for r in summaries if r["composer"] == method and r["alpha_level"] == alpha
                   and r["calibration_paths"] == "5000" and r["population"] == "common")
        vals += [f'{100*float(row[k]):.2f}' for k in ("mean_rate", "sd_rate")]
    common_table.append(" & ".join(vals) + r" \\")
common_table += [r"\bottomrule", r"\end{tabular}"]
for paper in ("arxiv-paper", "jfds-paper"):
    (REPO / paper / "sections/tables/tableS_var_common.tex").write_text("\n".join(common_table)+"\n")
print(json.dumps(report, indent=2))
