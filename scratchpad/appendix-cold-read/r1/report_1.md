# Cold read: appendix.P1–P26 and appendix.F1–F4

Read only the supplied reader packet, including its preceding context. Empty paragraph records are treated as extraction placeholders, not prose defects. Equation-reference artifacts and fixed formatting are not audited.

## Problems

appendix.P2.S11 | INCONSISTENT | severity 1 | “For two independent series” | Independence between series alone does not give the stated correlation standard deviation when either series is serially dependent. The text momentarily makes the sampling-noise benchmark sound general, despite the paper's emphasis on temporal dependence. | Guessed meaning: approximately independent or weakly autocorrelated raw returns give the familiar 1/sqrt(T) benchmark, and the measured single-draw spread supports using it here.

appendix.P4.S4 | INCONSISTENT | severity 2 | “sets each composed variance to the generator variance” | This sounds exact immediately after P2 explains why the finite-path variance target is approximate. It is unclear whether the derivation has deliberately switched to the zero-covariance idealization. | Guessed meaning: the correction matches variance under the zero-cross-covariance assumption used for this derivation.

appendix.P7.S5 | REREAD | severity 1 | “comoves perfectly” | Perfect correlation is insufficient for zero difference variance if the assets have different volatilities. The parenthetical repairs the mathematical meaning, but I had to reread the verbal statement. | Guessed meaning: the positively weighted assets have identical fluctuations, possibly differing by constants.

appendix.P8.S1 | UNDEFINED | severity 2 | “single-index decomposition” | The substituted decomposition uses calibrated beta, whereas composed paths use the effective loading and clipping can change it. The later bound explicitly uses the calibrated range, leaving the scope of the portfolio conclusion unclear. | Guessed meaning: this calculation applies to the unclipped construction at the observed market variance; alternatively beta here denotes the loading actually used in composition.

appendix.P8.S14 | REREAD | severity 1 | “the market component therefore contributes little” | The bound is an absolute annual growth contribution, but no comparison scale makes 1.2 percentage points necessarily little. This wording invites a stronger economic interpretation than the bound establishes. | Guessed meaning: the market contribution cannot exceed approximately 1.2 percentage points per year under these inputs.

appendix.P10.S6–S7 | INCONSISTENT | severity 2 | “fall short of the second-order formula at all rebalancing horizons” | This reads as a universal inequality, although the preceding derivation supplies an approximation, not a signed approximation error. The following upper-bound conclusion also needs the synthetic approximation error and other matched moments controlled. I cannot tell which conditions or empirical setting make the bound valid. | Guessed meaning: a documented shortfall in a particular real-portfolio comparison could inflate a measured synthetic-minus-real gap beyond the effect of omitted positive residual covariance.

appendix.P12.S8 | INCONSISTENT | severity 2 | “the comparisons are not independent of one another” | Given the fixed observed history and fitted model, independently simulated paths give independent pass indicators, which is the conditioning subsequently used for the binomial standard error in P18. The unqualified dependence statement makes that later uncertainty calculation seem contradictory. | Guessed meaning: comparisons share uncertainty in the observed history and model when these are treated as random, although simulation outcomes are independent conditional on them.

appendix.F2.S5 | UNDEFINED | severity 2 | “the observed density falls within the simulation envelope” | The envelope's percentile level and pointwise versus simultaneous meaning are unspecified. Those distinctions determine what the claimed containment says; the earlier quantile envelope describes a different statistic. | Guessed meaning: the observed density curve lies within a pointwise band formed from the simulated density curves at some stated percentile levels.

appendix.P20.S3 | REREAD | severity 2 | “cumulative compounding of the residuals” | The residuals are annualized log-growth rates, so ordinary simple-return compounding would produce a different synthetic price path. The operation matters to understanding whether the no-jump fitter receives exactly the OLS residual growth rates. | Guessed meaning: exponentiate the cumulative residuals multiplied by the daily time step, so extracting growth rates from the synthetic prices recovers the residual series.

appendix.F4.S3 | REFERENT | severity 2 | “the model's stationary distribution function” | The caption follows an introduction to both HMM-NJ and HMM-WJ, whose stationary laws differ. The context also distinguishes the ordinary chain's exact stationary start from the jump-augmented process's approximate start. I cannot identify which law the sup-distance compares with the observations. | Guessed meaning: the stationary emission mixture of the no-jump counted chain, unless a jump-adjusted law is explicitly intended.

## Paragraph and caption purposes

appendix.P1: Empty record associated with the empirical cross-term diagnostic heading.
appendix.P2: Quantify the average finite-path asset–market cross-correlation and distinguish average cancellation from individual-path variance error.
appendix.P3: Empty record associated with the rebalancing derivation heading.
appendix.P4: Explain why the portfolio derivation focuses on residual covariance omitted by marginal variance matching.
appendix.P5: Derive the annualized one-step growth of a daily-rebalanced portfolio by a second-order expansion.
appendix.P6: Convert the one-step expansion to expected growth, identify diversification return, and delimit its stationary long-run interpretation.
appendix.P7: Express diversification return through pairwise difference variances and establish its nonnegativity.
appendix.P8: Separate market-loading dispersion from residual dispersion and bound the market contribution for the observed universe.
appendix.P9: Explain why serial dependence affects sampling variation but not diversification return at fixed same-date moments.
appendix.P10: Identify omitted positive residual covariance as a source of overstated diversification return and discuss limits of a realized-return comparison.
appendix.P11: Empty record associated with the validation-metric definitions heading.
appendix.P12: Define distribution-test pass rates and explain their descriptive interpretation.
appendix.P13: Define Wasserstein and histogram Hellinger scores, including the implemented bin-edge convention and sample-length limitation.
appendix.P14: Define excess kurtosis and the reciprocal Hill tail index and distinguish them from VaR coverage.
appendix.P15: Define pointwise quantile-envelope coverage and delimit its interpretation.
appendix.P16: Define the sample absolute-return ACF and ensemble-average ACF error used for single-asset comparisons.
appendix.P17: Define the path-average ACF error used for composition and explain why it differs from ensemble error.
appendix.P18: Specify Monte Carlo standard errors for each metric and the replication-level treatment of shared market dependence.
appendix.P19: Empty record associated with the six-method composition evaluation heading.
appendix.P20: Specify residual comparator fitting, GARCH eligibility, and the absence of subsequent centering or scaling.
appendix.P21: Explain how to interpret the scorecard when branches have different variance and factor targets.
appendix.P22: Empty record associated with the GRU benchmark heading.
appendix.P23: Specify the neural benchmark architecture, normalization, training objective, optimizer, and model-selection rule.
appendix.P24: Specify recursive neural generation, reproducibility conditions, and the limitation to one fitted network.
appendix.P25: Empty record associated with the single-asset generator derivation heading.
appendix.P26: Introduce the generator derivation and fix the fitted SPY inputs used in its numerical evaluations.
appendix.F1: Describe the distribution across tickers of averaged normalized asset–market cross-covariances for three residual sources.
appendix.F2: Describe distributional and temporal diagnostic panels, distinguishing jump-active training subsets from all holdout paths.
appendix.F3: Describe the observed SPY series, rate units, fitted comparison distributions, and stylized-fact tests.
appendix.F4: Describe the analytical-versus-empirical generator comparison, simulation sample sizes, and sup-distance reference value.

TOTALS: severity-3 = 0; severity-2 = 7; severity-1 = 3.
