# Appendix scope review: preserve the mathematics

## Recommendation

The appendix can be substantially shorter, but **30 prose paragraphs is too aggressive as a readability target if every equation and derivation stays**. The initial 29–30-paragraph budgets depended on deleting mathematical derivations; the user's subsequent instruction, “don't cut math,” supersedes those recommendations. Do not implement those earlier mathematical cuts.

The current appendix has 58 substantive prose paragraphs, about 12,000 guard-counted prose words, 55 displayed equation/align blocks, and 24 figures/tables (6 figures and 18 tables). Its current PDF span is pages 27–59. The paragraph parser also reports 22 empty label blocks; these are not prose paragraphs.

A defensible first revision would aim for **roughly 45 prose paragraphs and 7 figures/tables**, retaining every mathematical step and shortening its surrounding explanation. The fresh math-preserving assessments allocate 15–17 paragraphs to the first chunk, 15–16 to the second, and approximately 14–15 to the third. These are editorial estimates, not verified counts of a rewritten manuscript. A 30-paragraph version could be manufactured by joining passages, but several resulting paragraphs would span multiple derivations and would not solve the reader's experience of excessive length.

The substantial reduction should come from words and displays: cut repeated interpretations, empirical result recitals already present in the main text, diagnostic tours, and cache/replay provenance. Retain definitions, assumptions, approximation limits, and the sentences that connect mathematical steps. A prose-word target can be set during revision; no page or word reduction has yet been demonstrated. Do not compress typography or move the same exposition into a second supplement.

## Protected content

- All 55 displayed equation/align blocks, including intermediate algebraic lines, remain.
- Substantive inline mathematics also remains: Taylor expansions, bounds, AR(1) sampling calculations, estimator arguments, conditional episode arithmetic, and other steps not enclosed in display environments.
- Preserve definitions and domains, units, finite-moment assumptions, the distinction between exact identities and approximations, and initial/horizon conventions.
- Preserve conditional versus unconditional jump behavior, weak identification of the jump probability, and the limitations of the autocorrelation approximation.
- Preserve the terminal zero-residual-sum result, independent-residual covariance limitation, shape-versus-variance distinction, and the consequences of clipping for means and loadings.
- Preserve the controls that qualify the comparison with residual fitting: equal centering and emission fallback sensitivity. Preserve the training/holdout reversal and conditional Monte Carlo uncertainty in the jump comparison.

“Preserve math” does not require retaining every empirical table or chart. Before removing a float, carry any unique formula or mathematical definition into its retained explanation, or verify that the identical content is already present there. Numerical result summaries may replace a redundant full table, provided claims and qualifications remain supported.

## Proposed seven retained displays

Numbers below refer to the current PDF; renumbering would occur only during revision.

1. **Table S2: fitted generator quantities.** Keep a bridge between the derivations and their numerical consequences. Remove duplicated prose recitals around it. Preserve mathematical content in any later row reduction.
2. **Table S4: emission and duration comparison.** Keep the controlled Gaussian/Student-t contrast and its holdout qualification. Reduce duplicate scorecard detail if possible; make the unequal HSMM/HMM state counts explicit.
3. **Table S10: fit by market loading.** Condense to the outcomes needed for the exposure-dependent fit result. Retain all methods if comparing their performance; avoid implying that beta quartiles isolate market variance share. This is worth keeping because the Discussion develops this result.
4. **Figure S6: empirical heavy tails after composition.** Keep both evidence of heavy tails and the shortfall from observed kurtosis. Similar naive/hybrid outcomes do not isolate rescaling's effect.
5. **Table S12: uncertainty in jump effects.** Retain training and holdout contrasts. Put the essential episode-incidence counts from Table S13 in adjacent prose or its caption.
6. **Table S14: equal-centering control.** Keep the paired common-asset comparison; it materially changes the interpretation of the primary scorecard.
7. **Table S18: fallback sensitivity.** Keep a compact paired comparison, the variance consequence, and the training-only limitation. Avoid presenting the affected-subset improvement as a universe-wide effect.

This retains more empirical support than the most aggressive first readers proposed: the generator summary, controlled emission comparison, and beta-stratified outcomes each have a distinct role alongside the four strongest controls/diagnostics. Seven is a proposed editorial allocation, not a proven minimum.

## Disposition of all 24 current figures/tables

