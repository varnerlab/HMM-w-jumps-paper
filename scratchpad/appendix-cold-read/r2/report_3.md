Cold read: quantitative-finance researcher. Read the supplied context and audited appendix.P52–P80 and appendix.F8–F24 only. Empty paragraph markers are identified below rather than treated as prose. No manuscript edits or optional-expansion requests.

ID | TYPE | severity | quote | problem | guessed meaning
--- | --- | --- | --- | --- | ---
appendix.F11.S1 | SCOPE | 1 minor | “separates tracker assets from single stocks” | The universe includes exchange-traded funds beyond the two trackers, so this description makes the lower branch sound stock-only. | The threshold separates the two high-R² trackers from all remaining assets in this universe.
appendix.P61.S3 | ASSUMPTION | 2 slowed | “If $\eps_i$ is independent of $g_m$” | The unscaled asset draw is independent of the market, but the composed residual uses a scale calculated from the market-path variance. I paused over whether this is a hypothetical sufficient condition or a condition claimed for the actual simulator; the stated independence does not carry directly through that scaling. | Under independent generator draws and convergent path moments, the scaled sample cross-covariance vanishes and the OLS errors approach zero.
appendix.P67.S5 | LOGICAL SCOPE | 1 minor | “requires the observed training market path and an unclipped loading” | “Requires” is stronger than the preceding mean identity: a different market path with the same mean and unchanged loading also matches the training asset mean. This briefly conflicts with the exact condition already derived. | Using the observed training market path and an unclipped loading guarantees the mean match in the reported training experiment.
appendix.F17.S1 | REPLICATION REFERENT | 2 slowed | “pairs of independent in-sample-length generator paths” | Both jump and no-jump SPY generators have been developed, with different kurtosis. This check does not identify which produced the pairs, so I cannot attach the reported numerical agreement to a specified generator configuration. | The check uses pairs from one fixed fitted SPY generator, presumably with the same jump setting used to obtain the displayed sample kurtoses.

Purpose lines

appendix.P52 | Empty marker beneath the state-resolution heading; no prose to assess.
appendix.P53 | Explain the state-count sweep, its marginal/temporal tradeoff, its confounding changes, and its SPY-only scope.
appendix.F8 | Specify and report the state-count sweep and its Monte Carlo uncertainty.
appendix.P54 | Empty marker beneath the cross-asset heading; no prose to assess.
appendix.P55 | Show how separately calibrated single-asset models generalize unevenly to three stocks and to their holdouts.
appendix.F9 | Report each stock's selected jump parameters and training/holdout distribution-test pass rates.
appendix.P56 | Empty marker beneath the SIM derivation heading; no prose to assess.
appendix.P57 | Derive the variance correction and state its sample cross-covariance qualification.
appendix.P58 | Derive the residual variance needed to target calibrated R² and identify eligible assets.
appendix.F10 | Show the empirical R² gap that supports assigning only two trackers to the alternate branch.
appendix.F11 | Map branch assignment in loading/R² space and explain the absence of clipping in training.
appendix.F12 | Compare training performance of the variance-preserving and R²-preserving branches.
appendix.P59 | Define the restricted Gaussian branch check and delimit what it validates.
appendix.F13 | Report loading and R² recovery under the Gaussian check with unit residual scale.
appendix.P60 | Distinguish retaining an intercept from preserving a path mean and quantify clipping-induced mean changes.
appendix.F14 | Define the market-volatility stress transformation and report clipping incidence.
appendix.P61 | Derive finite-path OLS recovery errors and describe branch-specific variance targets and the residual floor.
appendix.P62 | Derive the zero terminal residual sum and explain its horizon-dependent cumulative-risk limitation.
appendix.P63 | Empty marker beneath the residual-choice heading; no prose to assess.
appendix.P64 | Introduce the distinction between a full-return draw and an actual regression residual.
appendix.P65 | Separate residual mean, variance, and shape requirements and identify which the construction controls.
appendix.P66 | Derive the kurtosis contribution of independent market and asset components and connect it to loading-dependent fit.
appendix.F15 | Report how factor recovery and marginal metrics vary across calibrated loading quartiles.
appendix.F16 | Compare composed tail summaries across loadings and qualify what their similarity shows.
appendix.P67 | Contrast direct residual fitting with reuse and summarize the latter's exact and conditional properties.
appendix.F17 | Numerically check the independent-component kurtosis formula using paired generator paths.
appendix.P68 | Empty marker beneath the jump-uncertainty heading; no prose to assess.
appendix.P69 | Define paired jump comparisons and replication-level uncertainty, then describe episode incidence and the breadth of temporal changes.
appendix.F18 | Report conditional Monte Carlo intervals for temporal and marginal changes under jump settings.
appendix.F19 | Define episode-incidence counts and asset-level temporal-improvement shares.
appendix.P70 | Empty marker beneath the centering-control heading; no prose to assess.
appendix.P71 | Define the paired residual-mean translation and list its preserved metrics and limitations.
appendix.P72 | Establish the common eligible asset set, reproduction checks, aggregation conventions, and comparison implications.
appendix.F20 | Compare native and centered paths on common assets using distributional scores and intercept errors.
appendix.P73 | Empty marker beneath the pooled-threshold heading; no prose to assess.
appendix.P74 | Define separately composed path pooling and the finite-horizon one-day distribution it estimates.
appendix.P75 | Separate threshold Monte Carlo stability from real-return coverage and clarify uncertainty interpretation.
appendix.F21 | Report threshold convergence and independent simulation exceedance checks on eligible assets.
appendix.P76 | Check whether restricting all methods to common holdout assets changes the tail-coverage conclusions.
appendix.F22 | Report common-asset observed exceedance rates and their cross-asset dispersion.
appendix.P77 | Empty marker beneath the fallback heading; no prose to assess.
appendix.P78 | Specify and verify emission/transition fallbacks and inventory their prevalence and stationary mass.
appendix.F23 | Identify affected assets and quantify the stationary variance effect of removing broad constant-state scales.
appendix.P79 | Define the paired empirical-scale diagnostic and its reproduction and interpretation limits.
appendix.P80 | Summarize the diagnostic's training-fit gains and explain why it does not establish a replacement policy.
appendix.F24 | Report paired metric changes and Monte Carlo standard errors for the fallback-scale diagnostic.

TOTALS severity-3=0; severity-2=2; severity-1=2
