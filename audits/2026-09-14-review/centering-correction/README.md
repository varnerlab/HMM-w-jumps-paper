# Issue 2: retain, qualify, and test residual centering

The author chose to retain the zero-sum residual construction on September 14, 2026. The method is unchanged. Both manuscript versions now describe its finite-horizon scope and report an equivalent-centering comparison in Supplementary Table S14.

## What the comparison established

The control paired each native path with that same path after subtracting its residual mean. It held the fitted models, random draws, market path, effective loading, and residual scale fixed. Naive and hybrid already center their residuals, so their paths and scores were reused exactly.

All six methods were compared on the same 393 training assets, with 100 paths of length 2,766 per asset and seed 1234. This common set used available cached GARCH models that passed a finite-simulation preflight. The experiment did not refit or establish the admissibility of those GARCH models. Full available-population summaries also cover all 423 assets for the other five methods. The control generated 250,800 paired paths overall.

| Method | Native KS pass | Centered KS pass | Native AD pass | Centered AD pass | Native median W1 | Centered median W1 |
|---|---:|---:|---:|---:|---:|---:|
| Naive | 7.5% | 7.5% | 3.7% | 3.7% | 0.695 | 0.695 |
| Gaussian SIM | 0.6% | 0.9% | 0.5% | 0.6% | 0.675 | 0.673 |
| Hybrid | 74.4% | 74.4% | 65.1% | 65.1% | 0.246 | 0.246 |
| JumpHMM-on-residuals | 75.8% | 78.4% | 70.4% | 71.4% | 0.230 | 0.226 |
| Block bootstrap | 73.5% | 76.7% | 66.7% | 68.0% | 0.230 | 0.227 |
| GARCH(1,1)-t | 67.4% | 70.0% | 61.4% | 63.0% | 0.267 | 0.262 |

Equivalent centering changed the cross-method comparison: block bootstrap moved above hybrid on KS, and the residual-fit JumpHMM advantage increased. Both also had higher AD pass rates and lower Wasserstein distances than hybrid. Hybrid's improvement over naive composition remained, because those methods already used the same centering. The corrected claim is that reuse improves on naive composition without another generator fit; it is not evidence that hybrid matches the strongest residual-fit comparators under the common mean constraint.

All centered median intercept errors rounded to 0.002 yr^-1. The much larger native errors for uncentered comparators reflected finite-path residual means. For each paired path, translation left sample variance, recovered beta, R-squared, and excess kurtosis unchanged within the checked numerical tolerances. These are conditional simulation summaries for one training history and frozen fits, not independent historical replications or inferential proof of general superiority.

## Scientific qualification

The paper now explicitly states that the residual sum is zero at the requested terminal horizon. Conditional on a fixed market path and effective loading, terminal cumulative log return has no residual uncertainty. Daily and intermediate returns still vary. Clipping can vary the effective loading across paths and therefore introduce terminal variation through the market term, without changing the zero residual sum. Using full-path means and variances also makes the construction depend on the requested horizon.

The manuscript gives the exact terminal identity and explains why observed training SPY, OLS calibration, and unchanged loadings force the composed asset mean to equal its observed training mean. It distinguishes that imposed constraint from independent mean recovery. The abstract, Methods, Results, Discussion, Conclusion, and supplement now bound cumulative-risk interpretations. The Discussion also states that cross-sectional rank reordering cannot restore residual uncertainty because it preserves each residual sum.

The earlier [three-asset diagnostic](../CENTERING_DECISION.md#controlled-diagnostic) remains available as a separate sensitivity check. Its 249-observation experiment used a training prefix, not the 2025 holdout; it is not the source of the six-method results above. No holdout equal-centering comparison or generator redesign is claimed.

## Reproduction and artifacts

Run from the repository root:

```sh
julia --compiled-modules=existing --threads=4 --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/12-Centering-Control.jl
python3 audits/2026-09-14-review/centering-correction/render_table.py
```

The Julia script checks source and input SHA-256 fingerprints before resuming a checkpoint. It loads existing fits and fails if they are missing or incompatible. It does not silently refit or overwrite the original experiment results.

The subsequent [GARCH correction](../garch-correction/README.md) refit and validated the same 393 models with identical coefficients, preserving these results. Its cache now includes acceptance metadata and consequently has a different file hash. The original GARCH cache for this experiment is preserved in [original-models.jld2](../garch-correction/original-models.jld2); use the frozen inputs in an isolated checkout to reproduce this exact checkpoint.

- [Experiment script](../../../code/downstream-evaluation/scripts/12-Centering-Control.jl)
- [Summary CSV](../../../code/downstream-evaluation/results/centering-control/summary.csv), containing common and full available populations
- [Paired paths](../../../code/downstream-evaluation/results/centering-control/paired-paths.csv)
- [Checkpoint and final results](../../../code/downstream-evaluation/results/centering-control/results.jld2)
- [Input/source fingerprints and runtime checks](../../../code/downstream-evaluation/results/centering-control/metadata.toml)
- [GARCH eligibility record](../../../code/downstream-evaluation/results/centering-control/garch-eligibility.csv)
- [Run log](../../../code/downstream-evaluation/results/centering-control/run.log)
- [Table renderer](render_table.py) and [table checks](table-checks.json)

The runtime checked zero control residual means and the invariants for every paired path. It compared the optimized Anderson-Darling scorer with the production scorer on six probes, including ties. The table renderer independently verified that native summaries reproduced the existing training table at reported precision for all seven included metrics. Production composition code changed only in its explanatory docstring.

Both manuscripts and the JFDS supplement compiled, with no undefined references or new overfull boxes. Changed passages, equations, and Table S14 were visually inspected. Four pre-existing JFDS equation/paragraph width warnings remain. [Verification results](verification.json) record the final PDF hashes, data counts, and synchronized-source checks; rendered pages and logs are in [build-checks](build-checks). The arXiv source archive is left for the release step after the remaining corrections.
