# Downstream-evaluation pipeline

Reproducibility code for the multi-composer downstream-evaluation results in
*Variance-Corrected Multi-Asset Equity Simulation with Hybrid Hidden Markov Marginals* (Alswaidan & Varner). This
directory produces the six-composer comparisons (naive, Gaussian SIM, hybrid,
JumpHMM-on-residuals, block bootstrap, GARCH(1,1)-t), the per-ticker VaR
coverage check, the seed-uncertainty table, the stress and sensitivity sweeps, the
synthetic-tracker check, and the cross-term covariance diagnostic.

## Layout

```
downstream-evaluation/
├── Project.toml / Manifest.toml   pinned Julia environment
├── Include.jl                     paths, package imports, source loading
├── config.toml                    experiment configuration
├── src/
│   ├── Composers.jl       six composers (paired ε̃ for the per-ticker comparison)
│   ├── Metrics.jl         KS, AD, Wasserstein-1, Hill tail index, β recovery
│   ├── GARCHFit.jl        convergence, parameter, trial-path, and cache checks
│   ├── Pipeline.jl        universe loading, fitting, scoring, artifact I/O
│   ├── TrainingResults.jl canonical training run, checkpoints, and provenance
│   ├── TrainingSetup.jl   headless setup for training and table generation
│   ├── SyntheticMarket.jl synthetic high-β tracker construction (script 08)
│   └── VaRBacktest.jl     per-ticker exceedance + Kupiec coverage
├── scripts/               numbered pipeline (see below)
├── data/                  raw OHLC inputs + small published summaries
└── figs/                  output figures (gitignored)
```

## Dependencies

