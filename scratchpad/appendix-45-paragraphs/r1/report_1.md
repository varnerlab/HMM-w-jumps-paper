appendix.P8.S5 | INCONSISTENT | 2 | "so it does not change $\E(g_p)$" | The paragraph starts with a second-order statement, but this sentence makes invariance of expected portfolio growth sound exact. Holding residual variance fixed while changing AR persistence need not preserve the full same-date distribution or higher-order growth terms. | The second-order approximation to expected growth is unchanged when the relevant means, variances, and covariances are held fixed.
appendix.P11.S8 | INCONSISTENT | 1 | "the resulting weights sum to slightly less than one" | Omitting the pooled maximum does not generally remove an observation from both samples: the sample without that maximum still has weights summing to one. | At least one of the two sets of histogram weights can sum to less than one because the pooled maximum is excluded.
appendix.P12.S12 | INCONSISTENT | 2 | "Larger values indicate closer pointwise quantile agreement" | Higher envelope coverage can result from wider simulated quantile envelopes, even without better agreement of their centers with observed quantiles. The sentence overstates what this score establishes. | Larger values mean more observed quantiles fall within the pointwise simulated envelopes; interpretation also depends on envelope width.
appendix.P21.S7 | REFERENT | 1 | "Their annualized volatility" | The preceding sentence names both training and holdout returns, so the reader cannot tell which sample has the reported 13.5 percent volatility. | The value refers to the volume-weighted SPY training series used for the derivations.
appendix.F1.S1 | INCONSISTENT | 2 | "Each closed-form entry evaluates an expression derived in this section" | The uniform description does not distinguish exact fitted-model quantities from approximations, although the table includes a forced fraction estimated as lambda/T and a predicted single-episode plateau. A reader could interpret every entry as an exact expectation of the implemented finite-horizon generator. | Some entries are exact no-jump or long-run calculations, while others are finite-path or single-episode approximations whose assumptions are developed below.
appendix.P26.S1 | REFERENT | 1 | "the fitted law need not reproduce their moments" | Grammatically, "their" could refer to the partition, transitions, emissions, initial law, or sample summaries; the intended comparison is harder to locate than necessary. | The fitted generator need not reproduce the moments of the observed return sample.
appendix.P27.S1 | INCONSISTENT | 2 | "The transition matrix is the maximum likelihood estimator" | The previously displayed joint law includes a stationary initial probability that depends on the transition matrix, but the likelihood being maximized here omits that factor. The claim needs to identify the conditional transition likelihood so it does not appear to derive the full stationary-start MLE. | Row counting maximizes the transition likelihood conditional on the initial assigned state; the stationary initial distribution is solved afterward.

appendix.P2: Establishes that average market–draw correlations are near zero while individual finite paths retain nonzero variance cross-terms.
appendix.P4: Derives a second-order daily-rebalanced portfolio log-growth expansion from the wealth update.
appendix.P5: Takes expectations, identifies the diversification-return term, explains units, and limits the stationary long-run interpretation.
appendix.P6: Rewrites diversification return as weighted pairwise difference variances and establishes nonnegativity.
appendix.P7: Separates market and residual diversification returns, bounds the market contribution, and gives the independent-residual expression.
appendix.P8: Explains why serial dependence at fixed contemporaneous moments leaves second-order diversification return unchanged, while omitted cross-asset covariance can inflate it.
appendix.P10: Defines distribution-test pass rates and their descriptive interpretation under dependence and fitted-history reuse.
appendix.P11: Defines Wasserstein and histogram Hellinger discrepancies and records the histogram endpoint convention.
appendix.P12: Defines kurtosis, reciprocal Hill tail index, and pointwise quantile-envelope coverage.
appendix.P13: Defines absolute-return ACF and distinguishes error after ensemble averaging from average pathwise error.
appendix.P14: Defines Monte Carlo standard errors for single-asset scores and shared-market multi-asset contrasts.
appendix.P16: Specifies residual comparators and GARCH eligibility, then explains composition-specific score targets.
appendix.P18: Specifies GRU architecture, standardization, loss, training schedule, and training-only model selection.
appendix.P19: Specifies recursive GRU simulation, random streams, retained artifacts, and the limitation of one fitted network.
appendix.P21: Sets SPY parameters and data conventions for the generator derivations and introduces their numerical checks.
appendix.F1: Collects numerical stationary-law, dependence, and jump-episode calculations beside selected empirical or simulation comparisons.
appendix.P23: Gives the no-jump joint law and Student-t emission density, explaining conditional independence and stationary initialization.
appendix.P24: Makes the jump process Markov by adding a remaining-duration counter and relates its kernel to the simulation algorithm.
appendix.P26: Derives Laplace parameter estimates and quantile state boundaries, then reports empirical SPY state occupancy.
appendix.P27: Derives counted transition estimates, handles unobserved transitions, and recalls emission parameter estimation.
appendix.P28: Derives the empirical occupancy fixed-point residual and explains the fitted SPY stationary distribution's numerical closeness to occupancy.
TOTALS: severity-3 = 0; severity-2 = 4; severity-1 = 3
