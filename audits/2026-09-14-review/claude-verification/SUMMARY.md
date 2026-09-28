# Reconciled Fable 5.1 verification

**Recovered 14 September 2026. Both review rounds completed. The recommendation remains to resolve the release concerns before posting the arXiv replacement.**

This is Codex's reconciliation of [the original audit](../REVIEW.md), [Fable's response](CLAUDE_VERIFICATION.md), and [its correction addendum](CLAUDE_CORRECTIONS.md), not another Fable response. Both raw responses are preserved unchanged. Fable supported the underlying concerns across R1–R11, with qualifications about severity, historical provenance, and numerical verification.

Fable reviewed the supplied source and mathematics with no tools. It did **not** rerun Julia, independently aggregate caches, inspect the PDF, or validate every package implementation. Numerical results remain evidence from the original audit. This was an independent critique, not an independent experimental replication.

**Subsequent author-directed corrections:** ranked issue 1 (R6, Laplace) is implemented and documented in the [Laplace correction report](../laplace-correction/README.md). Ranked issue 2 (R1, centering) is resolved under the author's choice to retain the construction, qualify its scope, and add an equivalent-centering control; the [centering correction report](../centering-correction/README.md) records the experiment and manuscript changes. Ranked issue 3 (R3, GARCH acceptance) is corrected, with the same 393 accepted models recovered exactly; the [GARCH correction report](../garch-correction/README.md) records the new checks and evidence. Ranked issue 4 (R5, short-path VaR thresholds) is corrected under the author’s pooled-threshold choice; the [VaR correction report](../var-correction/README.md) records the changed rates, convergence checks, and remaining inference limits. Ranked issue 5 (R2, canonical training caches) is corrected; the [training correction report](../training-correction/README.md) records a fresh six-method run whose 250,800 path scores exactly reproduce the historical centered results. Table 3 and both supplementary breakdowns are unchanged, and the distributed cache, compact summary, provenance, and table formatter now agree. Ranked issue 6 (R4, Figure 4) is corrected on 15 September 2026; the [Figure 4 correction report](../figure4-correction/README.md) documents actual per-draw generator denominators, exact replay of all 84,600 composed variances, separate tracker targets, corrected reference curves and aggregation, and finite-path error quantiles. The findings and proposed sequence below record the earlier review state. The remaining findings are not marked resolved by these corrections.

Ranked issue 7 (R7, emission and transition fallbacks) is corrected on 15 September 2026 under the author's retained-fit policy. The [fallback correction report](../fallback-correction/README.md) records exact reconstruction of all 424 full-return and 423 residual-fit models, 50 fallback states in 39 full-return models, and a paired sensitivity control with 23,400 scored paths. Both manuscripts now disclose the rules and affected assets in Tables S17/S18. All 7,800 original composed paths reproduce canonical scores exactly; the control measures training sensitivity without replacing the fitted policy or establishing holdout performance.

Ranked issue 8 (R8, metric definitions and GRU reproducibility) is corrected on 15 September 2026. The [metrics and GRU report](../metrics-correction/README.md) records explicit ensemble-curve and mean-path ACF errors, corrected 252/248 single-asset lag limits, quantile-envelope coverage, and the metric-specific conditional simulation errors. Both manuscripts now specify GRU architecture, training, and generation. A complete retraining and regeneration reproduced both original path CSVs byte for byte, including all 3,015,000 values; selected weights, normalization, a 200-epoch log, and a pinned environment are saved. Independent checkpoint loading and rescoring passed, and all 16 Table 2 numerical rows remain unchanged. This is a reproduction of one fitted benchmark and seed, with no claim of robustness across training seeds.

Ranked issue 9 (R9, mean preservation under clipping) is corrected on 15 September 2026 by qualifying the retained-intercept construction. The [clipping correction report](../clipping-correction/README.md) records the exact composed mean, the clipping-induced shift, and the separate effect of changing the supplied market mean. Both manuscripts now describe the implemented stress transformation, which scales deviations around the market mean. All 192 targeted assertions passed, including the original audit's mean-shift example. The 42,300 recorded primary hybrid paths all retained their calibrated loadings, so clipping caused no mean shift in that experiment. Production sources, fitted models, scores, and table values are unchanged. R10 and R11 remain open.

Ranked issue 10 (R10, Kupiec boundary likelihood) is corrected on 15 September 2026.
The [Kupiec report](../kupiec-correction/README.md) records the continuous boundary
likelihood, corrected breach-probability documentation, input validation, and
807 passing assertions. Re-evaluating 1,152,800 saved holdout diagnostic p-values
changes 40,650 zero-breach cases and no 5% decisions at the 249-day horizon.
Zero breaches over 100 days at 99% coverage now gives p = 0.1562584, correcting
the old rejection in that example. The current pooled Table 5 does not use this
helper and regenerates byte for byte unchanged. Original run provenance and
historical caches are preserved, with the precise source correction and derived
legacy summaries recorded separately. Manuscript PDFs remain unchanged. R11
remains open; earlier status statements above describe their correction dates.

Ranked issue 11 (R11, synthetic-tracker scope) is resolved on 15 September 2026
by restricting the claim to the Gaussian branch check actually performed.
The [tracker report](../tracker-correction/README.md) records exact replay of
all 1,500 historical grid rows and 15 summaries. Both manuscripts disclose
the direct Gaussian residual input, unit residual scale, shared observed SPY
path, and different centering of the reference and composed residuals. Table S6
retains its numerical results and labels KS pass rates as nominal, with no
claim of calibrated inference or full fitted-pipeline validation over the grid.
All 492 assertions passed, including separate non-unit scaling and finite-path
recovery checks. Production composition and scoring code are unchanged;
script 08's executable syntax is unchanged after correcting its comments.
All three PDFs were rebuilt and visually checked. All eleven ranked findings
are now resolved; additional audit follow-ups and release verification remain.
The findings below preserve the historical review rather than the current status.

