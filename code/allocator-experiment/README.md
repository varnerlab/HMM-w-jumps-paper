# Allocator experiment (diversification-return decomposition)

This directory documents the provenance of the paper's daily-rebalanced
portfolio check: the Results subsection "Daily-rebalanced portfolio check"
and the appendix table `tab:allocator_decomp`.

**This experiment was not run by the pipeline in this repository.** It was run
in a separate codebase, and the numbers reported in the paper come from that
run. This file records exactly which code, which commit, and which inputs
produced them, and what is still missing for an in-repo rerun.

## Upstream source

| | |
|---|---|
| Repository | `https://github.com/varnerlab/eCornell-AI-finance-lectures` |
| Commit | `6463280` ("S2 Monte Carlo example: bias-corrected ensemble with prior anchoring", 2026-04-23) |
| Notebook | `lectures/session-2/eCornell-AI-Finance-S2-Example-MonteCarloEvaluation-May-2026.ipynb` |
| Library | `code/src/Compute.jl`, `code/src/Types.jl`, `code/src/Factory.jl` |
| Diagnostic write-up | `audits/bias_correction_issue.md` in this repository (verbatim copy of the upstream `tmp/bias_correction_issue.md`) |

The commit pin matters. Upstream `HEAD` will **not** reproduce these numbers:
since `6463280` the ticker universe changed (20 names to 22, and the names
themselves differ), `portfolio-config.toml` changed (`target_growth`
0.07 to 0.16, `cash_fraction` 0.30 to 0.0), and `Compute.jl` gained about
1,500 lines.

Key upstream functions: `allocate_cobb_douglas`, `allocate_shares`,
`run_rebalancing_engine`, `compute_wealth_series`, `backtest_engine`,
`backtest_buyhold`, `compute_ema`, `compute_lambda`,
`generate_drifted_hybrid_scenario`.

## Inputs captured here

- `data/universe.csv` -- the exact 20 tickers at `6463280`. These are
  defensive large caps (VZ, T, MCD, PG, KO, PEP, WMT, XOM, CVX, JPM, BRK.B,
  JNJ, MRK, HON, UPS, AAPL, MSFT, APD, AMT, NEE), consistent with the
  paper's statement that the universe was limited to names with calibrated
  `(alpha, beta)` and a maximum beta of 1.21.
- `data/portfolio-config.toml` -- the allocator configuration at `6463280`.
- `data/decomposition.csv` -- the published table rows and deltas.

Run configuration from the notebook at that commit: starting budget $10,000;
5,000 hybrid-SIM forward paths; 336 steps (84-day warmup = 21-day short EMA +
63-day long EMA, then 252 active trading days); scenario seed 2026; 5 bps
per-trade cost; EMA windows 21/63 with smoothed-growth window 10 and lambda
gain 10.0; drawdown trigger 0.15; turnover cap 0.50; long-run prior 8.0%/yr.

## Why this is not yet reproducible in-repo

Note that this experiment does not share a configuration with the rest of the
paper. The main pipeline evaluates 423 tickers over the 249 observed 2025 days
with 100 replications per ticker; this one uses a 20-ticker course portfolio
over 336 days with 5,000 paths. It is a separate experiment that happens to be
reported in the same manuscript.

Still missing for a self-contained rerun:

1. The allocator and rebalancing-engine source (about 180 KB of Julia across
   `Compute.jl`, `Types.jl`, `Factory.jl`), which would have to be vendored at
   `6463280` or reimplemented.
2. `lectures/session-1/data/sim-parameter-estimates.jld2` (7.9 MB) and
   `minvar-allocation.jld2` (25 KB), the frozen per-ticker SIM fits and target
   weights the allocator reads.

The market data these depend on is already in this repository, under
`code/downstream-evaluation/data/SP500-Daily-OHLC-*.jld2`.
