# Appendix scope cold read: reader 3

Perspective: quantitative-finance researcher; standard probability, HMM, regression, and statistics knowledge assumed. Review only. Source: reader_appendix_3.txt; audited P52–P80 and F8–F24. Empty label blocks P52, P54, P56, P63, P68, P70, P73, and P77 are excluded. There are **21 actual prose paragraphs and 17 floats** in this chunk.

## Scope judgment

Yes: a whole-appendix target of at most 30 prose paragraphs is credible. For this chunk, allocate **12 prose paragraphs and four floats**, down from 21 and 17. Do not reach that budget by making twelve giant paragraphs. Remove entire auxiliary experiments and textbook derivation steps; combine complementary results around a single claim. This chunk contains indispensable limitations and fairness controls, but also a substantial diagnostic archive presented as necessary exposition.

The appendix's necessary job here is to establish what the correction actually preserves, what it necessarily destroys, whether the empirical comparison is fair, and whether the main numerical findings are Monte Carlo artifacts. Repeated explanations of routine identities, exhaustive reconstruction checks, and several plots establishing that there are exactly two trackers do not help that job.

Required support: branch conditions and finite-path covariance qualification; consequences of clipping for means and loadings; terminal residual degeneracy and horizon dependence; the limitation of reusing total-return shape as residual shape; direct evidence for retained heavy tails; the jump training/holdout reversal with simulation uncertainty; equal-centering comparator control; pooled-VaR construction and numerical stability; the differential effect of fallback rules on full-return versus residual-fit models.

Optional detail: three additional hand-picked single-stock demonstrations, Gaussian identity verification, fourth-moment expansion and its numerical verification, all per-ticker fallback records, coefficient fingerprints and cache equivalence checks, and full tables of robustness results whose substantive conclusions fit in a sentence. Retain these in reproducibility artifacts if already available; the paper need not narrate the archive.

## Paragraph decisions

