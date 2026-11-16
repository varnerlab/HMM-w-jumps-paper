# First-read report: appendix.P52–P80 and appendix.F8–F24

Read as a quantitative-finance researcher with the preceding text as context. Empty paragraph entries are section boundaries. No paragraph restructuring or added detail is requested.

## Problems

appendix.P55.S6 | INCONSISTENT | 1 | “they are not unique per-ticker optima” | Monte Carlo sensitivity does not establish nonuniqueness of the optimum. I briefly wondered whether the objective has tied minima, rather than whether another simulation seed selects another grid point. | Guessed meaning: the reported choices are reproducible for the stated simulation settings but are not stable across Monte Carlo samples.

appendix.P58.S6 | INCONSISTENT | 2 | “exceeds” | The strict inequality conflicts with the earlier “at least” rule and with the following Gaussian check, which assigns cells at exactly 0.80 to this branch. This makes the branch-selection boundary unclear. | Guessed meaning: calibrated R² is at least 0.80.

appendix.P59.S10; appendix.F13.S5 | REREAD | 1 | “pass rates are nominal only” | “Nominal” usually identifies a specified significance or coverage level, whereas these are observed non-rejection percentages. The sentence then says their test calibration is unavailable, so I have to reinterpret “nominal” as a warning about evidential status. | Guessed meaning: these pass rates are descriptive; the nominal test level does not supply a calibrated interpretation in this dependent design.

appendix.P60.S5 | INCONSISTENT | 2 | “while other sign combinations raise it” | The statement contradicts the displayed mean-shift identity when both the loading and market mean are negative: shrinking the negative loading then also lowers the mean. | Guessed meaning: clipping lowers the mean when loading and market mean have the same sign and raises it when their signs differ.

appendix.F15.S2 | REREAD | 2 | “as the market loading ratio $\rho_i$ grows” | The table groups assets by β, but ρ also divides by each draw's generator variance. A higher β quartile therefore need not be a higher-ρ group. I cannot tell whether this is an observed increase in ρ or an assumed explanation of the β pattern. | Guessed meaning: pass rates decline across β quartiles, consistent with—but not by itself establishing—the proposed effect of a larger market variance share.

appendix.F16.S6 | INCONSISTENT | 2 | “does not cause its shortfall” | Similar naive and hybrid kurtosis does not rule out the rescaling contributing to the shortfall. Rescaling changes the market's share of total variance, which is precisely what the preceding kurtosis formula says changes composed kurtosis. The caption states a stronger causal conclusion than the comparison supports. | Guessed meaning: the shortfall is also present without the variance correction, so it cannot be attributed solely to that correction.

appendix.P74.S4 | REFERENT | 2 | “Each asset draw retained its own centering and variance correction” | This follows a sentence covering every composition method and reads as though all methods center and correct each draw. Earlier sections explicitly say the four residual comparators retain their native, uncentered treatment. I had to return to those definitions to decide whether the pooled-threshold experiment changes the comparators. | Guessed meaning: each separate path retained its method's native mean and variance treatment; naive and hybrid were centered, and hybrid used the stated correction.

appendix.P75.S4 | REFERENT | 1 | “the median asset's” | No ordering defines a median asset. The nearby caption resolves this as the median across assets of threshold changes, rather than the change for an asset with the median threshold. | Guessed meaning: the cross-asset median absolute relative change in the 99% threshold was 0.12–0.30%.

## Paragraph and caption purposes