## Findings after reconciliation

These are Fable's corrected priorities: P1 means resolve before release, P2 means a substantive correction, and P3 means a lower-priority fix. Priorities are reviewer judgments.

| ID | Supported conclusion | Corrected priority and limits |
|---|---|---|
| R1 | Realized-path centering forces residual sums to zero and affects comparison with methods retaining random sample means. | P1 for scope, disclosure, and comparability. An intentional construction, not automatically a coding defect. Terminal collapse conditional on a market path requires fixed loadings; clipping can change loadings between paths. |
| R2 | Distributed training caches disagree with Table 3 for naive and hybrid composition. | P1 for reproducibility. Does not prove the manuscript numbers false or authenticate the historical cache provenance. |
| R3 | Fresh GARCH fitting can cache models that fail simulation. | P1 as a reproduction blocker; P2 scientifically. Historical published results remain unauthenticated. |
| R4 | Figure code uses observed variance where labels specify generator variance. | Downgraded from P1 to P2 high. Direction and magnitude of the effect on the distributed figure remain unverified by Fable. Correct the exhibit before release. |
| R5 | Each VaR threshold uses one 249-observation synthetic path, mixing generator behavior with threshold-estimation error. | P1 for interpretation and evaluation design. No universal corrected null or corrected method ranking was established. |
| R6 | The Laplace benchmark uses mean-based location although the manuscript specifies median-based maximum likelihood. | P1. Correct and rerun; the large KS change is an original-audit probe result, not a Fable rerun. |
| R7 | Emission fallback behavior is incompletely documented. | P2. Fable confirmed supplied code, not the count of 39 affected fits out of 424 or omitted transition handling. |
| R8 | ACF scores differ in their order of averaging and absolute value, and documentation is incomplete. | P2. Define estimands, lag limits, and uncertainty separately. |
| R9 | Clipping beta without adjusting alpha can change the calibrated mean. | P2. Qualify the general claim; the described primary run was unclipped. |
| R10 | Kupiec boundary p-values use an incorrect heuristic. | Downgraded from P2 to P3. Zero breaches at the paper's 249-day, 99% setting gives a corrected p-value near 0.0253; both versions reject at 5%. Other horizons can change the decision. |
| R11 | The tracker test uses a restricted Gaussian residual construction with unit scaling and bypasses full-return fitting. | P2. Limited validation and potentially miscalibrated KS tests do not establish mathematical degeneracy. |

Five findings retain a P1 role, including R3 as a reproduction blocker. R4 is the only original P1 downgraded outright; R10 was originally P2. This qualifies Fable's initial opening statement about two over-classified P1 findings.

## Corrections that matter

Fable accepted all six follow-up criticisms, five in full and one in substance:

- The claimed VaR ranking reversal was arithmetically false: relative to the illustrative 1.392% uniform benchmark, naive's 1.21% is 0.182 percentage points away and hybrid's 1.67% is 0.278 points away.
- The iid probe rates around 1.37–1.39% are not a universal null for dependent, centered, scaled generators. They cannot be subtracted from reported rates. A shared procedure does not guarantee equal bias across methods.
- A fresh GARCH reproduction failure does not establish that historical published results were unaffected. Check exclusions and regenerated rows from the same run.
- The Figure 4 mismatch has no established universal direction or magnitude from the supplied comparisons.
- Exact matching to observed training means applies to naive and unclipped hybrid/tracker paths; clipping needs a separate qualification.
- Gaussian residual draws remain random; zero KS rejections alone do not prove degeneracy.

Two qualifications remain in the addendum. First, `3.48/250` is exact for the **uniform** type-7 example, not arbitrary iid continuous distributions; the original normal and Student-t probe results already differ. Second, the tracker reference uses an uncentered Gaussian residual while `compose_hybrid` centers its draw. Unit scaling therefore does not make their finite-path distributions identical, as the addendum claims. Shared market observations and different residual constraints require checking KS calibration; conservatism was not independently demonstrated here. These qualifications follow from the existing probe log, `scripts/08-Synthetic-Tracker-Eval.jl`, and `src/Composers.jl` and do not change the supported R5/R11 concerns.

## Proposed sequence at recovery

1. Resolve R1's scientific scope: retain constrained finite-horizon generation with clear limits and an equivalent-centering comparison, or revise centering/scaling and rerun affected results.
2. Fix GARCH admissibility and the Laplace estimator, then regenerate canonical results with source/configuration fingerprints and check manuscript agreement. Record GARCH eligibility from that actual run.
3. Choose the VaR estimand. For generator-tail evaluation, use a sufficiently large independent simulation ensemble and check threshold convergence. For a 249-observation estimator, calibrate that procedure explicitly, including dependence. Reassess all compared methods before revising interpretation.
4. Correct Figure 4 and remaining method, metric, fallback, clipping, and tracker descriptions. Synchronize arXiv and JFDS artifacts when implementing the agreed changes.

Recovery verified successful completion records, exact saved-response matches, the approved packet hash, all 48 source fingerprints, and all five original snapshot hashes. The recovery step itself needed no new model request or experiment rerun and made no manuscript or production changes. Subsequent changes are linked above.
