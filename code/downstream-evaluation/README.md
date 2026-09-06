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
│   ├── Pipeline.jl        universe loading, fitting, scoring, artifact I/O
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
julia --project=. scripts/01c-Fit-GARCH.jl                 # GARCH(1,1)-t fits + sim cache
julia --project=. scripts/03-Compose-And-Evaluate.jl       # six-composer paired evaluation
julia --project=. scripts/03b-Stress-Eval.jl               # clipping-branch stress test
julia --project=. scripts/03c-Seed-Sweep.jl                # seed-uncertainty table
julia --project=. scripts/03d-Sensitivity-Sweep.jl         # hybrid hyperparameter sweep
julia --project=. scripts/04-Tables.jl                     # table .tex files (T1-T4)
julia --project=. scripts/05-Figures.jl                    # main figure PDFs
julia --project=. scripts/06-VaR-Backtest.jl               # per-ticker VaR + Kupiec -> var-backtest-summary.csv
julia --project=. scripts/04b-VaR-Table.jl                 # T5 var-backtest .tex (must run after 06)
julia --project=. scripts/07-Cov-Diagnostic.jl             # cross-term covariance check
julia --project=. scripts/08-Synthetic-Tracker-Eval.jl     # R²-preserve branch check
julia --project=. scripts/09-Extra-Figures.jl              # revision figures
julia --project=. scripts/10-OoS-Evaluation.jl             # frozen-fit 2025 six-composer evaluation
julia --project=. scripts/10b-OoS-Table.jl                 # OoS manuscript tables and figure
```

The marginal and GARCH fitting scripts reuse existing model caches. Move
those caches aside before changing the fitted-model configuration. Evaluation
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
- `data/results-summary.csv` (26 MB) — per-ticker × composer aggregate metrics on the seed=1234 canonical run, the source of the numbers in `jfds-paper/sections/tables/`.
- `data/var-backtest-summary.csv` (1.2 KB) — per-composer mean exceedance rate, cross-ticker SD, mean Kupiec p, Kupiec pass rate.
- `data/synth-tracker-summary.csv` (1.7 KB) — synthetic-tracker β/R² recovery summary.
- `data/synth-tracker.csv` (177 KB) — per-tracker results.
- `data/sim-calibration.csv` (34 KB) — per-ticker (α, β, R², σ_ε) from script 02.
- `data/cov-diagnostic.csv` (74 KB) — cross-term Cov(ε̃, g_m) per ticker per composer.
- `data/garch-t-skipped.csv` (853 B) — tickers where GARCH fitting failed.

## Data regenerated by the pipeline (not committed)

`marginals.jld2`, `marginals-residuals.jld2`, `garch-t-models.jld2`,
`garch-t-sims.jld2`,
`results-seed-*.jld2`, `results-stress.jld2`, `results-thresh-*.jld2`,
`var-backtest.jld2`, `synth-tracker.jld2`. The fitted full-return, residual, and GARCH model archives are local caches
and are not distributed in Git. Regenerate them with scripts 01, 02, 01b,
and 01c in that order. The committed manifest pins the dependency source
trees; instantiate that environment before fitting.

`results-oos.jld2` and `results-oos.csv` contain the per-path 2025 holdout
evaluation. They are reproducible caches and are ignored by Git; the compact
`results-oos-summary.csv` and `var-backtest-oos-summary.csv` outputs are the
versioned sources for the manuscript tables. The evaluator also compares
every synthetic path with a random contiguous 249-day block from the training
period so that KS/AD rejection rates can be interpreted at a matched sample
length. Tables 4 and 5 use the observed training market variance in the
correction, even though their market paths are simulated. Each asset draw
still supplies its own generator variance. In contrast, Table 6 uses each
simulated market path's variance in both windows. No 2025 observations enter
fitting or either variance convention; holdout observations are used only
for scoring. The multi-asset closing-price experiments use `risk_free_rate = 0`.

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
