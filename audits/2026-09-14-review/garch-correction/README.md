# Issue 3: validate GARCH fits before caching and evaluation

Status: the acceptance rule is corrected and all 423 residual series were refit. The corrected run retained the same 393 training assets and excluded the same 30 nonstationary fits. All 423 optimizations reported convergence. Every accepted model reproduced the previous cache's coefficients and training residual data exactly. Paired simulations at 2,766 and 249 observations also matched exactly for all 393 models. The correction therefore requires no change to the GARCH performance values; it repairs fresh reproduction and makes the eligibility evidence explicit.

## Cause and correction

`01c-Fit-GARCH.jl` previously stored every model returned by `ARCHModels.fit`. The package could return a nonstationary fitted model, and the first evaluation-time simulation would then throw `Model is nonstationary.` The comment described excluding these fits, but the implementation no longer made that check. Existing cached models had already omitted the failing assets and concealed the fresh-run failure.

The corrected fitting path requires:

- Optimizer convergence and a finite likelihood.
- Finite coefficients, positive variance intercept, and nonnegative ARCH and GARCH coefficients.
- ARCH plus GARCH persistence strictly below one.
- Finite Student-t degrees of freedom greater than two.
- Finite positive unconditional variance and a finite, nonconstant trial path.

The pinned ARCHModels 2.7.0 public fitter discards the optimizer result. The small adapter in `src/GARCHFit.jl` uses its likelihood, starting values, default BFGS solver, and forward differentiation while retaining the Optim result. A regression test checks exact coefficient agreement with the public fitter. The correction does not constrain or retune the likelihood, clip fitted coefficients, or retry rejected models with a different scientific specification.

The model cache now contains all per-ticker acceptance records and input/source fingerprints. CSV diagnostics include rejected fits as well as accepted fits; the exclusion CSV is always rewritten, even when empty. A temporary serialized cache is validated before replacing the previous cache. Reuse requires matching provenance. Both production evaluators validate cache acceptance records and trial paths before evaluation, using a private random generator that leaves the scoring stream unchanged. Legacy or inconsistent caches receive a clear rebuild error.

## Effect on the paper

The accepted set remains 393 training assets, of which 386 have complete holdout histories. At 100 replications, GARCH contributes 39,300 training and 38,600 holdout paths. The other five methods cover 423 training and 416 holdout assets. Table 3 and the Methods now state the training denominator explicitly. Supplementary Table S14 already compares all six methods on the common 393-asset set; its numbers remain unchanged. Its description now records the confirmed eligibility and exact coefficient agreement. Both arXiv and JFDS received the same scientific changes.

These checks authenticate the fitted GARCH models and their unchanged simulation behavior. They do not resolve the separate canonical training-result cache inconsistency or the VaR estimator issue. Those remain later items in the agreed correction sequence.

## Validation and reproduction

From the repository root:

```sh
julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/test/garch_fit.jl
julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/01c-Fit-GARCH.jl --refit
julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/01c-Fit-GARCH.jl
julia --compiled-modules=existing --project=code/downstream-evaluation \
  audits/2026-09-14-review/garch-correction/verify_pipeline.jl
```

Use `--output-dir PATH` on the fitter to retain the canonical cache while writing an isolated run. The validation script uses the preserved original model cache for the before/after comparison. It runs two replications through each production evaluator to check integration and coverage; those smoke results are not substituted for the manuscript's 100-replication summaries.

Artifacts:

- [Corrected fitting script](../../../code/downstream-evaluation/scripts/01c-Fit-GARCH.jl), [acceptance helpers](../../../code/downstream-evaluation/src/GARCHFit.jl), and [regression tests](../../../code/downstream-evaluation/test/garch_fit.jl).
- [Full fit diagnostics](../../../code/downstream-evaluation/data/garch-t-diagnostics.csv), [exclusions](../../../code/downstream-evaluation/data/garch-t-skipped.csv), and [provenance](../../../code/downstream-evaluation/data/garch-t-metadata.toml).
- [Original cache](original-models.jld2) and [original exclusions](original-skipped.csv), preserved before replacement.
- [Initial convergence probe](convergence_probe.jl), [probe results](convergence-probe.csv), and [probe log](convergence-probe.log).
- [Refit log](refit.log), [cache reuse log](cache-reuse.log), [GARCH test log](tests.log), and [existing composer test log](composer-tests.log).
- [Pipeline verification](verify_pipeline.jl), [pipeline log](pipeline.log), and [pipeline checks](pipeline-checks.toml).
- [PDF build and visual checks](build-checks).

All 23 GARCH regression tests and 24 existing composer tests passed. The two
production evaluator checks completed 786 training and 772 holdout paths with
finite scores. Both manuscript versions and the supplement built with no
undefined references or new overfull boxes; the changed passages and tables
were visually checked. [Final verification](verification.json) records the
source/input checks, PDF hashes, and validation results. The four pre-existing
JFDS equation/paragraph width warnings remain unchanged.

The model archive has a new file hash because it now includes diagnostics and provenance. Its accepted model coefficients are unchanged. The earlier centering experiment's original GARCH file is preserved as `original-models.jld2`; its historical checkpoint intentionally refuses a different file fingerprint. Reproducing that exact checkpoint requires the frozen inputs in an isolated checkout. This does not change the centering-control results or their interpretation.