The hybrid composer is implemented in
[`JumpHMM.jl`](https://github.com/varnerlab/JumpHMM.jl) as
`HybridSingleIndexModel`. This pipeline uses `JumpHMM.jl` for per-ticker
marginal fits and implements the six paper comparison methods locally so they
pair the naive and corrected methods on the same per-ticker generator draw
`ε̃`; the other four methods draw their own residuals. Before a
full-return draw enters the naive or hybrid composition, its realized path
mean is removed; this prevents the draw's location from being counted again
on top of the calibrated SIM intercept. The pinned `JumpHMM.jl` release
provides the marginal generator, while `src/Composers.jl` is the authoritative
implementation of the paper's centered multi-asset construction.

The 424-ticker universe is loaded via
[`VLQuantitativeFinancePackage.jl`](https://github.com/varnerlab/VLQuantitativeFinancePackage.jl)
on top of the OHLC `.jld2` files committed under `data/`.

First-time `include("Include.jl")` will `Pkg.add(url=...)` both packages from
GitHub if `Manifest.toml` is absent; the pinned manifest is committed, so on
a clean checkout `Include.jl` alone does not install packages already listed
in the manifest. Instantiate the pinned environment once before running any
script:

```bash
julia --project=code/downstream-evaluation -e 'using Pkg; Pkg.instantiate()'
```

## Reproduction

Run the numbered scripts in order from the directory:

```bash
cd code/downstream-evaluation
julia --project=. scripts/01-Fit-Marginals.jl              # universe and 424 full-return fits
julia --project=. scripts/02-Calibrate-SIM.jl              # required before either residual fit
julia --project=. scripts/01b-Fit-Residual-Marginals.jl    # JumpHMM fits on OLS residuals
julia --project=. scripts/01c-Fit-GARCH.jl                 # validated GARCH(1,1)-t fits
julia --project=. --threads=4 scripts/03-Compose-And-Evaluate.jl # verified six-method training run
julia --project=. scripts/03b-Stress-Eval.jl               # clipping-branch stress test
julia --project=. scripts/03c-Seed-Sweep.jl                # seed-uncertainty table
julia --project=. scripts/03d-Sensitivity-Sweep.jl         # hybrid hyperparameter sweep
julia --project=. scripts/04-Tables.jl                     # training tables in arXiv, then JFDS
julia --project=. scripts/04-Tables.jl --check             # verify table agreement without writing
julia --project=. scripts/05-Figures.jl                    # main figure PDFs
julia --project=. scripts/06-VaR-Backtest.jl               # per-ticker VaR + Kupiec -> var-backtest-summary.csv
julia --project=. scripts/04b-VaR-Table.jl                 # legacy training VaR diagnostic (after 06)
julia --project=. scripts/07-Cov-Diagnostic.jl             # cross-term covariance check
julia --project=. scripts/08-Synthetic-Tracker-Eval.jl     # R²-preserve branch check
julia --project=. scripts/09-Extra-Figures.jl              # revision figures
julia --project=. scripts/10-OoS-Evaluation.jl             # frozen-fit 2025 six-composer evaluation
julia --project=. --threads=4 scripts/13-VaR-Ensemble.jl   # pooled 249-day VaR calibration, then 2025 scoring
julia --project=. scripts/14-VaR-Table.jl                  # Table 5 in both manuscript trees
julia --project=. scripts/10b-OoS-Table.jl                 # OoS tables/figure; requires the pooled ensemble
```

The marginal fitting scripts reuse existing model caches. Move those caches
aside before changing the fitted-model configuration. The GARCH fitter reuses
a cache only when its input/source fingerprints and acceptance records match;
use `scripts/01c-Fit-GARCH.jl --refit` to replace a legacy or changed cache.
Use `--output-dir PATH` to fit GARCH models into an isolated directory. Evaluation
and formatting scripts can overwrite their outputs. To preserve the published
results while rerunning experiments, use a separate checkout. Scripts 01 and
02 must run before scripts 01b and 01c on a checkout without fitted models.

## Data committed in this repo

The cached `universe.jld2`, `sim-calibration.jld2`, and `results.jld2`
are ordinary files. They do not require access to an author's filesystem.
The first two provide the training universe and OLS calibration; the third
is the cached training comparison.

- `data/SP500-Daily-OHLC-1-3-2014-to-12-31-2024.jld2` (84 MB) — in-sample raw OHLC, 424 tickers, 2014-01-03 to 2024-12-31.
- `data/SP500-Daily-OHLC-1-2-2025-to-12-31-2025.jld2` (8.8 MB) — 2025 out-of-sample OHLC.
- `data/SP500-Daily-OHLC-1-2-2026-to-04-22-2026.jld2` (3.6 MB) — 2026 partial-year OHLC.
- `data/results.jld2` — all 250,800 training path scores from the six-method run, with configuration and provenance. Five methods cover 423 assets; GARCH covers 393, each with 100 paths.
- `data/results-summary.csv` — six method-level rows aggregated from that cache, including denominators, median errors and tail metrics, and pooled KS/AD pass rates. This replaces the obsolete three-method per-path CSV of the same name.
- `data/results-metadata.toml` — source, input, fitted-model, dependency, and result hashes plus settings and GARCH eligibility.
- `data/results-tables.toml` — formatter and table hashes associated with that training run.
- `data/var-backtest-summary.csv` (1.2 KB) — per-composer mean exceedance rate, cross-ticker SD, mean Kupiec p, Kupiec pass rate.
- `data/synth-tracker-summary.csv` (1.7 KB) — synthetic-tracker β/R² recovery summary.
- `data/synth-tracker.csv` (177 KB) — per-tracker results.
- `data/sim-calibration.csv` (34 KB) — per-ticker (α, β, R², σ_ε) from script 02.
- `data/cov-diagnostic.csv` (74 KB) — cross-term Cov(ε̃, g_m) per ticker per composer.
- `data/garch-t-skipped.csv` — excluded GARCH tickers and reasons from the same fitting run.
- `data/garch-t-diagnostics.csv` — convergence, coefficients, persistence, unconditional variance, trial checks, and acceptance for every training ticker.
- `data/garch-t-metadata.toml` — fitting settings and source/input fingerprints for that run.

## Data regenerated by the pipeline (not committed)

`marginals.jld2`, `marginals-residuals.jld2`, `garch-t-models.jld2`,
`garch-t-sims.jld2`,
`results-seed-*.jld2`, `results-stress.jld2`, `results-thresh-*.jld2`,
`var-backtest.jld2`, `synth-tracker.jld2`. The fitted full-return, residual, and GARCH model archives are local caches
and are not distributed in Git. Regenerate them with scripts 01, 02, 01b,
and 01c in that order. The committed manifest pins the dependency source
trees; instantiate that environment before fitting.

`data/results.csv` is the full training-path CSV export. It is ignored by Git
because the same rows are distributed in `results.jld2`; the compact summary
is distributed separately. `results/training-canonical/` contains resumable
per-asset checkpoints and is also ignored.

`results-oos.jld2` and `results-oos.csv` contain the per-path 2025 holdout
evaluation. They are reproducible caches and are ignored by Git; the compact
`results-oos-summary.csv` and `var-backtest-oos-summary.csv` outputs are the
versioned sources for the manuscript tables. The VaR summary now comes from
scripts 13/14 and the separate pooled ensemble, not the per-path evaluator.
The evaluator also compares
every synthetic path with a random contiguous 249-day block from the training
period so that KS/AD rejection rates can be interpreted at a matched sample
length. Tables 4 and 5 use the observed training market variance in the
correction, even though their market paths are simulated. Each asset draw
still supplies its own generator variance. In contrast, Table 6 uses each
simulated market path's variance in both windows. No 2025 observations enter
fitting or either variance convention; holdout observations are used only
for scoring. The multi-asset closing-price experiments use `risk_free_rate = 0`.

## GARCH acceptance and coverage

The GARCH benchmark requires optimizer convergence, finite likelihood and
coefficients, positive variance intercept, nonnegative ARCH/GARCH coefficients
with sum below one, Student-t degrees of freedom above two, finite positive
unconditional variance, and a finite nonconstant simulated trial path. The
pinned ARCHModels public fitter discards its optimizer result, so
`src/GARCHFit.jl` uses the same likelihood, starting values, BFGS solver, and
forward differentiation while retaining convergence diagnostics. Acceptance
records are stored with the model cache; both evaluators validate them and run
a trial at the scoring horizon before producing results. Trial checks use a
private random-number generator and do not change the evaluation stream.

The September 2026 refit accepted the same 393 training assets and excluded
the same 30 nonstationary fits; all 423 optimizations converged. Accepted
coefficients matched the previous cache exactly. GARCH therefore covers 39,300
training paths and 38,600 holdout paths at 100 replications per asset (393 and
386 assets). Other methods cover 423 training and 416 holdout assets. Use the
common 393-asset results in the centering-control summary for training
comparisons across all six methods. This fit correction does not resolve the
separate canonical training-result cache audit.

Run the GARCH regression tests with:

```sh
julia --project=code/downstream-evaluation code/downstream-evaluation/test/garch_fit.jl
```

The test includes a real ALB fit that returns successfully but cannot be
simulated, a forced optimizer stop, invalid coefficients, legacy/inconsistent
caches, and preservation of the evaluation random stream.

## Portable-input check

This check loads the ordinary cached inputs, reconstructs the training universe
and OLS calibration from the pinned data dependency, and fits AAPL, QQQ, and
SPY marginals in a temporary directory without using any fitted-model cache:

```sh
julia --project=code/downstream-evaluation code/downstream-evaluation/test/portable_inputs.jl
```

## Output destinations

Scripts 04 and 04b write into `jfds-paper/sections/tables/`. Figure scripts
write cited assets into `jfds-paper/figs/main/` or
`jfds-paper/figs/supplement/`; uncited diagnostics go to
`jfds-paper/figs/diagnostics/`. Re-running them overwrites the corresponding
static `.tex` and `.pdf` files.
Re-running the pipeline therefore refreshes the manuscript inputs in place;
the next `pdflatex` rebuild picks up the new numbers.

Script 06 (`06-VaR-Backtest.jl`) writes `data/var-backtest-summary.csv`;
script 04b (`04b-VaR-Table.jl`) reformats that CSV into
`table5_var_backtest.tex`. The split exists because 06 is the slow
downstream step and 04b is a pure formatter.

The uncited VaR plot is retained as `figs/diagnostics/VaR-Backtest.pdf` for
historical comparison.

## Jump-enabled composition experiment

Scripts `11-Jump-Ablation.jl` and `11b-Jump-Ablation-Report.jl` compare jumps
off, market jumps only, and market-plus-asset jumps. Each configuration uses
exactly paired naive and corrected composition. The existing closing-price
fits remain frozen, and enabled models receive the published SPY settings
from `jump-ablation.toml` without per-ticker tuning. Unlike the older in-sample
comparison, the market is simulated in both the training and holdout windows.
The correction uses each simulated market path's variance, unlike the frozen
training market variance used for the six-method holdout comparison.

From the repository root:

```sh
julia --project=code/downstream-evaluation --threads=8 code/downstream-evaluation/scripts/11-Jump-Ablation.jl
julia --project=code/downstream-evaluation code/downstream-evaluation/scripts/11b-Jump-Ablation-Report.jl
julia --project=code/downstream-evaluation code/downstream-evaluation/test/jump_ablation.jl
julia --project=code/downstream-evaluation code/downstream-evaluation/test/jump_ablation_outputs.jl
```

The full run uses 1,000 paths per asset/configuration/method across four seeds.
`--smoke` on script 11 selects three assets and 20 paths in a separate output
folder. Outputs are isolated under `results/jump-ablation/`, including
[the report](results/jump-ablation/REPORT.md), CSV summaries, a PNG/PDF figure,
and local resumable seed/window checkpoints. No existing manuscript tables or
model caches are overwritten. Settings and fingerprints protect checkpoint
reuse; choose a new output directory when changing the experiment settings or
source. Checkpoints and smoke outputs are excluded from Git.

The primary temporal metric uses absolute-return ACF lags 1-25, with lags
1-60 as a secondary check. Monte Carlo uncertainty keeps all tickers together
under their shared market replication. It is conditional on the frozen fits
and observed histories; it does not measure uncertainty across market regimes.
Both unconditional outcomes and jump-active strata are saved. The AD scorer
reuses its sample-size normalization while retaining the pinned dependency's
statistic and p-value; tests compare it with the unoptimized implementation.

To regenerate the main comparison table and supplementary uncertainty table
in both manuscript trees from the saved CSVs, run:

```sh
python3 code/downstream-evaluation/scripts/11c-Jump-Ablation-Tables.py
```

The formatter updates the arXiv tree first and then the JFDS tree. Both paper
versions discuss the experiment in Results, Methods, Discussion, and Conclusion.

### Canonical training results (ranked audit issue 5)

Script 03 requires all three fitted-model caches and writes the complete
six-method training comparison. It retains seed 1234, 100 draws per asset,
the observed 2,766-day training SPY path, and the production composers and
random-draw order. Generation is serial; deterministic scoring is threaded.
The Anderson--Darling sample-size normalization is reused, with tests against
the original package calculation. No-jump fits and the validated GARCH
eligibility are required.

Every completed asset is checkpointed under `results/training-canonical/`.
Rerunning script 03 resumes only if the code, inputs, fitted models,
configuration, Julia version, and dependency sources match. Use `--restart`
to recompute checkpoints after a change. The canonical files are installed
only after the full asset/method/replication set and numeric scores pass
validation. Interrupted output writes are detected by the artifact hashes.

Script 04 verifies the canonical cache, its compact summary, and their
provenance before writing Table 3 and the two supplementary breakdowns to
arXiv first, then JFDS. `--check` regenerates the table text
in memory and requires exact agreement with both manuscript trees, without
writing them. The formatter can use the distributed path cache without the
local fitted-model archives; if any fitted archive is present, its hash must
match. The old `HMM_PAPER_RESULTS_FILE` override is rejected for paper tables.

The September 14 rerun recovered all 250,800 historical centered-path scores
within numerical tolerance and left every displayed value in the three
tables unchanged. The old canonical cache had retained the uncentered naive
and hybrid results, while its advertised CSV contained only three methods.
The [item 5 report](../../audits/2026-09-14-review/training-correction/README.md)
records the preserved originals, comparisons, and independent table checks.
Figure 4's separate variance-denominator correction remains outstanding.

### Pooled thresholds for holdout VaR (ranked audit issue 4)

Table 5 now uses `scripts/13-VaR-Ensemble.jl` and `var-ensemble.toml`.
For each frozen training asset and method, it pools the daily returns from
5,000 separately composed 249-day paths, then checks the thresholds on 1,000
independent paths. All thresholds are saved before reading the 2025 holdout.
Path centering, scaling, the training market variance, HMM initialization,
and GARCH warmup remain unchanged. This estimates the uniform-day marginal
of the 249-day construction, whose horizon dependence remains in force.

`results/var-ensemble/` contains per-asset calibration checkpoints, threshold
convergence, independent simulation checks, 2025 breach counts, available-asset
and common-asset summaries, and input/source fingerprints. The run resumes
only with matching fingerprints and checks each saved ticker/method/checkpoint.
`--pilot` uses a separate directory and never reads the holdout. Use
`--compiled-modules=existing` when running with a read-only Julia depot.

Script 14 validates provenance and writes the pooled Table 5 to both manuscript
trees. Script 10b delegates its Table 5 output to script 14; it cannot overwrite
that table with the old per-path estimates in `results-oos.jld2`. Its Table 4
scorecard and figure retain their existing 100-path protocol. Scripts 06/04b
and the per-path VaR/Kupiec fields in the older evaluator are legacy diagnostics,
not sources for the current Table 5. The known Kupiec boundary issue remains a
separate correction; Table 5 reports descriptive rates and cross-asset SDs.

The [issue 4 report](../../audits/2026-09-14-review/var-correction/README.md)
records the before/after comparison, convergence checks, and manuscript scope.
