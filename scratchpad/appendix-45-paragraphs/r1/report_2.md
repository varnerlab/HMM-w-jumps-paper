appendix.P34.S9 | INCONSISTENT | 2 | "the ACF is therefore bounded by a constant multiple" | The statement presents the exact second-eigenvalue bound as a general consequence of a counted transition matrix, although this bound needs a qualification about the spectral form of the fitted matrix; otherwise polynomial prefactors can occur. This matters to the asserted decay bound, rather than requesting an optional derivation. | The fitted SPY matrix has geometric decay governed by its subdominant eigenvalue, and the directly evaluated ACF establishes the practical rapid decay.
appendix.P37.S12 | REREAD | 2 | "misallocates $O(\pi_J) \approx 1%$ of probability mass" | The preceding calculation concerns the marginal state distribution, whereas a stationary start for the augmented process requires the joint state and remaining-duration distribution. The sentence makes the one-percent discrepancy sound like a quantified error for the complete initialization without saying which probability distance or distribution it describes. | The state marginal differs on the scale of the forced-step share, while the actual initialization also fixes the episode counter at zero.
appendix.P40.S2 | REFERENT | 1 | "Forced observations are conditionally independent draws from $u$." | The defined $u$ is a distribution over states, not return observations, so this briefly substitutes state draws for emission draws. | Forced states are independently sampled from $u$, followed by independent emissions from their selected states.
appendix.P41.S6 | REFERENT | 2 | "A sweep of the jump-active share confirmed the tradeoff" | No sweep definition, range, result, or identifiable reference accompanies this empirical confirmation, and the following sentences give a fitted-share result rather than the sweep. The reader cannot tell which change confirmed the tradeoff. | A separate sensitivity experiment varied episode incidence and found improved autocorrelation with poorer marginal fit.
appendix.P43.S5 | REREAD | 2 | "fitting used the unshifted visit lengths" | Fitting a nonnegative count distribution to positive observed lengths and then adding one raises the generated mean relative to the fitted mean. The operational description is clear, but its consequence for the duration benchmark is left implicit while the paragraph interprets temporal performance. | The implemented HSMM has an additional one-step dwell-time shift, which is another qualification on interpreting the duration comparison.
appendix.P51.S10 | INCONSISTENT | 2 | "clipping affected $0.0%$, $76.4%$ and $95.2%$ of the $423$ assets" | The main-text context reports percentages of composed paths and explains that clipping is recomputed for each draw. This sentence instead counts assets, without saying whether an asset clips in any, all, or a representative draw. | These are fractions of evaluated asset-path compositions, or an explicitly defined per-asset clipping classification.
appendix.P57.S1 | REREAD | 2 | "excess kurtosis of the supplied market series and of the generator draw" | The preceding paragraph deliberately switched to population moments with fixed coefficients, but this wording switches back to finite supplied series and draws. Their empirical kurtoses do not satisfy the population independence factorization exactly. | These symbols denote the population excess kurtoses of the two component laws in the fixed-coefficient approximation; finite-path estimates provide a diagnostic check.
appendix.P57.S5 | REFERENT | 1 | "For a low-loading asset" | The example fixes a low market variance share, which need not mean a low calibrated loading when generator variances differ. The next sentence about beta quartiles partly distinguishes these quantities, requiring a reread. | For an asset with a small market share of target variance, most generator excess kurtosis retains its weight.
appendix.F3.S1 | UNDEFINED | 1 | "Aggregate metrics by $\beta$ quartile" | The caption does not state how each reported metric is aggregated or identify that GARCH covers fewer assets, although these determine whether the rows share comparable asset sets. The earlier overall scorecard only permits an inference about this table. | Pass rates pool equal path counts, other entries summarize path scores by a specified median convention, and GARCH uses eligible assets within each quartile.
appendix.P65.S16 | PURPOSE | 1 | "For the inventory, $n_{\rm c}$ counted observations" | The paragraph introduces inventory symbols that do not occur in its inventory statements or the following sensitivity table; the reader searches for the inventory these definitions are meant to interpret. The same disconnect affects the named diagnostic $\Delta V$ in the next sentence. | These definitions belong to an accompanying per-asset inventory or should be tied explicitly to the counts and variance changes reported here, preserving the definitions.

appendix.P30: Establishes the stationary mixture law, its mean relationship to training data, and its small SPY CDF discrepancy.
appendix.P31: Explains how Student-t scale inflation contributes to total generator variance.
appendix.P32: Derives the fourth moment and explains why Student-t emissions improve the fitted tail shape.
appendix.P34: Derives no-jump absolute-return autocorrelation and shows its rapid decay at the SPY fit.
appendix.P36: Derives the long-run forced-step fraction from episode and waiting-time lengths.
appendix.P37: Connects episode arithmetic to path incidence, forced fractions, and approximate state occupancy.
appendix.P39: Derives the probability that two forced steps remain in the same episode.
appendix.P40: Approximates the slow autocorrelation contribution of forced episodes and compares it with simulations.
appendix.P41: Explains the kurtosis tradeoff and why conditioning on jump-active paths weakly identifies episode incidence.
appendix.P43: Defines the emission and HSMM comparisons and interprets their marginal and temporal performance.
appendix.F2: Reports the three variants' training and holdout metrics with simulation standard errors.
appendix.P45: Reports the combined sensitivity to state resolution, tail-set extremity, and retuned jump parameters.
appendix.P47: Reports separately tuned results for three additional assets and uneven holdout performance.
appendix.P49: Derives residual rescaling from the target variance and the omitted sample cross-term.
appendix.P50: Derives the R-squared branch and gives tracker and restricted Gaussian implementation checks.
appendix.P51: Separates retaining the fitted intercept from retaining the asset mean and illustrates clipping under market stress.
appendix.P52: Derives finite-path OLS recovery errors and distinguishes branch-specific variance targets.
appendix.P53: Establishes the zero terminal residual sum and the construction's dependence on the chosen horizon.
appendix.P55: Explains why a centered full-return generator is not automatically a validated regression-residual generator.
appendix.P56: Sets up the independent-component, fixed-coefficient approximation and expands its fourth moment.
appendix.P57: Derives the variance-share weights on component excess kurtoses and connects them to empirical composition results.
appendix.F3: Compares composition metrics across loading quartiles.
appendix.F4: Describes tail summaries across loadings and cautions that similar naive and hybrid tails do not isolate rescaling.
appendix.P59: Defines replication-level uncertainty for jump comparisons and reports the rarity of jump-active holdout paths.
appendix.F5: Reports conditional Monte Carlo intervals for jump-induced changes in temporal and marginal fit.
appendix.P61: Defines the paired residual-centering control and reports its invariances, eligibility set, and interpretation.
appendix.F6: Reports how equivalent residual centering changes marginal fit and intercept error across methods.
appendix.P63: Specifies pooled one-day thresholds, checks simulation stability, and limits interpretation of holdout coverage.
appendix.P65: Defines emission fallbacks and quantifies their occurrence and stationary mass.
appendix.P66: Defines a paired empirical-scale sensitivity experiment and reports improvements confined to training evidence.
appendix.F7: Reports marginal, variance, and temporal effects of the fallback-scale change with conditional simulation errors.
TOTALS: severity-3 = 0; severity-2 = 6; severity-1 = 4
