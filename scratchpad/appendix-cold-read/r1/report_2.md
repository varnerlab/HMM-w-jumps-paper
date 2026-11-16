Cold-read report: appendix.P27–P51 and appendix.F5–F7

Read the supplied reader file in order; preceding material served only as context. Empty paragraph entries are retained in the purpose map and are not treated as manuscript defects. Formatting and extraction artifacts are not audited.

Problems

appendix.P31.S2 | INCONSISTENT | severity 1 | “each reproduces that summary exactly” | The opening sounds as though the fitted emission reproduces the within-state variance, whereas the established scale convention inflates that variance. The reader must distinguish copying a sample summary into a parameter from reproducing it under the fitted law. | Guessed meaning: the parameter estimates are direct functions of sample summaries; the emission scale equals the sample standard deviation.

appendix.P36.S5 | INCONSISTENT | severity 1 | “so the model variance exceeds the sample variance by” | The sentence first allows denominator and weight corrections, then states the excess as an exact equality. I have to carry the earlier qualification across the conclusion to avoid misreading the variance comparison. | Guessed meaning: this is the additional Student-t contribution relative to the corresponding Gaussian mixture, and approximately the excess over the sample variance.

appendix.P41.S8 | INCONSISTENT | severity 2 | “conditioning on paths with an episode separates them” | This promises that conditioning identifies the two parameters, but P47 says conditioning removes the main information about epsilon and leaves it weakly determined. The forward description makes the later limitation surprising. | Guessed meaning: conditioning isolates duration effects and explains why the chosen objective identifies epsilon poorly.

appendix.P42.S6–S7 | INCONSISTENT | severity 2 | “the forced fraction is” | The gap is stated as 1/epsilon even though the previous sentence includes the episode in the cycle length; the single-episode fraction is stated as lambda/T although realized duration varies and episodes may be cut off at the horizon. These exact-sounding quantities obscure which finite-path effects the numerical predictions neglect. | Guessed meaning: 1/epsilon approximates the free waiting time, and lambda/T approximates the forced fraction for one untruncated episode of typical duration.

appendix.P45.S15 | INCONSISTENT | severity 2 | “The conditional mean is” | The displayed conditional mean treats every free step as having the ordinary stationary mean, but P43 explicitly excludes the transient steps after an episode. The prose does not say that the same relaxation approximation is being used here. | Guessed meaning: after neglecting the short post-episode transient, the conditional mean is approximated by the two indicated phase means.

appendix.P45.S18 | UNDEFINED | severity 2 | “using the absolute-return variance of such a path” | The value 3.01 is supplied without identifying whether it is calculated from the fitted single-episode mixture or measured from simulated jump paths. That distinction matters to the claim that the resulting ACF curve predicts the simulation. | Guessed meaning: 3.01 is the absolute-return variance of the fitted mixture with forced weight lambda/T, used to normalize the analytic covariance prediction.

appendix.P47.S3 | REREAD | severity 2 | “both its height and its slope depend on” | Combining the preceding height proportional to lambda/T with the linear factor 1−tau/lambda cancels lambda from the unnormalized slope. Any remaining slope dependence comes through the lambda-dependent variance normalization, which is not identified here. I have to reconstruct that distinction before accepting the identifiability explanation. | Guessed meaning: lambda controls the episode component through its amplitude, duration, and variance normalization; the short-lag slope is not a separate simple proportional dependence.

appendix.P49.S2; appendix.F6.S1 | REFERENT | severity 1 | “boundaries $Q_k$ are equiprobable” | Boundaries in a continuous distribution are points with zero probability; the equal-probability statement belongs to the intervals they delimit. The intended referent is recoverable from the earlier partition definition. | Guessed meaning: the boundaries define states with equal probability under the fitted Laplace distribution.

Paragraph and caption purposes

appendix.P27: Empty supplied entry marking the generative-law subsection.
appendix.P28: Define the no-jump joint law, emission density, and state-mediated conditional independence.
appendix.P29: Define the augmented state and transition kernel, and relate their initialization to the implemented simulator.
appendix.P30: Empty supplied entry marking the estimator subsection.
appendix.P31: Derive the fitted Laplace partition and explain SPY's empirical state occupancy.
appendix.P32: Derive counted transition estimates and state the emission estimators and fallback conventions.
appendix.P33: Relate the solved stationary distribution to empirical occupancy, including the finite-history end effect.
appendix.P34: Empty supplied entry marking the stationary-moment subsection.
appendix.P35: Derive the stationary observation mixture and quantify its agreement with the SPY training mean and distribution.
appendix.P36: Explain and quantify variance inflation caused by using sample standard deviations as Student-t scales.
appendix.P37: Derive fourth moments and explain emission-driven kurtosis and inherited skewness.
appendix.P38: Empty supplied entry marking the no-jump dependence subsection.
appendix.P39: Derive the absolute-return ACF and show why the counted chain loses volatility memory too quickly.
appendix.P40: Empty supplied entry marking the jump-arithmetic subsection.
appendix.P41: Derive the long-run fraction of forced steps from episode renewal cycles.
appendix.P42: Translate rare episode arrivals into path-level incidence, counts, waiting times, and forced fractions.
appendix.P43: Quantify forced/free emission differences and the approximation used for the jump-augmented stationary state law.
appendix.P44: Empty supplied entry marking the jump ACF and kurtosis subsection.
appendix.P45: Derive the episode-overlap ACF approximation and compare its jump-path predictions with simulations.
appendix.F5: Define the analytic and simulated ACF columns and explain the short-lag contribution omitted from the prediction.
appendix.P46: Explain why jumps lower standardized kurtosis while improving temporal persistence and document the resulting metric tradeoff.
appendix.P47: Explain the tuning objective's duration sensitivity and weak identification of episode probability.
appendix.P48: Empty supplied entry marking the transition-diagnostic section.
appendix.P49: Connect the fitted partition, transition pattern, and short tail visits to the need for a duration mechanism.
appendix.F6: Explain the three model-internal panels and the comparison of state residence times with episode duration.
appendix.P50: Empty supplied entry marking the emission and semi-Markov comparison section.
appendix.P51: Specify the HSMM comparison, distinguish its confounded state-count comparison from the controlled emission comparison, and interpret the metric results.
appendix.F7: Specify the three compared generators, uncertainty display, path count, and ACF evaluation convention.

TOTALS: severity-3 = 0; severity-2 = 5; severity-1 = 3.
