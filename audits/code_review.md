# Code Review — `HMM-w-jumps-paper`

Date: 2026-03-08

## Scope
Reviewed Julia scripts under `code/` and cross-checked shared data-flow for correctness and runtime risk.

## Findings

### 1) High — Jump simulation loop can become non-terminating
- **File(s)**: 
  - [code/spy-experiment/HMM-Parameter-Sweep.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/spy-experiment/HMM-Parameter-Sweep.jl:66)
  - [code/other-ticker-experiment/Multi-Ticker-Evaluation.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/other-ticker-experiment/Multi-Ticker-Evaluation.jl:145)

- **What happens**: In `while t <= n_steps`, when `rand() < ε` and `K = rand(Poisson(λ))` equals `0`, the inner loop does not advance `t`.
- **Why it’s wrong**: If `K == 0`, the loop body never increments `t`, so execution can stay in `while t <= n_steps` indefinitely.
- **Risk**: Simulation hang / hard-to-debug run stalls during grid search and OoS path generation.

### 2) Medium — Table 4 summary helpers assume non-empty filtered data
- **File**: [code/sim-experiment/Table4-Multi-Asset-Stats.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/sim-experiment/Table4-Multi-Asset-Stats.jl:23)

- **What happens**: `summary_stats` filters out `NaN` but still calls `mean/median/quantile` without checking if all entries were filtered out.
- **Why it’s wrong**: If all values are `NaN` (possible after stricter filtering or future data changes), this throws.
- **Risk**: Post-processing script can fail on otherwise valid-but-empty subsets.

### 3) Medium — RNG reproducibility with threaded kernels is fragile
- **File(s)**:
  - [code/spy-experiment/Include.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/spy-experiment/Include.jl:33)
  - [code/spy-experiment/GARCH-Benchmark-SPY.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/spy-experiment/GARCH-Benchmark-SPY.jl:99)

- **What happens**: Global seed is fixed once (`Random.seed!(1234)`), but Monte Carlo loops are executed in `Threads.@threads` in multiple places.
- **Why it’s wrong**: Thread scheduling and RNG state interleaving can make results non-reproducible across runs / systems even with the same seed.
- **Risk**: Regression reproducibility claims become weaker than documented; generated figures/metrics may vary slightly run-to-run.

## Suggested fixes (prioritized)

1. **Immediate**: Add explicit `else` branch for `K == 0` in jump simulators to guarantee `t` advances by 1 when no Poisson jump is drawn.
2. **Short**: Add `isempty(v)` guard in `summary_stats` returning `(NaN, NaN, NaN, NaN, 0)` and log a warning.
3. **Paper-quality reproducibility**: switch threaded simulation paths to per-thread/task RNGs (e.g., task-local streams) so seeds remain stable under thread scheduling.

## Open questions
- Should I also patch these directly in this repo now? (I can apply a minimal patch for 1 and 2 immediately.)

## Update (2026-03-08, follow-up verification)

### What changed since the prior review

1. **High — Jump simulation loop can become non-terminating**
   - **Status:** ✅ **Fixed**
   - **Files verified**:
     - [code/spy-experiment/HMM-Parameter-Sweep.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/spy-experiment/HMM-Parameter-Sweep.jl:66)
     - [code/other-ticker-experiment/Multi-Ticker-Evaluation.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/other-ticker-experiment/Multi-Ticker-Evaluation.jl:145)
   - **Verification:** Both `simulate_jump_path` implementations now explicitly handle `K == 0`, fall back to a single-step transition, and increment `t`, so `while t <= n_steps` always makes progress.

2. **Medium — Table 4 summary helpers assume non-empty filtered data**
   - **Status:** ✅ **Fixed**
   - **File verified**:
     - [code/sim-experiment/Table4-Multi-Asset-Stats.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/sim-experiment/Table4-Multi-Asset-Stats.jl:25)
   - **Verification:** `summary_stats` now exits early on empty vectors with `NaN` placeholders and `n = 0` (`isempty` guard).

3. **Medium — RNG reproducibility with threaded kernels is fragile**
   - **Status:** ⚠️ **Deferred (intentionally ignored)**
   - **Files verified**:
     - [code/spy-experiment/Include.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/spy-experiment/Include.jl:34)
     - [code/spy-experiment/GARCH-Benchmark-SPY.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/spy-experiment/GARCH-Benchmark-SPY.jl:99)
     - [code/other-ticker-experiment/Include.jl](/Users/jeffreyvarner/Desktop/papers/HMM-w-jumps-paper/code/other-ticker-experiment/Include.jl:29)
   - **Notes:** Global seeding remains, and thread-local random usage is still unresolved. This is intentionally ignored for now and not being treated as a blocking risk for this round.
