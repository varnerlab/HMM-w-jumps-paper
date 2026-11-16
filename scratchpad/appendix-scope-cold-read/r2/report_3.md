# Independent math-preserving scope assessment: P52–P80 / F8–F24

Review only, as a quantitative-finance reader. I read the supplied manuscript reader file; I did not inspect code, research sources, change the manuscript, or rebuild it. The governing constraint is **no deletion of displayed equations, algebraic steps, derivations, substantive inline mathematics, or definitions/assumptions required to interpret them**. Paragraph and float cuts must come from redundant explanation and optional empirical detail.

## Judgment

This block contains **21 actual prose paragraphs**; P52, P54, P56, P63, P68, P70, P73 and P77 are empty heading artifacts. A readable target is **15 paragraphs**, with **14** a plausible aggressive minimum if the two short opening empirical sensitivity summaries share a paragraph and heading. I would not promise a smaller allocation while retaining the derivations and necessary experiment definitions. The present P66 is already too dense: compression should give its fourth-moment expansion and kurtosis reduction two short prose units, not pack more material around them.

Consequently, a 30-paragraph whole appendix is not established by this block. It leaves 15–16 paragraphs for the preceding 37 actual paragraphs. That must be justified by the other readers' math-preserving inventories. Cutting this mostly empirical block alone cannot supply the requested reduction of 28 paragraphs.

## Proposed paragraph allocation

| New paragraphs | Existing material | Compression while protecting mathematics |
|---|---|---|
| 1 | P53 | Retain the state grid, fixed tail-set size, retuning protocol, combined-effect caveat and SPY-only scope. Remove recital of table entries and the extended defense of N=100. |
| 1 | P55 | Retain tuning settings, Monte Carlo dependence of the selected parameters and uneven holdout transfer. Let F9 supply the individual performance numbers. |
| 1 | P57 | Keep both variance displays and every inline substitution, including covariance scaling, the zero-cross-covariance assumption and the resulting variance equation. Shorten the roadmap. |
| 1 | P58 + P59 | Keep the displayed R-squared relation and branch threshold; compress the synthetic-grid description around target residual variance, supplied generator variance, unit scale, independent residuals and asymmetric centering. Retain the restricted scope of this check. Cut the long empirical narration. |
| 1 | P60 | Keep both mean-identity displays, the OLS calibration identity and definitions of observed/supplied means. Compress interpretations into the distinction between retained intercept, changed market mean and clipped loading. If F14 is removed, retain its market-stress transformation here. |
| 1 | P61 | Keep every OLS algebra line, convergence assumptions, both branch variance results and residual-floor inequality. This remains a separate paragraph from the mean and terminal-return arguments. |
| 1 | P62 | Keep the complete terminal-sum display, fixed-market/effective-loading qualification, possible clipping variation and horizon dependence. These are substantive limitations, not expendable explanation. |
| 1 | P64 + P65 | Retain the residual construction, total-return versus idiosyncratic distribution distinction, variance budget, sample covariance qualification and distinction between path-specific and frozen training market variance. Delete the three-item rhetorical introduction and repeated roadmap. |
| 2 | P66 + the unique mathematical content of P67 | First unit: zero-loading boundary, constant-scale/population-moment assumptions, component definitions and every line of the fourth-moment expansion. Second: kurtosis definitions, component fourth moments, every line of kurtosis simplification and its extension to other branches using the actual market variance share. Preserve inline examples and any formula rehomed from F17. Delete P67's repeated summary of means, variance and reuse. |
| 1 | P69 | Keep draw-sharing design, replication-level averaging, standard-error divisor and 1.96 interval multiplier, plus the conditional nature of uncertainty. Cut episode-count and ticker-percentage narration if F19 is dropped; retain the training/holdout direction succinctly. |
| 1 | P71 + P72 | Keep the entire centering equation, effective-loading definition, unchanged variance/scales/loading/R-squared/kurtosis properties and common-asset population. Drop cache-fingerprint and reconstruction bookkeeping. Preserve the mean-treatment conclusion and terminal-uncertainty limitation. |
| 1 | P74 + P75 + P76 | Keep pooled finite-horizon quantile construction, path/market sharing, calibration/validation separation and the frozen-scale rule. Compress convergence evidence and common-asset check to a sentence each; retain the uniformly selected day interpretation, no terminal-risk restoration, and distinction between simulation stability and real-data coverage. This should be roughly 200–250 words, not all three paragraphs pasted together. |
| 1 | P78 | Keep the full fallback piecewise equation, all symbol definitions, interval/transition conventions and scale-versus-standard-deviation distinction. Retain only the aggregate inventory needed to identify affected models. If F23 goes, retain its fallback-mass formula and variance-change definition here. |
| 1 | P79 + P80 | Keep precisely which scales change, the point-mass consequence at zero scale, paired simulation design and treatment-specific generator variance in composition. Summarize effects via F24; preserve the unchanged main specification and absence of holdout validation. |