| ID | Decision | Editorial reason | Minimum that must survive / support lost by removal |
|---|---|---|---|
| P53 | COMPRESS | A sensitivity check supports the chosen resolution, but the full sweep is secondary to generator reuse. | One short paragraph: SPY-only N sweep; fixed five-state tails plus retuning confounds state resolution with extremity/parameters; HMM-NJ little changed; HMM-WJ ACF/AD tradeoff; N=100 is a practical choice, not a demonstrated optimum for 423 assets. Preserve two endpoint numbers if needed; omit the recital of all metrics. |
| P55 | CUT | Three selected stocks are weak evidence for generalization when the paper already evaluates hundreds of assets. Its tuning reproducibility digression adds another research question. | Removing it loses support only for the specifically reported NVDA/JNJ/JPM experiment, not the main multi-asset claim. Remove or relocate the dependent main-text sentence and F9. The broader warning about uneven holdout fit already has stronger universe-wide support. Archive seed and tuning outputs. |
| P57 | COMPRESS | The scale derivation is core, but dropping a constant and expanding variance line by line is textbook material. | Keep the exact variance identity including 2 beta s Cov, the zero-covariance approximation, and the solved scale with its feasibility condition. Explicitly distinguish sample identities from approximation. Merge P58 into the same compact derivation paragraph. |
| P58 | MERGE | The alternative target belongs next to the scale; three branch-assignment floats are unnecessary. | Keep residual target beta² sigma_m²(1/R²−1), threshold 0.80, and QQQ/SPYG versus 421 assets. These facts can be one sentence following the equation. |
| P59 | CUT | The grid supplies Gaussian residuals already at the target variance, giving unit scale; it does not evaluate reuse, learned marginals, or temporal fit. It checks a standard identity and routing. | Main correction results lose no support. Remove F13 and any claim that this grid validates full-return tracker reuse. The real two-tracker results and explicit limited coverage survive in the branch paragraph. |
| P60 | COMPRESS | Mean retention versus intercept retention matters; twelve sentences over-explain two elementary identities. | Keep mean = alpha + beta_eff times market mean; exact observed mean only with observed training market and unchanged loading; clipping changes means. One stress-test sentence can report 0%, 76.4%, 95.2% clipping at volatility multipliers 1,2,3. Merge P61. |
| P61 | MERGE | Finite-path OLS and variance qualifications belong in the same preservation paragraph as P60. | Retain final slope/intercept identities with residual-market covariance, branch-specific variance targets, and the fact that a variance floor does not guarantee tail preservation. Drop intermediate covariance steps and asymptotic discussion unless needed for a retained claim. |
| P62 | KEEP | This is a material mathematical limitation of the proposed construction, not optional diagnostics. | Exact zero-sum/terminal cumulative-return identity; zero terminal residual uncertainty conditional on market/loading; earlier partial sums may vary; horizon extension changes centering/scaling. Clipping can change loading, not restore residual terminal uncertainty. Do not bury this inside a caption or archive. |
| P64 | MERGE | Its important distinction is already introduced in the main argument; it needs a sharp limitation statement, not another subsection introduction. | State that independent simulated full returns retain total-return shape, which need not equal the OLS-residual distribution. Merge with P65 as the first of two shape paragraphs. |
| P65 | MERGE | The three-part residual tutorial repeats mean and variance derivations just given. | Retain the additional holdout qualification: fixed training market variance leaves another variance discrepancy when the simulated market variance changes. Retain lack of residual-shape validation; drop the pedagogical numbered requirements and repeats of exact centering. |
| P66 | COMPRESS | The final kurtosis relation is useful; a full fourth-moment expansion, special zero-loading explanation, numerical identity check, and quartile-results recap are too much. | Second shape paragraph: independent components, finite fourth moments, fixed coefficients/population or long-path approximation; kappa = kappa_m rho² + kappa_gen(1−rho)²; composition changes tails despite affine preservation within a component. Keep one empirical limitation/figure reference. Avoid treating beta quartiles as variance-share identification. |
| P67 | CUT | Most of this is a recap of reuse versus residual fitting, mean preservation, covariance, and kurtosis already covered. | Move only the final branch qualification into P66: use actual market share of composed variance on clipped/R² branches. If synthetic-price compounding is needed to reproduce the residual comparator, place that single implementation fact with comparator methods. No distinct scientific claim otherwise loses support. |
| P69 | COMPRESS | Main methods already explain most of the pairing and Monte Carlo design. The appendix needs uncertainty evidence and the rare-episode caveat. | One paragraph: replication-level cross-asset averaging preserves shared-market dependence; 1,000 replications; unchanged components share draws, enabled/disabled models do not share innovations; intervals condition on fitted models/history. Keep 247/1000 versus 22/1000 market episodes and the training/holdout reversal. Breadth percentages optional. Retain F18. |
| P71 | COMPRESS | This is a necessary fairness control, but one formula and a clear paired design suffice. | Retain residual-mean subtraction, frozen same draws/scales and sample, naive/hybrid unchanged, and limitation that centering cannot restore terminal uncertainty. Merge essential P72 design/results. |
| P72 | MERGE | Exact refit reproduction, fingerprints, cache matches, and full-population bookkeeping are audit-log content. | State common 393-asset set, 100 paired paths each; other 30 GARCH fits fail stationarity acceptance (can cross-reference comparator methods); equal centering favors residual-fit comparators and removes apparent intercept advantage. Preserve aggregation definition in F20. Archive reconstruction narrative. |
| P74 | COMPRESS | VaR pooling is central, but main methods already contain most of this protocol. | One reproducibility paragraph: 5,000 separately centered/scaled 249-day paths, shared market per replication, linear empirical quantiles, frozen training parameters/market variance, no jumps and GARCH warmup. The estimand is a uniformly selected day of this horizon-constrained construction, not cumulative risk. Avoid re-explaining this limitation in every following paragraph. |
| P75 | COMPRESS | Numerical stability is necessary for the tail result; exhaustive pool grid and method-by-method table are not. | One robustness paragraph merged with P76: 2,500→5,000 pool change <0.006 pp in mean exceedance; threshold median/P95 changes or worst-case 3.95% to avoid hiding asset heterogeneity; independent 1,000-path validation near nominal. Explicitly these are Monte Carlo checks, not real-market coverage evidence. |
| P76 | MERGE | Eligibility control is useful but not a separate subsection-sized result/table. | Append common 386-asset comparison: hybrid/residual-fit/naive 99% rates 1.08/1.14/0.85%; no precise ranking or equivalence across one shared market period. No need to repeat all six methods and SD columns in F22. |
| P78 | COMPRESS | The fallback mechanism is essential reproducibility and a comparison confound; an exact reconstruction inventory is not. | One paragraph: rule/threshold once (cross-reference main methods instead of duplicating cases if retained there), 39 affected full-return assets/50 states, mainly populated repeated-return states, fallback mass range, none in SPY or residual-fit models. Sparse fallback mass is tiny. Archive ticker list and exact cache-match checks. |
| P79 | MERGE | The intervention design must accompany its result, but cache equality is process detail. | Combine with P80: 39 fixed assets, paired 100-path replay, only constant-state scales changed, generator variance recomputed for composition; state sequences/draws otherwise fixed. Sparse rules unchanged. |
| P80 | COMPRESS | The sensitivity materially qualifies the comparator result; avoid reciting the entire retained table. | Combined paragraph with P79: hybrid KS +10.28 pp and AD +14.08 pp on affected assets; variance also changes; original rule retained; training-only diagnostic, no sparse-state or holdout validation. Keep uncertainty in F24. Explain scope as subset effect, not a universe-wide gain of that size. |