appendix.P52: Section boundary introducing state-resolution sensitivity; no prose supplied.
appendix.P53: Describe the SPY state-count sweep, interpret its combined effects, and limit its relevance to other assets and shorter samples.
appendix.F8: Define the state-count comparison, uncertainty estimates, and ensemble ACF convention, and present the sweep results.
appendix.P54: Section boundary introducing cross-asset generalization; no prose supplied.
appendix.P55: Explain the three-stock replication, simulation sensitivity of tuning, and uneven holdout fit.
appendix.F9: Present per-stock selected jump settings and training/holdout distribution-test pass rates with simulation errors.
appendix.P56: Section boundary introducing composition derivations; no prose supplied.
appendix.P57: Derive the variance scale by centering the full-return draw and allocating the remaining variance budget under zero cross-covariance.
appendix.P58: Derive the residual variance needed for a target R² and identify which observed assets use that branch.
appendix.F10: Show the observed R² gap supporting the two tracker assignments.
appendix.F11: Display branch assignments in loading/R² space and explain the absence of clipping in the training run.
appendix.F12: Report factor recovery and marginal-fit metrics separately for the two composition branches.
appendix.P59: Define the restricted Gaussian implementation check and state its limitations for reuse, temporal fit, and test calibration.
appendix.F13: Present the Gaussian-grid recovery results and explain the unit-scale, shared-market design.
appendix.P60: Separate retaining the calibrated intercept from preserving a path mean or the observed asset mean, including the effect of clipping.
appendix.F14: Define the market-volatility stress transformation and report clipping incidence.
appendix.P61: Derive finite-path OLS errors and branch-specific variance properties, and delimit what the residual floor guarantees.
appendix.P62: Derive the zero terminal residual contribution and explain the resulting horizon dependence.
appendix.P63: Subsection boundary introducing the interpretation of full-return draws as residuals; no prose supplied.
appendix.P64: Identify the distributional mismatch involved in reusing full-return draws and state the subsection's scope.
appendix.P65: Separate mean, variance, and shape requirements and explain which ones the finite-horizon construction supplies.
appendix.P66: Establish the zero-loading identity, derive the fixed-scale population kurtosis formula, and connect it to the reported diagnostics.
appendix.F15: Present composition diagnostics across calibrated-loading quartiles.
appendix.F16: Describe the kurtosis and Hill-index plots and interpret the shared naive/hybrid tail shortfall.
appendix.P67: Contrast direct residual fitting with reuse and summarize the latter's branch-dependent preservation properties.
appendix.F17: Define and report a simulation check of the kurtosis composition formula.
appendix.P68: Section boundary introducing uncertainty for the multi-asset jump comparison; no prose supplied.
appendix.P69: Specify pairing and uncertainty units, then describe episode incidence and how broadly temporal changes occur across assets.
appendix.F18: Define jump-setting contrasts and present conditional Monte Carlo intervals for temporal fit and KS pass rates.
appendix.F19: Define the episode-frequency and cross-asset temporal-improvement summaries.
appendix.P70: Section boundary introducing the residual-centering control; no prose supplied.
appendix.P71: Define the paired centering transformation and identify its unchanged properties and remaining limitations.
appendix.P72: Establish the common eligible asset set, verify reproduced native results, and interpret the control's effect on method comparisons.
appendix.F20: Define and present native-versus-centered marginal-fit and intercept-recovery results on common training assets.
appendix.P73: Section boundary introducing pooled one-day tail thresholds; no prose supplied.
appendix.P74: Define how separate finite-horizon paths supply pooled tail thresholds and delimit the resulting return-law interpretation.
appendix.P75: Describe threshold-pool convergence and independent simulated validation while separating simulation precision from real-market coverage evidence.
appendix.F21: Define and present cross-asset threshold-change summaries and independent simulated exceedance rates.
appendix.P76: Check whether a common eligible holdout asset set changes the qualitative tail-coverage comparison and state its inferential limits.
appendix.F22: Present common-asset holdout exceedance means and cross-asset dispersion.
appendix.P77: Section boundary introducing fallback inventory and sensitivity; no prose supplied.
appendix.P78: State the implemented emission fallback rule, verify reconstruction, and quantify its incidence and stationary mass.
appendix.F23: Inventory affected assets, fallback-state counts and probability mass, and stationary-variance sensitivity to empirical constant-state scales.
appendix.P79: Define the paired empirical-scale diagnostic and its controlled components, reproduction checks, and scoring limitations.
appendix.P80: Report the fallback sensitivity's marginal-fit and variance effects and limit the conclusion to the training diagnostic.
appendix.F24: Define the paired fallback-sensitivity metrics, averaging, and simulation standard errors and present the results.

TOTALS: severity-3 = 0; severity-2 = 5; severity-1 = 3.