Total: **15**. Combining the first two short summaries makes **14**, but separate paragraphs are preferable because they test different questions. Expected prose lengths are about 100–200 words per unit, with some definition-heavy units near 250; displayed equations remain fully intact and add substantial page length independently of this paragraph count.

## Float cuts, assessed separately

The clearest reduction is **17 floats to about 7 in this block**. Retain F8, F9, one of F15/F16 (prefer F16 if its visual trend is legible), F18, F20, F21 and F24. I assessed figures from the supplied textual reader/captions, not rendered graphics.

- **Drop F10 and F11:** both repeat the two-asset branch assignment. Keep the threshold, branch counts and the definition `rho_i = beta_i^2 sigma_m^2 / sigma_gen,i^2`, including the unused clipped-branch condition, in the derivation prose.
- **Drop F12:** its branch-specific results are optional empirical detail; retain the branch populations in P58.
- **Drop F13:** the 15-row Gaussian check is disproportionately large for a restricted unit-scale check. Keep the mathematical construction and parameter grid (beta in {0.8,1.0,1.2}, R-squared in {0.80,0.85,0.90,0.95,0.99}) in compressed P58/P59. This removes tabulated evidence, not the derivation or test definition.
- **Drop F14:** rehome the full stress transformation `g_m^(gamma)(t) = mean(g_m) + gamma[g_m(t)-mean(g_m)]`, gamma in {1,2,3}, and its mean/variance effects. The three clipping percentages can fit in one sentence if needed.
- **Drop one of F15/F16:** they both support the loading/tail discussion. If dropping F16, retain the Hill-estimator definition (upper 5% of absolute returns) wherever the corresponding result remains. Avoid equating beta quartiles with variance-share quartiles.
- **Drop F17:** keep its distinctive standardized combination `sqrt(rho_i)x + sqrt(1-rho_i)y`, independence and evaluated shares, plus a short validation statement. The three-row table need not stand alone.
- **Drop F19:** episode incidence is secondary mechanism description; F18 carries the more consequential training/holdout comparison and uncertainty.
- **Drop F22:** retain a concise common-asset robustness statement and eligible count beside the primary coverage results. Its full ranking table is optional.
- **Drop F23:** the 39-ticker inventory is an especially strong space cut. **First retain** its mathematical definition `100 sum_{k in F} pi_k`, the definition of F, the meaning of the constant/empty/singleton-state counts and the meaning of Delta V. Retain the aggregate affected population/range and let F24 carry the sensitivity evidence.

These ten cuts would reduce the whole appendix from 24 to **14 floats** if F1–F7 stay. Dropping F9 as well is possible, but its concise cross-asset comparison is more useful than most proposed deletions. Any metric definition unique to a removed caption must be retained near the surviving use; deleting captions blindly is incompatible with the no-math-cut constraint.

## Essential explanations and caveat

The protected explanations are the sample-versus-population moment distinction; finite-path covariance terms; full-return versus residual distribution; intercept retention versus mean preservation; terminal zero-sum/horizon dependence; constant-scale assumptions in the kurtosis derivation; actual variance-share substitution on other branches; paired uncertainty conditional on fits/history; and fallback scale versus standard deviation. These are needed to avoid materially overstating the mathematical results.

This is a proposed allocation, not a verified 30-paragraph rewrite. Full mathematical preservation can coexist with fewer paragraphs and floats, but it does **not** imply a halving of appendix pages. The fixed equations and necessary definitions impose a lower bound that paragraph merging cannot remove. No new mathematical correctness claim is made by this scope review.
