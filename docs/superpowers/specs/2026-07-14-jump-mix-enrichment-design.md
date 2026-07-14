# Design: Jump-Mix Enrichment Frontier (diagnostic)

Date: 2026-07-14
Status: approved (brainstorming), pending implementation plan
Scope: single read-only diagnostic script; no manuscript or paper-data changes

## Motivation

The HMM-WJ generator produces an ensemble in which roughly 75% of simulated
paths contain no jump (they reduce to the no-jump generator, HMM-NJ) and roughly
25% contain at least one forced-tail step. This split is an emergent consequence
of the jump probability epsilon; it is not itself a tuned quantity. The question:
what happens to the stylized facts if we resample the ensemble to a target
jump-path fraction f (for example 50/50 or 25/75) instead of the natural ~25/75?

The intuition to test: enriching the jump population should improve
volatility-clustering capture at some cost to marginal fidelity. This experiment
characterizes that tradeoff frontier across f, treating the mix fraction as a
post-hoc ensemble knob that is deliberately decoupled from epsilon (we are not
retuning epsilon; the fitted model is untouched).

## Key prior evidence (shapes expectations)

A Hill tail-index diagnostic already exists (commit `7aef57c`, output in
`code/spy-experiment/diagnostics/tail_index_p1.txt`). On the IS window, 1,000
paths:

| series | excess kurtosis | pooled Hill alpha |
|---|---|---|
| Observed SPY | 7.71 | 3.14 |
| HMM-WJ (natural f ~ 0.25) | 7.47 | 2.87 |
| HMM-NJ (f = 0) | 8.05 | 2.84 |

Its conclusion: WJ and NJ coincide on the marginal tail because the
Student-t(nu=5) emission carries it; their difference is volatility clustering,
not the tail. Working the convex combination backward from the two points above,
the no-jump stratum sits near kurtosis 8.05 and the jump stratum near 5.7, so
enriching jumps is expected to LOWER kurtosis (clustered mid-to-large moves raise
variance and de-normalize the fourth moment), passing through the observed 7.71
near f ~ 0.15 and overshooting below it thereafter, while pooled Hill alpha
barely moves. Predicted story: clustering (ACF-MAE) improves monotonically in f,
while the cost lands on kurtosis and KS body-fidelity rather than on the extreme
tail index. The experiment confirms or refutes this and locates any Pareto knee
(the best-clustering f and the kurtosis-matching f are expected to differ).

## The analytic backbone

Every per-path metric the paper reports is an average over paths, so the enriched
value at target jump-fraction f is exactly the convex combination

    M(f) = f * M_jump + (1 - f) * M_nojump

where M_jump is the metric averaged over jump-paths and M_nojump over
no-jump-paths. Consequences:

1. For per-path-mean metrics (KS/AD pass, kurtosis, W1, Hellinger) the frontier
   is a determined straight line between the two strata; no resampling is
   required. ACF-MAE is the one non-scalar case: the paper reports the MAE over
   252 lags of the ensemble-mean |g| autocorrelation curve, so it combines
   through linear stratum-mean *curves* followed by a final MAE. That is still
   analytic and exact from the two stratum curves, but non-linear (slightly
   bowed) in f, not a straight line.
2. HMM-NJ is the f = 0 endpoint and today's HMM-WJ is the f ~ 0.25 point on the
   same line, so the mix dial is literally "distance from HMM-NJ toward a
   pure-jump generator."
3. The only exception is a metric computed on the pooled (concatenated) sample,
   such as the Hill tail index, which is non-linear in f and requires actual
   resampling. This is also where the tail behavior is measured.

## Decisions (locked during brainstorming)

- Ambition: diagnostic-first. Standalone script + frontier table + one figure. No
  manuscript changes; decide later whether the result earns a place in the paper.
- Path classification: binary, `any(p.jumps)` (a path is a jump-path iff it
  contains at least one forced-tail step). Matches the paper's convention and the
  natural ~75/25 split.
- Window: IS only (2,766 days). The 249-day OoS horizon has too few jump-paths
  for a stable enrichment; noted as a caveat, not swept.
- Method: Approach A. Exact convex-combination frontier for per-path-mean
  metrics, targeted resampling only for the pooled Hill index.
- Pool size 4,000 paths; R = 200 resampling replications for the pooled metric.

## Inputs and reuse

- Data: load `model_wj` and `g_is` (`insampledataset`) from
  `HMM-WJ-SPY-N-100-daily-aggregate.jld2` via the project's `_PATH_TO_DATA`,
  consistent with the existing `Empirical-ACF-Check.jl` / `Empirical-Episode-
  Calibration.jl` scripts.
