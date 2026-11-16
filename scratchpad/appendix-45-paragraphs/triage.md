# Revision and verification notes

## Authorized structure

The user approved 45 paragraphs after explicitly requiring preservation of mathematics. The revision combines related prose, drops a duplicate transition-matrix tour, and integrates the repeated residual-method summary into earlier paragraphs. It separates the jump-overlap/covariance and composition-fourth-moment/kurtosis derivations into distinct prose units. `grouping.json` records the original paragraph IDs. The final count excludes empty label blocks: 45 actual paragraphs, not the parser's 66 blocks.

Seven floats remain: fitted generator quantities, emission/HSMM comparison, beta-quartile comparison, tail figure, jump uncertainty, equal-centering control, and fallback sensitivity. Seventeen displays were removed from the manuscript; their source plots, numerical tables, and cached results remain in the repository. Essential results from the removed diagnostics survive in prose. Main-text changes are reference repairs only; its paragraph counts are unchanged. No simulations, numerical recalculations, or parameter changes were performed.

## Mathematical preservation

All 55 `equation`/`align` blocks, including every intermediate line and equation label, are byte-identical to the pre-edit appendix. A separate inline-math comparison found no lost substantive derivation: missing expressions are numerical recitals from discarded diagnostics, repeated components already present in retained displays, or obsolete source comments. In particular, the portfolio bound and AR(1) example, estimator arguments, renewal arithmetic, kernel conventions, finite-path coefficient identities, terminal constraint, and kurtosis derivations remain.

Mathematics unique to removed captions was retained: volatility conversion, tail-state sets, market variance-share definition and threshold, stress transformation, standardized independent-sum check and variance shares, fallback stationary-mass expression and inventory definitions. Table-header symbols for removed empirical grids are no longer needed; their modeled quantities and construction remain in prose. The ordinary invariant checker flags removed tabular blocks and labels as changes, as expected from the authorized float cuts; the separate display-math equality check establishes equation preservation.

The original structure guard reports authorized changes in paragraph structure, heading/caption order and float formatting commands. No font size, spacing, margin, manual page-break, or template changes were made. Word count remains below the original 11,963-word baseline; an intermediate snapshot is not a new word ceiling.

## First final-text read: triage

All 17 reported issues received an in-place repair, without adding paragraphs or removing mathematics.

| Reader flag | Disposition and evidence |
|---|---|
| A P8, exact versus approximate portfolio growth | Qualify invariance as second-order, consistent with the retained Taylor remainder. |
| A P11, Hellinger weights | Identify the sample containing the pooled maximum; only that sample necessarily loses mass. Bin conventions remain unchanged. |
| A P12, quantile-envelope score | State what coverage counts and its dependence on envelope width, without claiming better distributional fit from coverage alone. |
| A P21, volatility referent | Identify the training series explicitly. |
| A F1, exact versus approximate quantities | Caption distinguishes single-episode/finite-horizon approximations from other entries. |
| A P26, ambiguous moments | Name observed return moments. |
| A P27, transition MLE | Specify likelihood conditional on the initial assigned state; the displayed row optimization omits the stationary-start factor. |
| B P34, geometric bound | State ergodicity and diagonalizability as conditions for the stated bound; retain the direct fitted-chain ACF calculation. No displayed math changed. |
| B P37, approximate initialization | Distinguish state-marginal mixture weight from an error bound on the full state/counter initialization. |
| B P40, forced draws | State that states are drawn from `u`, then emissions from their state laws. |
| B P41, unspecified mixture sweep | Restore its 4,000-path construction, zero-to-one weight range and direction of the two fit effects from the original appendix. |
| B P43, HSMM shift | State the one-step addition to the fitted count mean. Verified negative-binomial fitting at `code/baseline-comparison/Semi-Markov-Baseline.jl:267`; no simulation change. |
| B P51, clipping denominator | Correct prose to composed paths across assets. Verified row-level aggregation in `code/downstream-evaluation/scripts/03b-Stress-Eval.jl:114` and `09-Extra-Figures.jl:125`. |
| B P57, kurtosis population/sample change | Define the symbols as population kurtoses in the fixed-coefficient approximation; retain the finite-path numerical check as a check. |
| B P57, loading/share distinction | Refer to small market variance share, not low loading. |
| B F3, aggregation and eligibility | Caption states pooled pass rates, other metrics' path medians, and GARCH eligibility. Verified `code/downstream-evaluation/scripts/04-Tables.jl:166`. |
| B P65, unused inventory notation | Identify the per-asset inventory in the retained replication files, preserving its mathematical definitions. |

## Rendering and checks

The first shortened PDF compiled to 49 pages, with the appendix on pages 27–49 (23 pages, previously 33). All 23 appendix pages were visually inspected. Existing forced page breaks and `[H]` placement leave some whitespace; they were preserved rather than changing the template to claim additional savings. Mathematical displays and table contents remain within the page boundaries. Final rendering is rechecked after reader repairs.

The source reference audit expands active `input` files, including table bodies, and finds no unresolved labels. Introduction, Results, Discussion and Conclusion retain 3, 12, 5 and 1 paragraphs respectively. Retained table bodies and figure files are unchanged.
