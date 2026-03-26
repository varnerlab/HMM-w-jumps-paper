# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Research paper repo: "Hybrid Hidden Markov Model for Modeling Equity Excess Growth Rate Dynamics" by Alswaidan & Varner (Cornell). Contains both a LaTeX manuscript (ACM acmsmall template) and Julia experiment code for HMM-based synthetic equity data generation.

## Build Commands

### LaTeX Paper
```bash
cd paper && sh Build.sh Paper_v1
```
This runs pdflatex/bibtex triple-pass. Main file: `paper/Paper_v1.tex`. Sections are in `paper/sections/*.tex`, bibliography in `paper/References_v1.bib`.

### Julia Experiments
Each experiment directory (`code/spy-experiment/`, `code/baseline-comparison/`, etc.) has its own `Project.toml` and `Manifest.toml`. Always activate the correct project:
```bash
julia --project=code/spy-experiment code/spy-experiment/Table1-Descriptive-Stats.jl
```
Or from within the directory:
```bash
cd code/spy-experiment && julia --project=. Table1-Descriptive-Stats.jl
```
Every script starts with `include("Include.jl")` which handles package installation (auto-installs `JumpHMM.jl` and `VLQuantitativeFinancePackage` from GitHub on first run), loads dependencies, and sets random seed to `1234`.

### Neural Baseline (Python)
```bash
cd code/baseline-comparison/neural-baseline
source .venv/bin/activate
# Python GRU baseline; evaluated via Julia in Neural-Baseline-Evaluation.jl
```

## Architecture

- **`paper/`**: ACM acmsmall-formatted LaTeX. `Paper_v1.tex` is the root; it `\input{}`s files from `sections/`. Figures live in `sections/figs/` as PDFs.
- **`code/spy-experiment/`**: Core experiment directory. Contains all SPY analysis scripts (figures, tables, parameter sweeps, validation). Precomputed results stored as JLD2 files in `data/`. This is the primary data source; other experiments reference it.
- **`code/baseline-comparison/`**: Six-model benchmark (Bootstrap, Gaussian, Laplace, GARCH, HMM-NJ, HMM-WJ) plus HSMM and GRU neural baselines. References `spy-experiment/data/` for shared data.
- **`code/other-ticker-experiment/`**: Cross-asset evaluation (NVDA, JNJ, JPM).
- **`code/sim-experiment/`**: Multi-asset Single-Index Model extension (424 assets).
- **`code/gbm-experiment/`**: Geometric Brownian Motion baseline.

Key dependencies:
- [`JumpHMM.jl`](https://github.com/varnerlab/JumpHMM.jl) provides HMM model fitting (`fit(JumpHiddenMarkovModel, prices)`), jump tuning (`tune()`), simulation (`simulate()`), decoding (`decode()`, `forward_filter()`), and validation (`validate()`). Also provides copula-based multivariate models (`GaussianCopula`, `StudentTCopula`, `VineCopula`, `SingleIndexModel`, `PortfolioModel`).
- [`VLQuantitativeFinancePackage.jl`](https://github.com/varnerlab/VLQuantitativeFinancePackage.jl) provides market data loading (`MyTrainingMarketDataSet()`, `MyTestingMarketDataSet()`) and growth rate computation (`log_growth_matrix()`).

## Writing Conventions

- **Never use em dashes** (---, or unicode em dash) in the paper. Use commas, semicolons, colons, or parentheses instead.
- Results text follows the pattern: "We did X, we saw Y, which suggests Z (Fig/Table ref)."
- Always verify numerical claims against the actual code/data before stating them.