| Current display | Proposed disposition | What survives |
|---|---|---|
| Figure S1, cross-covariance | Remove | Correlation formula, sampling calculation, near-zero averages, and nonzero finite-path cross-term qualification in prose. |
| Figure S2, statistical validation | Remove | Main-text model evidence; any unique jump-active conditioning and incidence needed by retained claims. |
| Table S1, SPY descriptive statistics | Remove standalone table | Needed observed moments, raw-return dependence qualification, growth-rate units and volatility conversion; retain the mean/variance comparison used by the portfolio derivation. |
| Table S2, generator quantities | Keep | Numerical interpretation of the mathematical results. |
| Table S3, ACF prediction | Remove standalone table | Full overlap/ACF derivation; one representative numerical comparison if the agreement claim stays, with conditional sample and omitted free-phase component identified. |
| Figure S3, model internals | Remove | State versus tail-region persistence distinction, dwell formula, direct ACF evidence, and no-fallback qualification. |
| Table S4, emissions/HSMM | Keep, condense | Controlled emission comparison, comparator conventions, state-count confounding, holdout qualification. |
| Table S5, state sensitivity | Replace with concise numerical summary | SPY-only scope, fixed-tail-count/retuning confounding, practical rather than universally optimal choice of N. |
| Table S6, three selected stocks | Remove | Remove the dependent three-stock result claims; broad-universe composition evidence remains. Any unique calibration limitation needed by the mathematics remains in the tuning discussion. |
| Figure S4, R-squared histogram | Remove | Threshold, two tracker names, and 421/2 branch membership in prose. |
| Figure S5, branch map | Remove | Same membership facts and beta range used in the mathematical bound. |
| Table S7, observed branches | Replace with concise numerical summary | Actual two-tracker scope, branch targets, recovery errors if claimed, and no training clipping. |
| Table S8, Gaussian tracker grid | Remove standalone table and numerical recital | Preserve branch mathematics and the Gaussian test construction, including its parameter grid. Shorten the empirical grid-validation claim; it does not test fitted full-return reuse. |
| Table S9, clipping stress | Replace with concise numerical summary | Mean-preserving stress transformation, clipping frequencies, mean/loading implications, and lack of shape validation. |
| Table S10, beta quartiles | Keep, condense | Exposure-dependent marginal fit without a causal variance-share interpretation. |
| Figure S6, tails | Keep | Direct empirical tail evidence and observed-versus-synthetic shortfall. |
| Table S11, kurtosis simulation check | Remove standalone table | Full fourth-moment expansion and final kurtosis relation with all assumptions; also retain the standardized independent-sum construction and evaluated shares from the check. Its numerical result can be summarized. |
| Table S12, jump uncertainty | Keep | Replication-level contrasts and conditional simulation intervals. |
| Table S13, episode incidence | Merge essential counts into text/caption of S12 | Rare holdout episodes and differing window lengths. |
| Table S14, centering control | Keep | Fairness control and its interpretation. |
| Table S15, VaR convergence | Replace with concise numerical summary | Convergence and independent simulation check; neither establishes real-market coverage. |
| Table S16, common-asset VaR | Replace with concise numerical summary | Eligibility control and short, shared-market holdout limitation. |
| Table S17, fallback inventory | Remove standalone ticker inventory | Aggregate prevalence, differential impact, stationary fallback-mass formula, state-set/count definitions and variance-change definition; retain existing reproducibility records. |
| Table S18, fallback sensitivity | Keep, condense | Paired intervention, material effect, uncertainty, and restricted validation scope. |

## Prose priorities under the revised constraint

The rebalancing section retains the complete wealth/Taylor argument, second-moment decomposition, pairwise nonnegativity proof, market/residual decomposition, bound, and serial-dependence example. Its repeated interpretations and historical narration can shrink, but these derivations should not be concatenated into two enormous paragraphs.

The generator section retains the joint law, augmented kernel, estimation calculations, stationary weighting, all moment derivations, no-jump dependence, renewal arithmetic, and jump-ACF approximation. Cut repeated descriptions of what each formula says when the displayed annotations already convey it. The overlap and covariance derivations currently share an overloaded paragraph; readability may require a local split even while the appendix becomes shorter overall.

The composition section retains the full scale, mean, regression, terminal-sum, fourth-moment and kurtosis arguments. Delete repeated introductions to residual reuse and repeated restatements of mean/variance preservation. Keep the mathematical limits next to their claims.

Benchmark, validation and robustness prose can shed implementation audit logs, repeated settings, exhaustive numerical recitals, and duplicate motivations. The appendix still needs the conventions required to reproduce retained results and the caveats that change their meaning.

## Dependencies and verification for a subsequent revision

Twenty-two of the 24 current floats are cited in active main-text files. Their removal requires targeted reference repairs and, for discarded auxiliary experiments, narrowing or removing the corresponding claims. The three-stock experiment and restricted Gaussian grid are examples. Preserve the user's existing introduction/results/discussion paragraph limits during these repairs; do not substitute an unrelated main-text rewrite.

Retain existing raw tables, code and cached records in the repository. Removing a display from the paper is not an instruction to delete its source data or to launch new simulations.

Before delivery of an actual shortened appendix, compare every mathematical block and substantive inline derivation against the original, audit references and surviving empirical claims, obtain fresh reads, rebuild normally, and inspect the rendered pages. Paragraph counts alone cannot establish readability or page savings.

## Status

This is a scope assessment, not an implemented rewrite. The appendix source is byte-for-byte identical to the baseline saved for this scope probe. No manuscript rebuild was performed. Initial mathematical-cut recommendations in `r1/` are superseded by the user's clarification and the preservation assessments in `r2/`.
