# Figure 4: generator denominator and aggregation (ranked item 6; R4)

The correction uses each original generator draw's sample variance as the
denominator. Figure 4 now measures its stated quantity. The 421 ordinary
assets and two tracker assets are distinguished, the naive reference uses
each draw's actual variance budget, and the caption specifies pass fractions,
median ratios, and kernel-weighted median curves separately.

## What changed scientifically

The previous plotting script divided composed variance by observed training
variance, while its axis and caption called the denominator generator
variance. Its dotted curve also substituted the universe-median observed
variance for generator variance. These quantities cannot establish the
per-draw generator-variance target.

The new diagnostic replays the original 100 full-return draws for each of
423 non-market assets, using the same fitted models, asset ordering, seed
schedule, 2,766-observation horizon, observed training SPY path, no-jump
setting, and composition functions. All 84,600 composed variances (42,300
naive and 42,300 hybrid) match the corrected canonical training cache exactly.
The canonical cache, scores, fitted models, simulation sources, and other
figures remain unchanged.

Ratios are calculated within each paired draw before taking the median over
100 replications for a ticker. Among the 421 ordinary assets:

| Quantity | Result |
|---|---:|
| Median naive ticker ratio, composed/generator variance | 1.3170597411 |
| Median hybrid ticker ratio, composed/generator variance | 1.0001034183 |
| Range of hybrid ticker medians | 0.9933385572–1.0071707485 |
| Median individual hybrid path absolute relative error | 1.1158568% |
| 95th percentile individual hybrid path absolute relative error | 3.4079987% |
| Maximum individual hybrid path absolute relative error | 8.2436269% |

The near-unit ticker medians do not imply exact variance preservation on each
path. The replay verifies the finite-sample identity
`Var(g) = target + 2 * beta_eff * scale * Cov(market, generator)` on every
path. The relative covariance term exactly explains the variance deviation
up to floating-point tolerance. The individual-path error quantiles now
appear in the caption and Results, replacing the earlier inference from
small averages of signed cross-covariances alone. This addresses the
path-dispersion concern for this training experiment; it does not close
separate holdout or jump-active dispersion follow-ups.

QQQ and SPYG use the tracker branch. Their target is
`beta^2 * Var(market) / R2_real`, rather than generator variance. Their hybrid
median composed/generator ratios are 0.965431 and 0.998058, respectively;
their median composed/target ratios are 0.998292 and 1.000496. Outlined circles identify
both methods' tracker cases in the figure. Trackers are excluded from the
ordinary-asset smoothing curves and from the target-one summary. No paths
in this training replay use the clipping branch.

Panel (a) retains the cached KS outcomes and shows their per-ticker pass
fractions. Its solid curves are Gaussian-kernel weighted medians with beta
bandwidth 0.15. Panel (b) shows per-ticker median composed/generator ratios.
The dotted naive reference applies the same smoother to ticker medians of
the per-draw `1 + beta^2 * Var(market) / Var(generator)` values. It omits the
finite-path covariance term. The dashed line is the ordinary hybrid target.
Every ticker point lies within the plotted limits.

## Implementation and artifacts

- `scripts/15-Variance-Diagnostic.jl` and `src/VarianceDiagnostic.jl` recover
  and check the denominators without changing the frozen training runner.
- `results/variance-diagnostic/paired-paths.csv` preserves all denominators,
  covariance terms, branch targets, cached KS values, and paired ratios.
- `ticker-summary.csv`, `figure-curves.csv`, and both metadata TOMLs preserve
  aggregates, plotted curves, source/data hashes, and the training signature.
- `scripts/05-Figures.jl` validates the canonical cache and diagnostic before
  calling `src/PreservationFigure.jl`. It writes the same Figure 4 PDF to
  arXiv and JFDS. `--preservation-only` limits the run to this figure.
- The arXiv caption is in `sections/main_figures.tex`; the identical JFDS
  caption is embedded in `sections/results.tex`. Both Results passages were
  revised. The later beta-quartile passage now cites panel (a).

The plotter now uses the existing headless training setup and explicit
plotting imports. This avoids an unnecessary package-activation write to
the user's Julia logs directory while preserving the pinned environment.

## Validation

`verify_numerics.py` independently checks all 84,600 CSV path keys,
variances, KS values, and loadings against the canonical CSV; it also checks
branch assignments, all three denominators, tracker targets, covariance
identities, all 846 ticker/method summaries, and all 240 plotted curve points.
The curve values agree exactly. It verifies source and artifact hashes,
including unchanged canonical training sources and outputs.

Both manuscripts and the JFDS supplement were rebuilt. Build and visual
verification records are in `build-checks/` and `verification.json`.
The original files and hashes are preserved in `before/` and
`before-manifest.json`. The source archive and JFDS submission package remain
for the final release step after the other review corrections.

## Reproduction

From the repository root:

```sh
julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/15-Variance-Diagnostic.jl
GKSwstype=100 julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/05-Figures.jl --preservation-only
python3 audits/2026-09-14-review/figure4-correction/verify_numerics.py
make -C arxiv-paper pdf
make -C jfds-paper all
```

Replaying the diagnostic needs the canonical fitted caches. Plotting from
the distributed CSVs does not require those caches to be present.

### Author marker preference

After the author requested no star markers, tracker symbols and their legend
were changed to outlined circles. Both captions and manuscripts were rebuilt
and visually checked. Plot data and curves are unchanged. The no-star rule
is recorded in `HOUSE_STYLE.md`; the checks are in `marker-update/`.
