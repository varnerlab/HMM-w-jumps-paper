# Appendix cold-read triage and factual checks

All reported problems were suitable for in-place repair. No reader request required paragraph restructuring, relocation, a new experiment, or a changed numerical result. Raw severities remain in the reader reports.

## Round 1

| Reader ID | Decision and evidence |
|---|---|
| P2.S11 | Qualify the familiar correlation-noise benchmark with weak serial correlation; retain the independently measured spread and all values. |
| P4.S4 | State the zero-cross-covariance assumption beside variance matching; existing composition expansion and Composers.jl establish the condition. |
| P7.S5 | Replace perfect comovement with identical fluctuations, matching the displayed zero difference variance. |
| P8.S1 | Scope the loading calculation to fixed, unclipped loadings in the observed-market training comparison; Composers.jl distinguishes fitted and effective loadings. |
| P8.S14 | Replace the subjective “contributes little” with the quantitative implication of the existing bound. |
| P10.S6–S7 | Narrow the realized-return inference: the second-order expression has an unsigned remainder and a realized comparison includes sampling. An observed gap does not isolate residual dependence or establish the previously asserted upper bound. No new empirical claim is made. |
| P12.S8 | Distinguish conditional independence of simulated pass indicators from the shared observed history; preserve the descriptive test interpretation and conditional Monte Carlo errors in P18. |
| F2.S5 | Define the density envelope as pointwise 10th–90th percentiles, confirmed in Fig6-Statistical-Validation-SPY.jl lines 142–143. Remove the unnecessary global containment claim. |
| P20.S3 | Describe exponentiation of cumulative residual growth rates times the daily step, confirmed in 01b-Fit-Residual-Marginals.jl lines 72–77. |
| F4.S3 | Identify the stationary CDF as the no-jump mixture, confirmed by SI-Derivation-Checks.jl and the adjacent derivation. |
| P31.S2 | Distinguish parameters copied from sample summaries from the moments of the resulting distribution. |
| P36.S5 | State the Student-t variance increment relative to the matching Gaussian mixture; the displayed total-variance equation provides the exact comparison. |
| P41.S8 | Replace the promise of identifying both jump parameters with duration sensitivity and weak trigger identification, consistent with the tuning objective and P47. |
| P42.S6–S7 | Mark free waiting time and a typical untruncated episode fraction as approximations; SI-Derivation-Checks.jl uses the renewal-cycle calculation and lambda/T. |
| P45.S15 | Make the neglected post-episode relaxation explicit before the approximate phase-mean formula. |
| P45.S18 | Identify 3.01 as the variance of the fitted two-phase mixture, confirmed in SI-Derivation-Checks.jl lines 141–144. |
| P47.S3 | Remove the independent slope-identification claim; lambda affects the amplitude, duration and normalization in the existing expressions. |
| P49.S2 and F6.S1 | Equal probability belongs to the states, not their boundary points. |
| P55.S6 | Describe variation across Monte Carlo samples, rather than claim mathematically nonunique optima. |
| P58.S6 | Correct the verbal branch rule to “at least,” matching Composers.jl's >= threshold and the existing grid table. |
| P59.S10 and F13.S5 | Describe the test pass percentages as descriptive rather than nominal. The existing table header is retained. |
| P60.S5 | Correct the sign statement from the displayed mean-shift identity: matching signs lower the mean; opposite signs raise it. |
| F15.S2 | Remove the unsupported identification of beta quartiles with increasing market variance shares; qualify the related P66 transition. |
| F16.S6 | Narrow the causal interpretation: shared tail shortfall does not isolate the effect of rescaling. The existing kurtosis equation shows both components' variance-share dependence. |
| P74.S4 | Preserve each method's own centering/scaling rules, as implemented in VaREnsemble.jl lines 43–64. |
| P75.S4 | Specify the median across assets of absolute relative threshold changes, as already defined by its table caption. |

## Round 2

| Reader ID | Decision and evidence |
|---|---|
| P8.S9 | Restore “half” in the verbal description to match its unchanged displayed formula. |
| P24.S5–S7 | Clarify that both libraries are seeded before training and generation uses NumPy's continuing stream without reseeding; checked train_gru.py and reproduce_gru.py. |
| P51.S4 | Specify that the simulator adds one to a nonnegative count fitted using unshifted visit lengths. Include the mean >1.01 condition, checked Semi-Markov-Baseline.jl lines 267–290 and 365. No duration law or simulation was changed. |
| F11.S1 | Distinguish the two high-R-squared trackers from the remaining assets, rather than calling every other asset a stock. |
| P61.S3 | Apply independence to the underlying generator and market draws, not their path-dependent scaled residual. State convergent moments and nonzero limiting market variance as conditions for the stated large-sample result, consistent with Composers.jl and the displayed OLS identities. |
| P67.S5 | Replace a claimed necessary condition for mean matching with the sufficient condition used in the training comparison; the preceding exact mean identity is unchanged. |
| F17.S1 | Identify the SPY HMM-WJ generator; SI-Derivation-Checks.jl loads model_wj and simulates it for both components (lines 32–34 and 175–179). |

## Editorial checks

Kept all paragraph roles and boundaries. Cut redundant opening/preservation language to pay for necessary qualifications. Definitions and descriptions of existing formulas were clarified; the 55 displayed equation blocks, numerical table contents, citations, labels, and formatting were not changed. Added numerical settings (the density-envelope percentiles and dwell-fit cutoff) describe existing code, not new results.

The invariant checker flags only inherited acronym-led definition sentences in captions and the ticker SPY. These are functional symbol/model keys rather than new acronym-led narrative; SPY is a ticker, not an acronym. No further changes were made for these flags.
