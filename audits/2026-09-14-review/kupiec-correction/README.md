# R10: Kupiec boundary likelihood

Completed 15 September 2026. The helper correction and its tests resolve R10.
The current manuscripts report pooled breach rates, not Kupiec p-values, so
no manuscript text, figure, table value, or PDF needed to change.

## Correction

The old `kupiec_pvalue` returned zero or one at zero/all breaches by comparing
the count with a rounded expected count. That is not the likelihood-ratio
test. With coverage level α, n breaches, and T observations, the null
log likelihood is `n log(1 − α) + (T − n) log(α)`. The fitted alternative uses
the observed breach fraction n/T. The corrected helper evaluates zero-count
terms by their continuous limit, `0 log(0) = 0`. Therefore, the statistic at
zero breaches is `−2T log(α)` and at all breaches is `−2T log(1 − α)`.
The p-value is the upper tail of the asymptotic chi-square distribution with
one degree of freedom.

The code now rejects nonpositive sample sizes, counts outside `[0, T]`, and
nonfinite coverage levels or levels outside `(0, 1)`. It uses `log1p(-α)` for
the null breach term and clamps a negative statistic caused by roundoff to
zero. The docstring now puts the breach/nonbreach probabilities in the right
order and distinguishes the asymptotic test from an exact finite-sample test
or a test of breach independence.

| Breaches | Observations | Coverage | Old p-value | Corrected p-value | Decision at 5% |
|---|---|---|---|---|---|
| 0 | 100 | 99% | 0 | 0.1562583995 | Changes to non-rejection |
| 0 | 249 | 99% | 0 | 0.0252732215 | Still rejects |

## Tests and saved diagnostic impact

All 807 assertions in the four targeted test scripts passed:

- 755 helper assertions: zero/all breaches, independent high-precision
  likelihood calculations, interior counts, exact-null examples, extreme
  probabilities, invalid inputs, and propagation through `var_backtest`.
- 15 pooled-threshold assertions: quantile pooling, validation scoring,
  seed separation, and ticker serialization.
- 10 provenance assertions: unchanged non-Kupiec source and rejection of
  changed current source, archived source, inputs, or run signature.
- 27 saved-diagnostic assertions: integer counts reconstructed from rates,
  agreement with the archived helper, interior agreement within floating-point
  tolerance, and unchanged historical input files.

The three saved holdout CSVs contain 1,152,800 diagnostic p-values across
95% and 99% coverage. Their corresponding JLD2 metadata confirms 249
observations. Re-evaluation changes 40,650 zero-breach cases; there are no
all-breach cases and no changes to 5% decisions. Interior p-values agree
within floating-point tolerance. These are overlapping historical evaluations,
not 1,152,800 independent observations.

| Saved evaluation | 95% zero-breach cases | 99% zero-breach cases | Changed 5% decisions |
|---|---|---|---|
| `results-oos.csv` | 546 | 15,697 | 0 |
| `results-oos-centered.csv` | 554 | 15,758 | 0 |
| `results-oos-centered-components.csv` | 128 | 7,967 | 0 |

[legacy-impact.csv](legacy-impact.csv) gives corrected per-method mean
p-values and pass rates; [kupiec-values-T249.csv](kupiec-values-T249.csv) gives
old and corrected p-values for every possible count at both coverage levels.
Together with the saved row's breach rate and 249-day horizon, the latter
recovers each corrected p-value without rerunning simulations. Reproduce the
analysis with [check_legacy.jl](check_legacy.jl).

Historical CSV/JLD2 caches retain their original stored Kupiec values and
must not be described as corrected caches. The unused training aggregate
`data/var-backtest-summary.csv` has no corresponding saved per-path CSV or
JLD2 in this repository, so its p-value means cannot be corrected from that
aggregate alone. It remains a historical diagnostic, outside the current
manuscript's inputs. New evaluations use the corrected helper.

## Frozen pooled experiment

The pooled experiment recorded the hash of the entire `VaRBacktest.jl` file,
although it uses only the unchanged `var_threshold` function. Its calibration
and scoring never call `kupiec_pvalue`. The original source is preserved at
`code/downstream-evaluation/results/var-ensemble/source-corrections/VaRBacktest.before-R10.jl`.
The adjacent `R10.toml` records the original run signature, old/new source
hashes, correction scope, and verification paths.

The original `provenance.toml`, `scoring.toml`, calibrated thresholds, scored
breach counts, and summaries remain byte-identical. Script 14 validates all
original input/source hashes, allowing only the exact recorded R10 correction
when rendering tables. The saved original helper must also match the original
manifest. Tests verify that all source outside the Kupiec function and its
docstring is byte-identical. Further unrecorded source changes still fail.

Script 13 retains its strict original-source check for calibration/resumption;
the table-rendering exception does not relabel an old run as a new simulation.
Historical resumption requires the archived original helper in a separate
checkout. Existing paper tables can be regenerated directly with script 14
using the corrected working source.

Script 14 regenerated both active Table 5 files and their compact CSV byte for
byte. All three manuscript PDFs and both Figure 4 PDFs match their pre-R10
hashes. No LaTeX source changed, so the existing PDF verification remains
applicable. [verification.json](verification.json) records these checks.

## Reproduction

Run the four Julia checks listed in the downstream evaluation README. Then:

```sh
julia --compiled-modules=existing --project=code/downstream-evaluation code/downstream-evaluation/scripts/14-VaR-Table.jl
python3 audits/2026-09-14-review/kupiec-correction/verify_artifacts.py
```

The next named finding is R11, the scope of synthetic-tracker validation.
Additional audit follow-ups and final release preparation remain open.
