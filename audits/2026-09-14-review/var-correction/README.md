# Issue 4: pooled thresholds for the one-day VaR evaluation

The author selected pooled thresholds while retaining the 249-day path construction.
Table 5 now uses one threshold per asset, method, and coverage level, calibrated
from 5,000 separate paths before opening the 2025 holdout. Independent simulated
paths check tail probabilities. Both manuscripts replace the old per-path table
and narrow the coverage interpretation. No fitted models, centering rules,
variance targets, jump settings, horizons, or Table 4 scores changed.

## Why the result changed

The old procedure estimated a tail quantile separately from each 249-observation
synthetic path and averaged its exceedance rate on the same observed 2025 history
over 100 replications. That quantity mixes generator-tail performance with the
sampling behavior of a short empirical quantile. Pooling estimates the uniform-day
marginal of the retained 249-day generator more accurately. The old and new rates
therefore concern different threshold procedures; a lower rate does not mean the
frozen generator improved.

The numerical comparison below uses the archived old summary and a fresh pooled
ensemble with a separate seed schedule. It is not a paired random-draw comparison
or a universal finite-sample correction. In particular, the audit's iid uniform
illustration, 1.392% for the type-7 1% quantile from 249 observations, cannot be
subtracted from these dependent, centered, and scaled generators' coverage rates.

| Method | Holdout assets | 95% exceedance: old → pooled (%) | 99% exceedance: old → pooled (%) |
|---|---:|---:|---:|
| naive | 416 | 4.37 → 4.04 | 1.21 → 0.88 |
| gaussian | 416 | 4.95 → 4.65 | 2.03 → 1.72 |
| hybrid | 416 | 5.97 → 5.48 | 1.67 → 1.12 |
| residual_jumphmm | 416 | 6.07 → 5.62 | 1.67 → 1.16 |
| block_bootstrap | 416 | 6.13 → 5.50 | 1.84 → 1.28 |
| garch_t | 386 | 5.79 → 5.07 | 1.80 → 1.20 |

The hybrid mean 99% exceedance rate was 1.1160%, versus 1.1623% for
JumpHMM-on-residuals and 0.8756% for naive composition. Hybrid and naive lay
similarly close to nominal on opposite sides; their small difference does not
establish a ranking. The former claim that naive was numerically closest no
longer holds. The remaining excess over 1% is descriptive, not evidence by
itself of statistical miscalibration. At 95%, hybrid remained above nominal
at 5.4815%. Cross-asset standard deviations are dispersion measures, not
standard errors; one shared observed year does not supply independent market
replications.

## Protocol and limits

- Freeze all 423 training asset models/calibrations, including 393 accepted GARCH
  models. Generate and persist calibration thresholds before reading the holdout;
  score the 416 eligible holdout assets, including 386 GARCH assets.
- For each asset and method, compose 5,000 separate 249-day paths, then pool their
  1,245,000 daily log returns. Never compose or center a single long concatenated
  path. Use the negative linearly interpolated lower-tail quantile as VaR.
- Preserve training-market-variance scaling, path-specific full-return variance,
  shared simulated SPY per replication, stationary HMM initialization, GARCH's
  default 100-step warmup, no-jump fits, and native residual mean treatment.
- Use seed 9142026 with disjoint phase/source/asset/draw ranges. Batch size is 100.
  Calibration and validation have separate market and asset draws. Threshold
  checkpoints at 100, 500, 1,000, 2,500, and 5,000 paths were fixed before scoring.
- Score each fixed threshold on 1,000 independent 249-day simulated paths as a
  numerical diagnostic, then on the one observed 2025 return history. The
  independent simulation check does not establish real-market calibration.
- Pooling retains horizon dependence and the zero-sum residual construction.
  It does not recover cumulative residual risk or parameter uncertainty.

Doubling the pool from 2,500 to 5,000 changed every method's mean observed
exceedance rate by less than 0.006 percentage points at either level. Across
methods, the median relative change of the 99% threshold was 0.12–0.30%, and
the 95th percentile was 0.37–1.03%. The largest individual change was 3.95%
for a GARCH asset, so small aggregate changes should not be interpreted as
uniform precision for every asset. Mean independent simulated breach rates
were 5.03–5.04% and 1.01–1.02%. Supplementary Tables S15 and S16 report
convergence and the common 386-asset comparison. On that common set, hybrid
and JumpHMM-on-residuals had 99% rates of 1.08% and 1.14%, respectively.

The alternative discussed with the author is to retain the short-path estimator
and calibrate its entire procedure: repeatedly fit a threshold to one 249-day
simulated path and test it on an independent path from the same generator.
That would quantify model-specific short-estimator coverage and uncertainty.
It answers a different question from the main pooled analysis and has not been
run as a calibrated short-path sensitivity study. The current independent
simulation check uses fixed pooled thresholds.

## Production integration

`scripts/13-VaR-Ensemble.jl` writes per-asset checkpoints, thresholds, scores,
available-asset/common-asset summaries, and provenance under
`code/downstream-evaluation/results/var-ensemble/`. It checks each stored ticker,
method set, and checkpoint count before aggregating. The formatter,
`scripts/14-VaR-Table.jl`, validates source/input fingerprints and the scored
threshold hash, then updates both manuscript trees and the canonical compact
`data/var-backtest-oos-summary.csv`. Script 10b now delegates Table 5 to this
formatter, so it cannot silently regenerate the table from old per-path columns.
Its Table 4 and figure protocol remains unchanged.

Kupiec pass rates were removed from the primary table. Its original asymptotic
independence interpretation did not accommodate the evaluated paths. The old
boundary helper remains a separate ranked correction and is used only in
legacy diagnostics, not in the new Table 5 calculation. Canonical training-cache
reconciliation remains ranked issue 5.

## Validation and reproduction

From the repository root:

```sh
julia --compiled-modules=existing --threads=4 --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/13-VaR-Ensemble.jl
julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/14-VaR-Table.jl
julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/test/var_ensemble.jl
julia --compiled-modules=existing --project=code/downstream-evaluation \
  audits/2026-09-14-review/var-correction/verify_ensemble.jl
python3 audits/2026-09-14-review/var-correction/check_and_report.py
```

All 15 unit checks and 10 production integration checks passed. Serial replay
reproduced all six AAPL methods' threaded thresholds and simulation checks exactly.
Checks confirm distinct calibration/validation market draws, 5,000 distinct
market paths, the 249-day horizon, direct agreement with unchanged composers,
retention of hybrid centering, and random residual means for Gaussian SIM.
The independent Python aggregation verifies all 25,080 calibration rows and
24,660 scored rows, unique thresholds per asset/method/level/pool size, every
saved breach-rate calculation, and every available/common summary.

During development, checks caught a shared-variable error in the new threaded
runner's saved rows and automatic Boolean inference for single-ticker CSV files
named F and T. The runner now uses a separate local result and explicit ticker
string types, with identity assertions and regression tests. Those development
outputs were discarded from the canonical results; a clean full run produced
the final 416/386-asset summaries. The exact serial replay and independent row
checks refer to this final run.

Artifacts include `table5_before.tex`, `summary_before.csv`, `ensemble.log`,
`tests.log`, `integration.log`, `numerical-checks.json`, and `build-checks/`.
The raw Fable responses remain unchanged; this correction was implemented and
experimentally checked by Codex, not rerun by Fable.
