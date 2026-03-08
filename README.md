# Hybrid Hidden Markov Model with Jump-Diffusion for Synthetic Equity Data Generation

This repository contains the code and paper for:

> **Hybrid Hidden Markov Model for Modeling Equity Excess Growth Rate Dynamics: A Discrete-State Approach with Jump-Diffusion**
> Abdulrahman Alswaidan and Jeffrey Varner, Cornell University

The framework discretizes continuous excess growth rates into Laplace quantile-defined market states and augments the resulting hidden Markov process with a Poisson-driven jump-duration mechanism. This produces synthetic equity time series that simultaneously reproduce heavy-tailed distributions, negligible linear autocorrelation, and persistent volatility clustering.

This material was inspired by [CHEME 5660: Quantitative Finance for Scientists and Engineers](https://varnerlab.github.io/CHEME-5660-Markets-Mayhem-and-Money-Fall-2024/) at Cornell University.

## Repository Structure

```
.
├── paper/                          # LaTeX manuscript
│   ├── Paper_v1.tex                # Main document
│   ├── References_v1.bib           # Bibliography
│   └── sections/                   # Section files (intro, methods, results, etc.)
│       └── figs/                   # Compiled figures (PDF)
│
└── code/
    ├── spy-experiment/             # Core SPY single-asset experiments
    ├── baseline-comparison/        # Six-generator benchmark (Table 2)
    ├── other-ticker-experiment/    # Cross-asset evaluation (NVDA, JNJ, JPM) — Online Appendix S5
    ├── sim-experiment/             # Multi-asset Single-Index Model extension
    └── gbm-experiment/             # Geometric Brownian Motion baseline
```

## Experiments and Scripts

### `code/spy-experiment/` — Core SPY analysis

The primary experiment directory. All scripts begin with `include("Include.jl")`.

| Script | Description |
|--------|-------------|
| `Include.jl` | Environment setup, package loading, random seed (`1234`) |
| `Fig1-Empirical-Motivation-SPY.jl` | Figure 1: Empirical stylized facts (distribution, Q-Q, ACF plots) |
| `Fig3-Model-Internals-SPY.jl` | Figure 3: Fitted CDF, transition matrix heatmap, residence times |
| `Fig4-Replot-SPY.jl` | Figure 4: Simulated vs. observed path comparison |
| `Fig6-Statistical-Validation-SPY.jl` | Figure 6: KS/AD p-value distributions and ACF envelope |
| `GARCH-Benchmark-SPY.jl` | GARCH(1,1) benchmark comparison |
| `HMM-Parameter-Sweep.jl` | Grid search over (epsilon, lambda) hyperparameters (Figure 5) |
| `OoS-Validation-SPY.jl` | Out-of-sample validation on 2025 data (249 trading days) |
| `Table1-Descriptive-Stats.jl` | Table 1: Descriptive statistics for SPY excess growth rates |
| `Table2-SEs.jl` | Table 2: Standard errors for GARCH/HMM-NJ/HMM-WJ metrics |
| `Table3-Sensitivity-ACF-MAE.jl` | Table 3: State resolution sensitivity (N = 30, 60, 90, 100, 150, 200) |
| `Table3-Diagnostics.jl` | State occupancy health checks for Table 3 |

### `code/baseline-comparison/` — Full six-model benchmark

Computes all metrics (KS pass rate, AD pass rate, excess kurtosis, ACF-MAE, Wasserstein-1, Hellinger distance, novelty, diversity, coverage) for six generators: Bootstrap, Gaussian, Laplace, GARCH(1,1), HMM-NJ, and HMM-WJ. Produces the complete Table 2 (in-sample and out-of-sample panels).

| Script | Description |
|--------|-------------|
| `Include.jl` | Environment setup (references `spy-experiment/data/` for shared data) |
| `Baseline-Comparison.jl` | Full Table 2 computation across all 6 models and all metrics |

### `code/other-ticker-experiment/` — Cross-asset evaluation (Online Appendix S5)

Fits standalone HMM-NJ and HMM-WJ models to individual equities with distinct risk profiles and evaluates distributional and temporal fidelity.

| Script | Description |
|--------|-------------|
| `Include.jl` | Environment setup |
| `Multi-Ticker-Evaluation.jl` | Grid search + full evaluation for NVDA, JNJ, JPM (Table S5) |

### `code/sim-experiment/` — Multi-asset Single-Index Model extension

Propagates the SPY factor path to a 424-asset universe using the Single-Index Model.

| Script | Description |
|--------|-------------|
| `Include.jl` | Environment setup |
| `SIM-Multi-Asset-KS.jl` | In-sample KS pass rates for 424 assets |
| `SIM-Multi-Asset-KS-OoS.jl` | Out-of-sample KS pass rates |
| `Fig7-Multi-Asset-SIM.jl` | Figure 7: Multi-asset pass rate distributions (in-sample) |
| `Fig7S-Multi-Asset-SIM-OoS.jl` | Figure 7 supplement: out-of-sample |
| `Table4-Multi-Asset-Stats.jl` | Table 4: Summary statistics across the asset universe |

## Installation

### Prerequisites

- [Julia](https://julialang.org/downloads/) (v1.10 or later recommended)

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/<your-username>/HMM-w-jumps-paper.git
   cd HMM-w-jumps-paper
   ```

2. Each experiment directory has its own `Project.toml` and `Manifest.toml`. Scripts must be run with the project activated using `--project=.`. The recommended approach is to run scripts directly from the repo root, specifying the project path:
   ```bash
   julia --project=code/spy-experiment code/spy-experiment/Table1-Descriptive-Stats.jl
   ```
   Or `cd` into the experiment directory first:
   ```bash
   cd code/spy-experiment
   julia --project=. Table1-Descriptive-Stats.jl
   ```
   On first run, `Include.jl` will automatically install all dependencies (including `VLQuantitativeFinancePackage` from GitHub) if no `Manifest.toml` is present.

3. Alternatively, run scripts interactively in the Julia REPL with the project activated:
   ```bash
   cd code/spy-experiment
   julia --project=.
   ```
   ```julia
   julia> include("Table1-Descriptive-Stats.jl")
   ```

### Key Dependencies

All experiments depend on [`VLQuantitativeFinancePackage.jl`](https://github.com/varnerlab/VLQuantitativeFinancePackage.jl), which provides the HMM construction, simulation, and decoding routines. It is installed automatically by `Include.jl`.

Other notable packages: [`ARCHModels.jl`](https://github.com/s-broda/ARCHModels.jl) (GARCH benchmark), [`HypothesisTests.jl`](https://github.com/JuliaStats/HypothesisTests.jl) (KS/AD tests), [`Distributions.jl`](https://github.com/JuliaStats/Distributions.jl) (Laplace fitting), [`JLD2.jl`](https://github.com/JuliaIO/JLD2.jl) (data serialization), [`Plots.jl`](https://github.com/JuliaPlots/Plots.jl) / [`StatsPlots.jl`](https://github.com/JuliaPlots/StatsPlots.jl) (figures).

## Reproducing Results

Each experiment directory is self-contained with its own `Project.toml` and `Manifest.toml`. Always use `--project=<dir>` or run from inside the directory with `--project=.`. The recommended order:

1. **SPY core analysis** — precomputed results are already stored in `data/*.jld2`; re-run individual scripts to regenerate figures or tables:
   ```bash
   julia --project=code/spy-experiment code/spy-experiment/Table1-Descriptive-Stats.jl
   ```
2. **Baseline comparison** — references data from `spy-experiment/data/`:
   ```bash
   julia --project=code/baseline-comparison code/baseline-comparison/Baseline-Comparison.jl
   ```
3. **Cross-asset evaluation** (NVDA, JNJ, JPM):
   ```bash
   julia --project=code/other-ticker-experiment code/other-ticker-experiment/Multi-Ticker-Evaluation.jl
   ```
4. **Multi-asset SIM extension**:
   ```bash
   julia --project=code/sim-experiment code/sim-experiment/SIM-Multi-Asset-KS.jl
   ```

### Data Files

Precomputed results are stored as JLD2 files in each experiment's `data/` directory:

| File | Contents |
|------|----------|
| `spy-experiment/data/HMM-WJ-SPY-N-100-daily-aggregate.jld2` | Fitted HMM model for SPY (N=100) |
| `spy-experiment/data/HMM-Parameter-Sweep-SPY.jld2` | Grid search results over (epsilon, lambda) |
| `spy-experiment/data/GARCH-Benchmark-SPY.jld2` | GARCH(1,1) benchmark results |
| `spy-experiment/data/OoS-Validation-SPY.jld2` | Out-of-sample validation results |
| `sim-experiment/data/SIMs-SP500-01-03-14-to-12-31-24.jld2` | Fitted Single-Index Models for 424 assets |
| `sim-experiment/data/SIM-Multi-Asset-Results.jld2` | Multi-asset in-sample results |
| `sim-experiment/data/SIM-Multi-Asset-Results-OoS.jld2` | Multi-asset out-of-sample results |
| `sim-experiment/data/SP500-GICS-Sectors.csv` | GICS sector classifications |

## Citation

If you use this code or framework in your research, please cite:

```bibtex
@article{alswaidan2026hybrid,
  title={Hybrid Hidden Markov Model for Modeling Equity Excess Growth Rate Dynamics: A Discrete-State Approach with Jump-Diffusion},
  author={Alswaidan, Abdulrahman and Varner, Jeffrey},
  year={2026}
}
```

## License

This project is provided for academic and research purposes.
