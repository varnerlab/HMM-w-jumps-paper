# Independent math-preserving scope assessment: P1–P26 / F1–F4

Read as a quantitative-finance reader with the preceding manuscript as context. Review only; no manuscript edits, code audit, or research. The requirement is to retain every displayed equation, every algebraic step, substantive inline mathematics, and necessary definitions and assumptions.

## Assessment

This chunk has **20 actual prose paragraphs**, not 26: P1, P3, P11, P19, P22, and P25 are empty heading artifacts. A defensible aggressive allocation is **15 paragraphs**. About 16–17 would read more comfortably. I would not promise a whole-appendix reduction from 58 to 30 based on this chunk: allocating 15 here leaves only 15 for the remaining 38 paragraphs, including the generator derivation. A smaller numerical count achieved by running the existing long derivations together would not be a substantive shortening.

## Proposed 15-paragraph allocation

| New paragraph | Existing material | Treatment |
|---|---|---|
| 1 | P2 | Keep diagnostic equation, independence versus finite-path distinction, correlation sampling scale, and conclusion. Delete histogram narration and repeated empirical summaries if necessary. |
| 2 | P4 + P5 | Reduce P4 to a purpose clause and retain P5's complete wealth/Taylor/log-expansion derivation, including inline expansions and definitions. |
| 3 | P6 | Retain complete expectation derivation, units, mean-dispersion approximation, ergodic qualification, and finite-horizon limitation. Shorten verbal restatements of displayed terms. |
| 4 | P7 | Retain every pair-identity step, nonnegativity equation, and equality condition. Cut the trading intuition and historical narrative to a brief attribution. |
| 5 | P8 | Retain market/residual decomposition, beta-pair algebra, range bound and its numerical substitution, and independent-residual formula. Shorten explanatory repetition. |
| 6 | P9 + P10 | Retain AR(1) example and both variance formulas; join them to a compact account of the positive omitted covariance and the unmeasured real-market gap. |
| 7 | P12 | Compact definitions and test conventions; retain conditional interpretation of pass rates. |
| 8 | P13 | Keep both score formulas and their definitions, units, unusual histogram endpoint convention, and window-length qualification. |
| 9 | P14 + P15 | Combine tail-shape and quantile-envelope definitions. Retain inline moments/kurtosis, Hill ordering and threshold, quantile definitions, both displays, and the VaR/simultaneous-coverage distinction. |
| 10 | P16 + P17 | Define ACF once, retain all three equations and the triangle inequality, and state each score's lag/sample convention compactly. |
| 11 | P18 | Keep uncertainty formulas, resampling unit, and fixed-history/fixed-fit scope; compress repeated procedural wording. |
| 12 | P20 + P21 | Compact comparator setup and branch-dependent score interpretation. Preserve admissibility conditions and unique branch-target mathematics. |
| 13 | P23 | Retain GRU loss and symbol definitions; shorten narrative around architecture/training settings and remove epoch-by-epoch commentary. |
| 14 | P24 | Retain recursive sampling distribution, variance floor, window and initialization rules, no-burn-in convention, and single-fit uncertainty qualification. Cut the long rerun/software-version narrative. |
| 15 | P26 | Compact generator-derivation introduction with parameter definitions. It could be absorbed into the next substantive paragraph only if that next paragraph remains readable. |

This plan is conditional on actual prose compression before merging. P5, P6, and P8 already span many displayed lines; their mathematical length survives intact. They should not be combined with one another. P14+P15 and P16+P17 are the most demanding proposed merges; keep them separate if the resulting prose is still dense. Do not merge P23+P24 merely to reach a count.

## Explanations that must survive

- P2: independent draws imply population cross-covariance zero, not exact zero on every simulated path. Its `1/sqrt(2766)` sampling argument is substantive math, not removable empirical padding.
- P5–P10: long-only normalized weights; daily reset; growth-rate/time units; approximation order; finite moments and stationarity; the small mean-dispersion assumption; stationary ergodic limit versus finite-horizon centering; fixed/unclipped loadings; market/residual uncorrelatedness; and the sign-dependent covariance omission. Preserve the beta range bound and AR(1) sampling-variance example even though they are partly inline.
- P12–P18: pass rates are descriptive conditional comparisons; histogram weights have the reported endpoint defect; Hill is the reciprocal tail index; envelope coverage is not VaR coverage; ensemble/path ACF errors are different statistics; Monte Carlo errors omit fitting and regime uncertainty. These caveats prevent misleading interpretations and can be concise.
- P20–P24: the branch-specific R-squared and variance targets, residual comparators' no-recentering convention, GARCH admissibility filters, frozen training normalization, training-only model selection, generation recursion, and one-network scope.

## Float decisions, separately from paragraph counts

- **F1: remove first.** Its correlation definition and means repeat P2. Preserve P2's formula and sampling-noise derivation. The histogram does not carry a unique mathematical argument.
- **F2: remove.** The conditional jump-path diagnostic is secondary to the full-path evaluations already described. If any numbers are cited elsewhere, repair the references. Retaining the figure instead requires its selected-path conditioning to remain explicit.
- **F3: optional removal.** It documents familiar SPY stylized facts already motivated in the paper. Before removal, retain/rehome its unique relation `annualized volatility = sigma(G_t) sqrt(Delta t)` and the stated Laplace-MLE definitions, unless an identical formulation is demonstrably present elsewhere. A short retained table may be preferable if it supports the mean-versus-variance comparison in P6.
- **F4: retain provisionally.** A single summary table connecting closed forms to fitted values is useful and can consolidate empirical commentary. The reader file includes its caption but only an input command for its body, so I cannot establish whether its rows contain unique mathematics. Its caption's KS critical-value calculation `1.358 sqrt(2/T) = 0.0365` must survive if the table is later removed.

Two float removals are well supported in this chunk; a third is conditional. None requires deleting mathematical derivations. No new comprehension-blocking issue emerged in the read; the principal limitation is that preserving the math places a hard floor on page length even when prose paragraph count falls.