- Estimators (reused so the numbers match the paper exactly):
  - ACF-MAE: MAE over lags 1:252 of the ensemble-mean |g| autocorrelation curve
    against the empirical curve, matching the paper's reported `_L_ACF = 252`
    convention (Table2-SEs.jl, Baseline-Comparison.jl). Computed from the two
    stratum-mean ACF curves, not per-path scalars. (The tune objective uses 25
    lags; the reported metric uses 252, which is what the frontier must match.)
  - kurtosis: `StatsBase.kurtosis` (excess).
  - KS / AD p-values: `pvalue(ApproximateTwoSampleKSTest(g_is, obs))`,
    `pvalue(KSampleADTest(g_is, obs))`; pass = p > 0.05.
  - W1 / Hellinger: `JumpHMM._wasserstein1`, `JumpHMM._hellinger` (module-
    qualified; these are the same internals `validate()` uses).
  - Hill alpha: reimplement the standard Hill estimator inline (a few lines),
    matching the convention in `code/downstream-evaluation/src/Metrics.jl`
    (pooled upper `|G_t|`, same upper-tail fraction). Importing that file
    directly would pull a separate project's dependencies, so it is reimplemented
    rather than imported; the f = 0 anchor (Hill ~ 2.84) validates that the inline
    version matches `tail_index_p1.txt`.
- Seed 1234, set via `Include.jl`.

## Algorithm

1. Simulate one pool of `N_POOL = 4000` paths from `model_wj` at the fitted
   `(epsilon, lambda)`.
2. Tag each path jump/no-jump via `any(p.jumps)`. Report both stratum sizes and
   the empirical jump fraction (sanity: ~0.25).
3. For every pool path, compute the six per-path metrics against `g_is`. Store
   per-stratum means and standard errors (`std / sqrt(n_stratum)`).
4. Per-path-mean frontier: for `f` in `{0.0, 0.1, ..., 1.0}` plus `0.25`, report
   `M(f) = f*mean_jump + (1-f)*mean_nojump` with propagated SE
   `sqrt(f^2 * SE_jump^2 + (1-f)^2 * SE_nojump^2)`.
5. Pooled Hill: for each `f`, draw `R = 200` resampled 1,000-path ensembles
   (`round(f*1000)` jump-paths + remainder no-jump-paths, sampled with
   replacement from the respective strata), concatenate observations, compute
   pooled Hill alpha; report mean and MC standard deviation across the R draws.
6. Assemble the frontier table and figure.

## Outputs

- stdout: the frontier table (columns `f`, ACF-MAE, kurtosis, Hill alpha,
  KS-pass, AD-pass, W1, Hellinger), plus the stratum sizes and the three
  correctness-check lines below.
- `code/spy-experiment/diagnostics/jump_mix_frontier.csv`: the same table.
- `code/spy-experiment/diagnostics/jump_mix_frontier.pdf`: one figure with
  ACF-MAE on the x-axis and kurtosis and Hill alpha on twin y-axes across the f
  grid, with the observed SPY targets (kurtosis 7.71, Hill 3.14) and the f = 0.25
  operating point marked.
- Nothing under `jfds-paper/` or the paper JLD2 data is written.

## Correctness checks (printed by the script)

- f = 0.25 row reproduces the published HMM-WJ numbers (kurtosis ~ 7.47,
  ACF-MAE ~ 0.052, KS-pass ~ 97.6%) within Monte Carlo noise.
- f = 0 row reproduces HMM-NJ (kurtosis ~ 8.05, Hill ~ 2.84).
- At one interior f (0.5), the analytic value of a linear metric (kurtosis)
  matches a directly resampled 1,000-path ensemble of that mix within the
  propagated SE, validating the convex-combination shortcut end to end.

## Out of scope (explicit)

- Retuning epsilon or lambda (deliberately left untouched).
- OoS-window enrichment (too few jump-paths at 249 days).
- Graded-by-intensity stratification (single-vs-multi-jump), min-episode
  thresholds, or importance weighting.
- Any manuscript figure, table, or prose. This is a diagnostic; promotion to a
  paper result is a separate decision after the frontier is seen.
- A production enriched-ensemble sampler for downstream consumers (the resampling
  routine exists as a byproduct but is not packaged or exported).

## Success criterion

The script runs clean under `julia --project=. Jump-Mix-Enrichment-Frontier.jl`
from `code/spy-experiment/`, reproduces the three anchor points within noise, and
emits a frontier table + figure that make the ACF-MAE-versus-kurtosis/Hill
tradeoff legible, so the author can judge whether a mix fraction Pareto-dominates
the natural f ~ 0.25 operating point.
