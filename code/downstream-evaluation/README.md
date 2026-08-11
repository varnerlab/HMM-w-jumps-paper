# Downstream-evaluation pipeline

Reproducibility code for the multi-composer downstream-evaluation results in
*Hybrid Hidden Markov Model for Modeling Equity Excess Growth Rate Dynamics:
A Discrete-State Approach with a Jump-Duration Mechanism* (Alswaidan & Varner). This
directory produces the six-composer comparisons (naive, Gaussian SIM, hybrid,
JumpHMM-on-residuals, block bootstrap, GARCH(1,1)-t), the per-ticker VaR
backtest, the seed-uncertainty table, the stress and sensitivity sweeps, the
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
share the same per-ticker generator draw `ε̃` (paired comparison). Before a
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
julia --project=. scripts/01-Fit-Marginals.jl              # ~hours: 424 JumpHMM fits
julia --project=. scripts/01b-Fit-Residual-Marginals.jl    # JumpHMM fits on OLS residuals
julia --project=. scripts/01c-Fit-GARCH.jl                 # GARCH(1,1)-t fits + sim cache
julia --project=. scripts/02-Calibrate-SIM.jl              # per-ticker OLS vs SPY
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

Each script is idempotent: if its primary output JLD2 already exists in
`data/`, the script reuses the cache instead of recomputing. Delete the
cached artifact to force a refit.

## Data committed in this repo

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
`garch-t-sims.jld2`, `sim-calibration.jld2`, `universe.jld2`, `results.jld2`,
`results-seed-*.jld2`, `results-stress.jld2`, `results-thresh-*.jld2`,
`var-backtest.jld2`, `synth-tracker.jld2`. These intermediates exceed the
small-summary threshold; rebuild them by running the pipeline.

`results-oos.jld2` and `results-oos.csv` contain the per-path 2025 holdout
evaluation. They are reproducible caches and are ignored by Git; the compact
`results-oos-summary.csv` and `var-backtest-oos-summary.csv` outputs are the
versioned sources for the manuscript tables. The evaluator also compares
every synthetic path with a random contiguous 249-day block from the training
period so that KS/AD rejection rates can be interpreted at a matched sample
length.

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
