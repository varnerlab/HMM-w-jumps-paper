Cold read: quantitative-finance researcher. Audited P27–P51 and F5–F7 only, using the preceding supplied text as context. Empty paragraph markers are treated as extraction placeholders. No manuscript changes or external research.

appendix.P51.S4 | REPLICATION AMBIGUITY | severity 2 slowed | “Each state's dwell time is negative binomial, fitted by the method of moments” | The dwell-time support is unclear. A usual negative-binomial variable includes zero, whereas a state visit must last at least one step; shifting, truncating, or otherwise treating zero changes the moment fit. I cannot tell which duration law the stated comparison uses. | The fit probably applies a shifted or zero-truncated negative-binomial law to positive visit lengths, with a positive-support geometric fallback.

Purpose appendix.P27: Empty marker under the generative-law heading; no prose to assess.
Purpose appendix.P28: State the no-jump joint law and emission density, establishing that all serial dependence passes through the states.
Purpose appendix.P29: Define the augmented state and transition kernel for forced episodes and reconcile its initialization with the simulation algorithm.
Purpose appendix.P30: Empty marker under the estimator heading; no prose to assess.
Purpose appendix.P31: Derive the fitted Laplace partition and distinguish model-equiprobable intervals from empirical state occupancy.
Purpose appendix.P32: Derive counted transition estimates, clarify unidentified rows, and connect emission estimates to their scale convention.
Purpose appendix.P33: Show why empirical occupancy nearly solves stationarity and quantify the endpoint correction for SPY.
Purpose appendix.P34: Empty marker under the stationary-moment heading; no prose to assess.
Purpose appendix.P35: Derive the stationary mixture and its mean, qualify the fallback exception, and explain strong training marginal fit.
Purpose appendix.P36: Decompose mixture variance and quantify the modest inflation caused by using empirical standard deviations as Student-t scales.
Purpose appendix.P37: Derive the fourth moment, explain the emission-dependent kurtosis gain, and describe how the mixture inherits empirical skewness.
Purpose appendix.P38: Empty marker under the no-jump dependence heading; no prose to assess.
Purpose appendix.P39: Derive absolute-return autocorrelation and show why the fitted chain loses volatility memory too quickly.
Purpose appendix.P40: Empty marker under the episode-arithmetic heading; no prose to assess.
Purpose appendix.P41: Derive episode-start probability and the long-run forced-step fraction using renewal cycles.
Purpose appendix.P42: Translate renewal quantities into episode incidence and forced-step shares over finite training-length paths.
Purpose appendix.P43: Contrast free and forced return distributions and quantify the approximate stationary-start error.
Purpose appendix.P44: Empty marker under the jump autocorrelation and kurtosis heading; no prose to assess.
Purpose appendix.P45: Derive the same-episode overlap probability and use phase means to approximate the slow autocorrelation component, then compare with simulation.
Purpose appendix.F5: Specify the episode-only ACF prediction and compare it with simulated jump-active paths at selected lags.
Purpose appendix.P46: Explain why episodes can improve temporal fit while lowering kurtosis and distribution-test pass rates.
Purpose appendix.P47: Explain why jump-active conditioning constrains duration more strongly than episode incidence.
Purpose appendix.P48: Empty marker under the transition-diagnostic heading; no prose to assess.
Purpose appendix.P49: Interpret the fitted partition, transition matrix, and short tail visits as motivation for the duration mechanism.
Purpose appendix.F6: Identify the partition, transition, and residence-time panels and their visual encodings.
Purpose appendix.P50: Empty marker under the emission and semi-Markov comparison heading; no prose to assess.
Purpose appendix.P51: Define the HSMM and emission comparisons, report their marginal and temporal performance, and distinguish the controlled emission effect from the confounded duration comparison.
Purpose appendix.F7: Define the three-way comparison table, uncertainty notation, path counts, and autocorrelation scoring convention.

TOTALS severity-3=0; severity-2=1; severity-1=0.