## Caption / float decisions

Decisions concern the float as well as its caption. Cutting a caption while retaining its full graphic/table would not deliver the requested scope reduction.

| ID | Decision | Why / minimum surviving evidence / claim at risk |
|---|---|---|
| F8 | CUT | Replace the 12-row N sweep with P53's short quantitative summary and archive the full results. N=100 rationale survives; exhaustive sensitivity values are not a main claim. If a formal claim of optimal N is retained, this experiment does not establish it anyway. |
| F9 | CUT | Remove with P55. No main reuse claim loses support; only the explicitly reported three-stock jump-calibration claim must be removed or relocated. |
| F10 | CUT | A histogram is unnecessary to establish that only QQQ and SPYG exceed 0.80. Keep names/count/threshold in P58. No support loss. |
| F11 | CUT | Duplicates branch membership already in F10/F12 and text. Preserve 421/2 assignment and no clipping in training as prose; beta–R² geometry is optional. |
| F12 | CUT | Two branch rows do not require a standalone table. Put tracker beta/R² errors 0.005/0.001 and no-clipping fact into the compact branch paragraph if those empirical claims remain. Other columns duplicate aggregate results. |
| F13 | CUT | The restricted Gaussian/unit-scale grid is a routine identity/routing check, not reuse validation. Archive it; no core support loss. |
| F14 | CUT | Three clipping percentages fit one sentence. Preserve the mean-preserving market-volatility transformation and rates in P60; otherwise the empirical clipping-frequency claim would lose its evidence. No need for an independent float. |
| F15 | CUT | A 24-row table revisits nearly every metric for all methods. Retain hybrid KS endpoint quartile values and their descriptive status in text if the main claim still cites them; archive the full table. Heavy-tail evidence remains in F16. Do not claim the beta split proves a rho mechanism. |
| F16 | KEEP | Direct empirical support for the central retained-heavy-tail claim is worth one float. Tighten the caption to per-ticker medians, 100 draws, real-data reference, Hill convention and top 5% threshold, axis clipping, and limitation that naive/hybrid similarity does not isolate scaling. Both tail heaviness and the shortfall from observed kurtosis must remain visible. |
| F17 | CUT | Numerical verification of an elementary independent-sum kurtosis identity is unnecessary once the short relation and assumptions are stated. Remove the precise within-0.03 simulation claim; no empirical financial claim loses support. |
| F18 | KEEP | Compact evidence that the training improvement/holdout worsening exceeds simulation noise is directly relevant to a main result. Preserve paired contrasts, 1,000 replication unit, ACF estimand, and conditional-Monte-Carlo scope of intervals. |
| F19 | CUT | Episode incidence and broad sign pattern can be one or two P69 sentences. Preserve rare holdout incidence; archive the full breadth diagnostic. No support loss to the primary average jump contrast if F18 remains. |
| F20 | KEEP | This table directly changes interpretation of the six-method comparison. Keep same-assets paired design, native/centered contrast, metrics/units, and descriptive pass-rate qualification. The six methods matter here. Caption should not equate non-rejection with demonstrated distributional truth. |
| F21 | CUT | The simulation rates are nearly identical, and the numerical stability ranges fit prose. Preserve both independent validation and convergence evidence in P75; archive per-method results. Otherwise the pooled-threshold precision claim would lose support. |
| F22 | CUT | This repeats the primary VaR table on a common subset. Keep common-set count and key 99% rates in P76/P75, with descriptive/no-equivalence qualification. Full SD columns are optional. |
| F23 | CUT | A 39-ticker inventory is a reproducibility artifact. Preserve aggregate counts, mass range and variance-change range in P78/P80, plus fallback definition. No main claim depends on naming all 39 tickers. |
| F24 | COMPRESS | Retain as the fourth float because differential fallback treatment materially affects comparator fairness. Reduce to hybrid marginal-fit outcomes and an uncomposed variance summary; archive naive/uncomposed ACF and other secondary rows. Preserve 39 assets ×100 paired replications, unchanged sparse fallback, treatment definition, and that SE describes simulation uncertainty on fixed assets. |

## Concrete budget

1. State-resolution sensitivity (P53): 1 paragraph.
2. Variance and R² branch derivation (P57–58): 1.
3. Mean, finite-path OLS, branch qualifications and clipping (P60–61): 1.
4. Terminal residual constraint (P62): 1.
5. Residual-shape limitation and variance convention (P64–65): 1.
6. Kurtosis relation and empirical tail interpretation (P66 plus last P67 qualification): 1.
7. Jump uncertainty (P69): 1.
8. Equal-centering control (P71–72): 1.
9. Pooled VaR protocol (P74): 1.
10. VaR numerical and eligibility controls (P75–76): 1.
11. Fallback prevalence (P78): 1.
12. Fallback intervention and material effect (P79–80): 1.

Total: **12 prose paragraphs**; P55, P59, and most of P67 disappear. Retain **F16, F18, F20, and a reduced F24**. No added float is needed. If another appendix chunk already contains all N-choice support, P53 can merge there, taking this allocation to 11. I would not cut the terminal-constraint paragraph, common-centering table, or fallback sensitivity to preserve secondary single-asset demonstrations.

## PURPOSE friction log

Each line uses ID | TYPE | severity | quote (at most 15 words) | issue | likely intended purpose.

P55.S1 | PURPOSE | 2 | “To test generalization beyond SPY” | Three selected stocks create a second generalization story after the universe-wide experiment already carries that burden. | Illustrate single-asset transfer; optional corroboration.

P57.S8 | PURPOSE | 1 | “where alpha_i drops out because it is constant” | Elementary algebra lengthens the core derivation without resolving a research uncertainty. | Make variance correction accessible to beginners.

F10–F12 | PURPOSE | 2 | “only QQQ and SPYG exceed the threshold” | Three floats establish essentially the same two-asset assignment. | Document routing and limited tracker coverage.

P59.S9 | PURPOSE | 3 | “without evaluating full-return reuse or temporal fit” | The paragraph itself disclaims the central questions; a long grid initially looks like validation then turns out to test unit scaling and routing. | Implementation sanity check.

P60.S5 | PURPOSE | 1 | “Clipping shrinks the magnitude of the loading” | Sign-case narration adds length after the mean-shift identity already answers the question. | Warn that retaining an intercept does not preserve means.

P65.S1 | PURPOSE | 2 | “The residual slot must supply three things” | Reopens a tutorial on mean and variance immediately after those properties were derived. | Frame the residual-shape limitation.

P66.S8 | PURPOSE | 2 | “every cross term in the fourth moment factors” | A standard independent-sum calculation takes center stage while the important result is the changed tail contribution. | Justify the kurtosis relation.

F17.S1 | PURPOSE | 2 | “Simulation check of the kurtosis composition rule” | A new table numerically checks standard algebra, increasing apparent evidentiary breadth without addressing empirical adequacy. | Verify implementation of the formula.

P67.S4 | PURPOSE | 1 | “reuses the generator's centered shape” | Recaps the main premise and several properties yet again. | Summarize reuse versus residual fitting.

P69.S7 | PURPOSE | 1 | “divided by sqrt(1,000)” | The elementary SE formula is less important than identifying shared-market replications as the uncertainty unit. | Explain Monte Carlo intervals.

P72.S4 | PURPOSE | 2 | “Acceptance records, coefficient fingerprints, and exclusion reasons accompany the fitted-model cache” | Audit provenance competes with the actual fairness-control finding. | Demonstrate reproducibility and identical models.

F21–F22 | PURPOSE | 2 | “Threshold convergence and independent simulation checks” | Two separate robustness tables extend a VaR subsection whose primary result is already in the main paper. | Rule out numerical instability and eligibility confounding.

F23.S1 | PURPOSE | 2 | “Each listed asset had one populated constant-return state” | An exhaustive ticker inventory makes a material but compact limitation look like an independent major result. | Provide auditability of fallback prevalence.

P79.S8 | PURPOSE | 1 | “matched the canonical cache exactly” | Reproduction verification is useful in the archive but does not explain the sensitivity result. | Establish paired-run fidelity.

TOTALS: severity 3 stopped = 1; severity 2 slowed = 8; severity 1 minor = 5; total friction entries = 14.

No manuscript edits, external research, or implementation audit were performed. These recommendations judge scientific purpose and evidence allocation rather than technical correctness of the code.
