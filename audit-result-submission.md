# Technical and Narrative Audit of the JFDS Manuscript

## Scope of review

This audit covers the compiled 34-page manuscript in `jfds-paper/Paper_v1.pdf`, its TeX source under `jfds-paper/`, and the associated Julia/Python experiment code under `code/`. The review focuses on technical correctness, alignment between claims and implementation, statistical interpretation, reproducibility, and narrative flow.

## Executive assessment

There is a publishable paper in this repository, but the manuscript currently asks its methods and experiments to support claims that are broader than the code warrants. The central empirical result is meaningful: the variance correction works under its stated zero-covariance assumption, and the jump-duration mechanism produces a measurable temporal effect. The manuscript will become substantially stronger by narrowing its claims and separating three presently competing stories:

1. a univariate quantile-state Markov generator with a tail-duration override;
2. a variance-corrected single-index composition method; and
3. a downstream portfolio rebalancing/bias-correction argument.

The third story is the least technically settled and currently creates the most serious internal contradictions. Before submission, the top priorities should be to recast the VaR evaluation, resolve or remove the allocator bias-correction claim, and correct the Student-t and jump-duration parameterizations.

## Major technical findings

### 1. The reported VaR “backtest” is not an out-of-sample forecasting backtest

The abstract and introduction describe forecasting tomorrow's loss over a holdout window. The implementation instead:

- fits and calibrates using the 2014–2024 universe;
- generates an unconditional synthetic path using the observed 2014–2024 SPY factor;
- estimates one VaR threshold from that synthetic path; and
- tests that threshold against the same asset's entire 2014–2024 real history.

Relevant implementation:

- [`code/downstream-evaluation/scripts/06-VaR-Backtest.jl`](code/downstream-evaluation/scripts/06-VaR-Backtest.jl), especially lines 134–175;
- [`code/downstream-evaluation/src/VaRBacktest.jl`](code/downstream-evaluation/src/VaRBacktest.jl), especially lines 73–87.

This is a useful in-sample unconditional tail-calibration diagnostic, but it is not a rolling one-day forecast or a conventional VaR backtest. The claims in `sections/introduction.tex` and `sections/results.tex` should either be renamed accordingly or replaced with a genuine rolling/expanding-window evaluation on 2025 and, if desired, the available 2026 partial-year data.

Recommended resolution:

- Preferred: implement rolling or expanding-window forecasts in which all model inputs at date \(t\) use information available only through \(t\), then score the realized return at \(t+1\).
- Minimal: rename the analysis “in-sample unconditional VaR calibration” or “tail-quantile coverage diagnostic” and remove “forecast tomorrow,” “holdout,” and similar language.

### 2. The diversification-return explanation contradicts its own derivation

The appendix correctly derives that, under stationarity, long-run expected rebalanced growth is determined by the one-period joint distribution. It therefore does not depend on residual serial structure when that one-period joint distribution is fixed. The appendix later explicitly says that the i.i.d./AR(1) distinction changes sampling variation rather than the ensemble median.

Relevant passages:

- [`jfds-paper/sections/appendix.tex`](jfds-paper/sections/appendix.tex), lines 234–239;
- the same file, lines 302–336.

However, the surrounding paper attributes the approximately 22-percentage-point growth gap to discarded residual temporal structure. This appears in the discussion and again in the empirical allocator interpretation.

The more plausible mechanism is missing **contemporaneous residual covariance** caused by omitted sector, style, or other common factors. Matching each asset's marginal variance does not match the residual covariance matrix. Independent residuals can exaggerate cross-sectional dispersion, and that dispersion directly enters the diversification-return identity.

Recommended resolution:

- Compute and compare the real residual covariance/correlation matrix against the synthetic residual covariance/correlation matrix.
- Re-run the allocator with residuals that preserve contemporaneous covariance, for example through an empirical or factor residual copula.
- Separate the effects of contemporaneous dependence, serial dependence, market nonstationarity, and higher moments instead of assigning the whole gap to i.i.d. sampling across time.
- Until that mechanism is identified, remove the causal claim that missing serial dependence produces the 22-point bias.

### 3. The location-shift correction does not preserve drawdown geometry

The proposed transformation is

\[
W_{p,t}^{\mathrm{corr}} = W_{p,t}\exp(-b t\Delta t).
\]

This transformation preserves terminal-wealth ordering across paths evaluated at a common terminal horizon. It also leaves the variance of log-return increments unchanged because it subtracts a constant drift. It does **not** preserve drawdowns: the time-dependent exponential factor can change peak dates, peak-to-trough ratios, recovery dates, and time under water.

Relevant passage:

- [`jfds-paper/sections/appendix.tex`](jfds-paper/sections/appendix.tex), lines 438–460.

The claims that the correction preserves “drawdown geometry,” “drawdown shape,” or the full drawdown distribution should be removed unless proved under a more restricted definition. The correction should be described as a scenario-level drift calibration anchored to an external prior. It forces the synthetic median to that prior by construction; it does not fix the underlying data-generating mechanism.

### 4. The fitted model is not hidden in the standard HMM estimation sense

Historical states are assigned deterministically from observed return bins, and transitions are then counted. There is no latent-state likelihood or posterior state inference in the fitting procedure described in the manuscript. See [`jfds-paper/sections/method_hmm.tex`](jfds-paper/sections/method_hmm.tex), especially lines 42–80.

The simulator does have latent states, but the training-state sequence is an observed deterministic quantization of the returns. More technically precise names include:

- quantile-state Markov generator;
- discretized-state Markov model with tail-duration override; or
- observed-state Markov generator.

If “hidden Markov model” is retained, the manuscript should explain precisely in what sense the state is hidden and distinguish the deterministic training encoding from conventional latent-state HMM estimation.

The reported parameter counts are also misleading. A 100-state construction estimates a large transition matrix plus state-specific emission and partition parameters, even if only two or four hyperparameters are tuned by grid search. The “Parameters estimated” row should be renamed “Tuned hyperparameters,” or all free/effective parameter counts should be reported consistently across methods.

### 5. The Student-t emission scale is misdescribed and inflates conditional variance

The manuscript defines

\[
G_t\mid S_t=k = \mu_k + \sigma_k t_5
\]

while saying that \(\sigma_k\) is the sample standard deviation of observations assigned to state \(k\). A standard \(t_5\) variable has variance \(5/3\), so the conditional standard deviation of that emission is actually

\[
\sigma_k\sqrt{5/3},
\]

not \(\sigma_k\).

The exploratory implementation follows this construction; for example, see [`code/spy-experiment/N6-df-Sensitivity.jl`](code/spy-experiment/N6-df-Sensitivity.jl), lines 98–115.

Recommended resolution:

- If the intended conditional SD is the empirical within-state SD, use the location-scale parameter
  \(\sigma_k\sqrt{(\nu-2)/\nu}\).
- Otherwise, call \(\sigma_k\) a scale parameter rather than a standard deviation and explicitly acknowledge the induced variance inflation.

Because the paper attributes much of the kurtosis improvement to Student-t emissions, this correction should be followed by regeneration of the univariate tables and figures.

### 6. The jump-duration algorithm is off by one

At a jump trigger, Algorithm 1 samples a tail state immediately and then stores \(K\) future forced steps. Consequently, it produces \(K+1\) forced tail-set observations. Even a draw of \(K=0\) produces one forced tail observation. The surrounding text says the jump lasts \(K\) steps.

Relevant passage:

- [`jfds-paper/sections/method_hmm.tex`](jfds-paper/sections/method_hmm.tex), lines 220–250.

The duration convention should be made explicit and matched in both code and pseudocode. A shifted or zero-truncated duration distribution would avoid zero-length ambiguity. The justification should also be revised: a Poisson distribution is naturally a count distribution; it is not automatically a standard dwell-time model.

### 7. The calibration code and manuscript use different path-selection rules

The manuscript says the simulated ACF and kurtosis are averaged across 200 independent paths per grid point. The standalone sweep discards every path without a jump:

```julia
any(path.jumps) || continue
```

See [`code/spy-experiment/HMM-Parameter-Sweep.jl`](code/spy-experiment/HMM-Parameter-Sweep.jl), lines 52–78.

At \(\epsilon=10^{-4}\), only about 24% of 2,766-day paths contain a jump. Conditioning calibration on this minority produces a different objective from evaluating the unconditional generator. This also explains why roughly 76% of generated HMM-WJ paths behave like HMM-NJ.

The paper should state exactly which objective generated the reported operating point and use the same rule in the manuscript, saved artifacts, and plotting scripts. An unconditional generator should generally be tuned and evaluated unconditionally unless the conditioning is an explicitly defined separate experiment.

### 8. “Marginal preservation” is too strong

Scaling the full-return generator and adding a market component preserves a variance target under the zero-covariance assumption. It does not preserve the full marginal distribution in general: convolution with the market factor changes that distribution.

The empirical results reflect this limitation. Hybrid achieves a 50.4% KS pass rate, whereas residual-fit alternatives achieve approximately 67–76%. A technically accurate description would be:

> variance-preserving composition with partial retention of heavy-tailed character.

The method should not claim exact marginal fidelity or preservation. The algebra proves a second-moment identity, not distributional equality.

### 9. KS and AD pass rates are interpreted too literally

Ordinary two-sample KS and AD p-values assume independent observations. Several evaluated generators produce serially dependent paths, including HMM, HSMM, GARCH, and block-bootstrap models. Their p-values are therefore not calibrated uniformly across generators.

The simulation replications also reuse the same observed sample and fitted model. Binomial standard errors across replications measure Monte Carlo variation conditional on the fitted data; they do not measure uncertainty about model estimation or generalization.

Recommended resolution:

- Give greater weight to Wasserstein distance, quantile error, tail coverage, and ACF error.
- Use block-calibrated or simulation-calibrated goodness-of-fit tests where dependence matters.
- Clearly distinguish Monte Carlo standard errors from data/model-estimation uncertainty.
- Avoid presenting “pass rate” as an absolute model-quality probability.

### 10. The base-chain stationary distribution is not stationary for the jump-augmented process

The initial state is sampled from the stationary distribution of the empirical transition matrix \(\mathbf T\). Once the jump mechanism is added, the augmented process has a different invariant distribution because it includes jump status, remaining duration, and tail direction. Initializing from the stationary distribution of \(\mathbf T\) does not initialize the full HMM-WJ process in stationarity.

This is probably a small effect for long paths, but it should be handled by either:

- using a burn-in period;
- computing the invariant distribution of the augmented state process; or
- describing initialization as an approximation rather than stationarity of the full generator.

## Claims that should be softened

### Combined superiority

The conclusion says HMM-WJ outperformed bootstrap and HMM-NJ on combined distributional and tail metrics. No combined score is defined, and bootstrap and HMM-NJ beat HMM-WJ on multiple reported metrics. The defensible claim is a **Pareto tradeoff**: HMM-WJ modestly improves temporal fidelity relative to HMM-NJ at a modest cost in marginal fit.

### “Jump-diffusion” terminology

The model has a discrete-state tail-duration override but no explicit diffusion process. “Jump-duration” or “tail-duration” is more precise than “jump-diffusion.”

### “i.i.d. floor”

The phrase should be “i.i.d. baseline.” A floor conventionally denotes a lower bound, whereas the manuscript is referring to the ACF error achieved by independent sampling.

### Volatility-clustering claim

At the selected \(\epsilon\), approximately 76% of long generated paths have no jumps and behave like HMM-NJ. In a 249-day horizon, the probability of any jump is smaller still. Claims that the generator generally reproduces volatility clustering should acknowledge this mixture explicitly.

### Universe-scale HMM-WJ validation

The multi-asset composer experiment disables jumps for each ticker. It therefore validates the composition algebra and no-jump marginal generator at universe scale, not the headline jump-duration mechanism across 424 assets.

## Narrative and structural assessment

### Strongest available story

The clearest paper is:

> A transparent quantile-state Markov generator with a sparse tail-duration intervention produces a useful marginal/temporal tradeoff, followed by an application to variance-corrected factor composition.

The current manuscript contains three separate contribution arcs. The portfolio bias-correction arc is the least settled and occupies disproportionate space in the abstract, introduction, discussion, conclusion, and appendix. It should be removed from the headline contribution and either reduced to a limitations paragraph or developed as a separate study after its causal mechanism is resolved.

### Recommended main-text structure

1. **Introduction**
   - Problem and stylized facts.
   - Gap in existing generators.
   - Two contributions only: tail-duration state generator and variance-corrected SIM composition.

2. **Related work**
   - Condense historical material.
   - Make the distinction from HSMMs and conventional HMM estimation precise.

3. **Methods**
   - Quantile-state marginal generator.
   - Tail-duration mechanism.
   - Experimental design and baselines.
   - Variance-corrected SIM construction.
   - Validation metrics and uncertainty definitions.

4. **Results**
   - Does the duration override improve temporal fidelity?
   - What marginal-fit cost does it impose?
   - Does the variance correction improve composition?
   - Optional genuine out-of-sample VaR forecast evaluation.

5. **Discussion**
   - Explicit tradeoffs and limitations.
   - Cross-sectional residual dependence and simulated-market uncertainty.
   - No allocator drift correction unless independently justified.

6. **Conclusion**
   - State only what the reported experiments directly establish.

### Current flow issues

- The introduction includes substantial methods and downstream results before the core model is fully established.
- The Results section contains universe construction, composer definitions, fitting details, and evaluation protocol that belong in Methods.
- The Discussion repeats many Results numbers and spends too much space defending secondary design choices.
- The abstract is overloaded with the HMM, SIM correction, VaR result, allocator artifact, and location-shift correction.
- The conclusion overstates model dominance instead of presenting the empirical tradeoff honestly.

## Reproducibility and code audit

### Broken or stale instructions

- The top-level code README instructs users to run a nonexistent `Fit-HMM-WJ-SPY.jl` script.
- The downstream README lists the VaR table formatter before the VaR script that creates its input.
- The top-level README says Table 5 must be updated manually, while the downstream pipeline contains an automatic formatter.

### Environment instantiation

Both relevant `Include.jl` files instantiate packages only when `Manifest.toml` is absent. On a clean checkout where the committed manifest is present but packages have not been installed, they do not call `Pkg.instantiate()`.

Relevant files:

- [`code/spy-experiment/Include.jl`](code/spy-experiment/Include.jl);
- [`code/downstream-evaluation/Include.jl`](code/downstream-evaluation/Include.jl).

The normal pattern should activate the project and call `Pkg.instantiate()` explicitly as a documented setup step. Installation should not be hidden behind manifest absence.

### “Paired innovation” mismatch

The manuscript and README say all composers receive the same per-ticker innovation draw. Gaussian SIM actually draws a fresh Gaussian sample in [`code/downstream-evaluation/src/Pipeline.jl`](code/downstream-evaluation/src/Pipeline.jl), lines 233–247. Naive and hybrid are paired; Gaussian is not paired to their realized shock values, only evaluated under the same outer calibration.

The wording should be corrected, or the experiment should pair composers using common uniforms transformed through each marginal distribution.

### Reproducibility status

The downstream Julia environment loaded successfully, and a direct smoke test confirmed that the core hybrid composition achieves the intended variance identity when the covariance assumption is satisfied. This supports the algebraic implementation. The larger concerns are interpretation, validation design, and inconsistencies between manuscript language and code paths.

### Testing recommendations

Add automated tests for:

- exact variance recovery with zero covariance;
- the general variance formula when covariance is nonzero;
- \(R^2\)-branch recovery;
- clipping behavior and effective-beta reporting;
- Student-t emission variance;
- jump-duration counts, especially \(K=0\) and \(K=1\);
- unconditional versus jump-conditioned calibration objectives;
- rolling VaR forecasts with no future-data leakage;
- drawdown changes under the proposed location shift.

## PDF and presentation audit

The compiled PDF is visually clean overall. No catastrophic clipping, missing figures, or broken references were observed. The figures are generally legible and the typography is consistent.

Remaining presentation issues:

- Several tables are dense and require small type.
- The abstract is unusually packed and difficult to scan.
- The LaTeX log contains multiple underfull boxes and several overfull boxes, including two material overflows of roughly 10–15 pt.
- Long captions repeat interpretation that already appears in the main text.
- The 34-page preprint feels longer than the core contribution requires, largely because the allocator correction and repeated caveats create a second discussion arc.

## Recommended revision order

1. Recast or replace the VaR evaluation.
2. Remove the allocator bias correction from the headline contribution.
3. Diagnose contemporaneous residual covariance before assigning the allocator gap to serial dependence.
4. Correct Student-t scaling and jump-duration semantics, then regenerate univariate results.
5. Rename the model or explain precisely in what sense its states are hidden.
6. Reframe the SIM result as variance preservation rather than exact marginal preservation.
7. Add an Experimental Design subsection and shorten Results and Discussion.
8. Correct parameter-count and statistical-uncertainty language.
9. Repair clean-checkout reproduction instructions and add targeted tests.
10. Rebuild and visually verify the final PDF.

## Bottom line

The central results do not appear meaningless: the variance correction is sound under its stated covariance assumption, and the jump-duration intervention produces a real temporal effect. The manuscript's main weakness is overextension. It currently treats an observed-state quantile model as a conventional HMM, an in-sample tail diagnostic as a forecast backtest, a second-moment correction as marginal preservation, and a prior-anchored drift adjustment as a mechanism-level bias correction.

Narrowing those claims would not weaken the paper. It would make the genuine contribution easier to see, easier to defend, and much more credible to a technical reviewer.

---

# Author Response to the Audit (2026-07-13)

## How we handled this audit

Before changing anything, we independently verified every code-dependent claim in this audit against the actual source (the JumpHMM.jl package, the experiment scripts, and the manuscript), because an audit generated without running the code can misread it. Several claims held up exactly; a few were partially correct (the defect was in the manuscript or pseudocode, not the code); one was incorrect. We then made a single revision pass of 25 prose, pseudocode, and documentation edits, with **no regeneration of results** (committed as `da352ae`, clean build, 35 pages, no undefined references, no overfull boxes above 20 pt). Where a fix required new experiments or new code, we deferred it and say so explicitly below.

Legend: **AGREE** (finding correct, acted), **PARTIAL** (finding correct in part; we describe the part), **DISAGREE** (finding incorrect or not actionable as stated), **DEFERRED** (correct but requires new work we did not do this pass), **DECLINED** (correct on the narrow technical point but we made a deliberate opposite choice, with rationale).

## Major technical findings

### 1. VaR "backtest" is not an out-of-sample forecast — AGREE (in part); FIXED by rewording
We confirmed the implementation: `06-VaR-Backtest.jl` and `VaRBacktest.jl` estimate a single static threshold from the full synthetic path and test it against the same asset's entire 2014-2024 real history via Kupiec's *unconditional*-coverage test. There is no rolling/expanding window and no information-set discipline. The audit is correct on the code.

However, the overstatement was localized. The Results paragraph and the Table 5 caption already described the exercise accurately ("estimate the VaR threshold from the composed path and count exceedances against the real 2014-2024 growth-rate history," "Kupiec unconditional-coverage test"). Only the Introduction used "forecast tomorrow's worst plausible loss" and "ran the forecast over a real holdout window."

Action: we adopted the audit's "minimal" resolution, rewording the Introduction to "estimated a one-day VaR threshold from the composed path and checked whether its breach frequency ... matched the nominal coverage level (a one-day VaR coverage check scored by Kupiec's unconditional-coverage test)." We **did not** implement the audit's "preferred" rolling forecast (see Deferred).

### 2. Diversification-return explanation contradicts its own derivation — AGREE on the contradiction; PARTIAL on mechanism; FIXED (reframed), DEFERRED (quantification)
We agree there was an internal contradiction. The appendix (from an earlier rederivation) already stated that the i.i.d.-versus-AR(1) serial structure does not move the ensemble median and attributed the excess to higher-moment, nonstationarity, and attenuation effects; but the Discussion still attributed the ~22 pp gap to discarded *serial* (across-time) dependence. That was the inconsistency.

We agree with the audit's proposed mechanism: the more direct structural contributor is **contemporaneous cross-asset residual covariance** (common sector/style factors), which the per-asset i.i.d. generator omits. We reframed both the Discussion and the Appendix to attribute the artifact to cross-asset (contemporaneous) independence rather than serial dependence, and the Appendix now states explicitly that the cross-asset orthogonality assumption holds for the i.i.d. generator but not for real residuals, so the synthetic idiosyncratic dispersion term is inflated relative to the market.

We **did not** run the recommended diagnostic (compute real-versus-synthetic residual covariance and re-run the allocator with covariance-preserving residuals). The mechanism is now named and flagged as the plausible dominant contributor, explicitly not yet quantified. Quantification is deferred.

### 3. Location-shift correction does not preserve drawdown geometry — AGREE; FIXED
We confirmed the mathematics. `W_{p,t}^{corr} = W_{p,t} exp(-b t Δt)` is a linear detrend in log-wealth: it shifts every log-return increment by the same constant (so increment variances, the "volatility envelope," are unchanged) and is monotone in `W_{p,t}` at any fixed step (so cross-path terminal-wealth rank order is preserved). It is **not** constant in wealth space, so it moves drawdown dates and depths. The audit is correct.

Action: we removed the "preserves drawdown geometry/shape" claims at all four sites (appendix twice, discussion, conclusion) and now describe the transform as a level recalibration that preserves rank order and the volatility envelope but moves drawdowns; drawdown-based diagnostics are directed to the uncorrected ensemble.

### 4. Not a hidden Markov model in the standard estimation sense; parameter counts misleading — PARTIAL (DECLINED on rename; AGREE on parameter counts)
On the estimation point, the audit is technically right that training assigns states deterministically by quantile bin and counts transitions, bypassing latent-state likelihood/Baum-Welch. We **declined** to rename the model away from "HMM." Our reasoning: the simulator carries a genuine latent state (unobserved to a returns-only observer), the deterministic training encoding is already disclosed in the manuscript ("bypassing the iterative Baum-Welch algorithm ... direct frequentist counting"), and the "HMM-WJ" name is stable across the arXiv preprint and prior drafts. We added an in-text clarification of the discrete-state, tail-duration nature (see the terminology item below) rather than retitling.

On parameter counts, we agree the row was misleading. We renamed "Parameters estimated" to "Free parameters" and added a caption note stating that for the state-based models the frequentist-counted transition matrix and per-state emission moments are plug-in estimates and are excluded, whereas the GRU entry is its full trained weight vector. We did not attempt a unified effective-parameter count across model families; the caption now discloses the asymmetry directly.

### 5. Student-t emission scale inflates conditional variance — AGREE on the math; FIXED by description, DISAGREE on the need to regenerate
We confirmed the code applies no `sqrt((ν-2)/ν)` correction in any path (package `Emission.jl` `sample_emission`: `μ + σ*rand(TDist(ν))`), so with `σ_k` set to the within-state sample SD, the conditional SD is `σ_k*sqrt(5/3)`. The audit is arithmetically correct.

The important qualification the audit did not weigh: `ν = 5` was selected by a sensitivity sweep run **under this exact scaling**, and the aggregate marginal passes KS/AD at high rates (IS 97.6% / 91.3%). The operating point is therefore self-consistent with the code as written. We adopted the audit's *second* recommended option (call `σ_k` a scale parameter and disclose the induced variance), not its first (change the scaling to `σ_k*sqrt((ν-2)/ν)`), because changing the scaling would force re-selecting `ν` and could undo the kurtosis match that the emission choice exists to achieve.

Action: the emission definition now states that `σ_k` is a scale parameter equal to the within-state sample SD, that the conditional SD is `σ_k*sqrt(ν/(ν-2)) = σ_k*sqrt(5/3)`, and that the degrees-of-freedom sweep was run under this parameterization. We **disagree** with the recommendation to regenerate the univariate tables and figures: with the description fix, no numbers change and no regeneration is warranted.

### 6. Jump-duration algorithm is off by one — PARTIAL: the CODE is correct, the PSEUDOCODE was wrong; FIXED pseudocode
This is the finding where verifying the code mattered most. The simulator (`Simulate.jl`) produces **exactly K** forced tail-set observations, and a draw of **K = 0 produces zero** forced observations (it falls through to an ordinary Markov transition with the jump flag false). The prose ("for K consecutive steps") matches the code. The printed **Algorithm 1** was the artifact that was off by one: it emitted a forced tail state on the trigger step *in addition to* K continuation steps (K+1 total), and it forced a tail state even when K = 0. So the audit's reading of the *pseudocode* is accurate, but no generated results are affected because the implementation is correct.

Action: we rewrote Algorithm 1 so the trigger branch draws K, routes K = 0 to a standard transition, and otherwise emits the first forced step and sets the continuation counter to `min(K, T-t) - 1` (exactly K forced steps total), matching the code line for line. We agree with the count-versus-dwell-time point and added a caveat that, because the Poisson support includes zero, `λ` is the mean length of a *triggered* episode rather than a guaranteed minimum dwell.

### 7. Calibration uses a different path-selection rule than the manuscript — AGREE, and it is more robust than stated; FIXED by disclosure
We confirmed the mismatch and that it is stronger than the audit claims. The filter `any(path.jumps) || continue` appears not only in the standalone `HMM-Parameter-Sweep.jl` but also in the authoritative `JumpHMM.tune()` (`Tune.jl`), which is what actually produced the reported operating point (it uses `acf_lags = 25`, matching the manuscript, whereas the standalone sweep uses 252). Both divide the ACF/kurtosis objective by the jump-path count. The manuscript described an unconditional 200-path average and disclosed no filtering. At `ε = 10^-4`, roughly 24% of 2,766-day paths contain a jump, so the objective is effectively conditioned on that minority.

Action: the objective description now discloses that the simulated ACF and kurtosis are averaged over the jump-active paths, with the rationale that a jumpless path reduces to the no-jump generator and carries no information about `(ε, λ)`. We regard conditioning the jump-tuning objective on jump-active paths as a defensible design (you tune how jumps behave by measuring paths where they occur), but we agree it must be stated, and it now is. We **did not** re-tune the objective unconditionally (which would move the operating point); we consider an unconditional retune a legitimate alternative and note it as possible future work rather than a defect requiring a rerun.

### 8. "Marginal preservation" is too strong — AGREE; FIXED
We agree that convolution with the market factor changes the marginal, and that the 50.4% hybrid KS pass rate (versus 67-76% for residual-fit composers) reflects this. We changed the aggregate-table caption from "only the hybrid composer preserves the marginal distribution" to "holds the marginal variance close to the generator target and retains its heavy-tailed character, though convolution with the market factor still shifts the full marginal." The algebra is presented as a second-moment identity, not distributional equality.

### 9. KS and AD pass rates interpreted too literally — AGREE; FIXED
We added a caveat stating that two-sample KS/AD p-values assume independent observations, which the HMM, HSMM, GARCH, and bootstrap generators violate, so their pass rates are not calibrated on a common footing; that we therefore weigh them alongside the distribution-level distances (Wasserstein-1, Hellinger, Hill tail index); and that the parenthetical standard errors are Monte-Carlo variation across replications at the fitted model, not uncertainty about the fit.

### 10. Base-chain stationary distribution is not stationary for the jump-augmented process — AGREE (minor); FIXED
We added a sentence noting that the stationary distribution of the transition matrix approximates the invariant distribution of the jump-augmented process (whose state also carries jump status and remaining episode length), and that the discrepancy affects only the first few steps of a 2,766-day path. We treated this as a description fix rather than adding a burn-in, consistent with the audit's own assessment that the effect is small for long paths.

## Claims that should be softened

- **Combined superiority — AGREE; FIXED.** The conclusion no longer claims HMM-WJ "outperformed ... on combined distributional and tail metrics" (no combined score was defined, and bootstrap/HMM-NJ win some rows). It now states the Pareto tradeoff: HMM-WJ is the only non-GARCH, non-neural model to reduce absolute-return autocorrelation error meaningfully below the i.i.d. baseline while holding near-best distributional fidelity, at a few percentage points of marginal-fit pass rate relative to the no-jump variant.
- **"Jump-diffusion" terminology — DECLINED (with in-text clarification).** We agree the model has no continuous diffusion component. We kept the title and keywords for arXiv continuity and added a sentence in Methods stating that the "jump-diffusion" label refers to the heavy-tailed tail-duration override on a discrete-state chain with Student-t emissions and that the construction carries no continuous-time diffusion. This is a deliberate choice; the technical point is acknowledged in the body.
- **"i.i.d. floor" — AGREE; FIXED** at the contradictory site (the Discussion phrase "below the i.i.d. floor," where "floor" cannot be gone below, is now "i.i.d. baseline"). We left the Results phrase "the i.i.d. floor (0.060) and the GARCH ceiling (0.031)" because there floor/ceiling denote the two ends of a performance range and the usage is internally coherent.
- **Volatility-clustering claim — AGREE; already disclosed.** The Results and Discussion already state that roughly one path in four contains a jump and the remaining ~76% behave like the no-jump variant. No change needed.
- **Universe-scale HMM-WJ validation — AGREE; already disclosed.** The Results and Discussion already state that the per-ticker composer generators run with `ε = 0` (jumps disabled), so the universe-scale experiment validates the composition algebra and the no-jump marginal, not the jump mechanism. No change needed.

## Narrative and structural assessment — PARTIAL / DECLINED
We agree the portfolio bias-correction arc is the least-settled of the three stories. We **declined** the recommendation to demote it out of the headline as a structural requirement; instead we reconciled the internal contradiction (finding 2) and made its claims honest (findings 2, 3), keeping it as a documented caveat with the mechanism now correctly attributed. This is a scope decision by the authors. We **did not** undertake the larger main-text restructure (a dedicated Experimental Design subsection, migrating universe-construction and protocol text from Results to Methods, trimming Discussion/abstract). We regard those as reasonable editorial suggestions but out of scope for a claims-accuracy revision pass.

## Reproducibility and code audit

- **README references a nonexistent `Fit-HMM-WJ-SPY.jl` (A) — AGREE; FIXED.** The reproduction command now points to a real script (`Table2-StudentT-Emissions.jl`) with a note that spy-experiment fitting/tuning happens inside its table/figure scripts (there is no standalone fit script).
- **Downstream README lists 04b before 06 (B) — AGREE; FIXED.** Reordered so `06-VaR-Backtest.jl` runs before `04b-VaR-Table.jl`, with a "must run after 06" note.
- **Top-level README says Table 5 is manual (C) — AGREE; FIXED.** Corrected to state that `04b-VaR-Table.jl` regenerates `table5_var_backtest.tex` from the CSV produced by script 06; no hand editing is required.
- **`Include.jl` does not `Pkg.instantiate()` on a clean checkout (D) — DISAGREE; not changed.** Both files instantiate when `Manifest.toml` is absent; with the pinned manifest committed (as it is), the standard `julia --project=.` workflow resolves and precompiles the pinned environment on first `using`. The described failure mode (manifest present, packages not installed, no instantiate) is not exercised by the documented workflow, and the downstream `Include.jl` additionally calls `Pkg.activate` unconditionally. We regard this as by design, not a defect.
- **"Paired innovation" mismatch (E) — AGREE; FIXED.** We confirmed that `compose_gaussian_sim` draws a fresh Gaussian sample rather than reusing the shared per-ticker innovation, while naive and hybrid are paired. The Results text now states that only the naive and hybrid composers reuse a common innovation draw and that the Gaussian-residual baseline draws its own i.i.d. Gaussian innovations by construction, as a Gaussian baseline must.
- **Automated tests — DEFERRED.** We agree targeted tests (zero-covariance variance recovery, general covariance formula, R^2-branch, clipping/effective-beta, Student-t emission variance, jump-duration counts at K=0/K=1, unconditional-versus-conditioned calibration, no-leakage rolling VaR, drawdown change under the location shift) would strengthen reproducibility. They are not part of this pass.

## PDF and presentation
The revised manuscript builds cleanly at 35 pages with no undefined references and no overfull boxes above 20 pt (the worst overflow the audit noted, ~10-15 pt, is unchanged). We did not address abstract density, dense-table type, or caption/main-text repetition in this pass.

## Summary of dispositions

| Item | Disposition |
|---|---|
| 1 VaR forecast language | AGREE; reworded intro (minimal resolution). Rolling forecast DEFERRED |
| 2 Diversification-return contradiction | AGREE contradiction; reframed serial -> contemporaneous covariance. Diagnostic DEFERRED |
| 3 Drawdown geometry | AGREE; all four sites corrected |
| 4 "Hidden" Markov naming | DECLINED rename (kept HMM, clarified); parameter-count row AGREE, renamed + caption |
| 5 Student-t scale | AGREE math; description fix, no regeneration; DISAGREE regenerate |
| 6 Jump-duration off-by-one | PARTIAL: code correct, pseudocode fixed |
| 7 Path-selection mismatch | AGREE; disclosed conditioning. Unconditional retune not done (defensible design) |
| 8 Marginal preservation | AGREE; softened to variance/tail |
| 9 KS/AD p-values | AGREE; caveat added |
| 10 Stationary init | AGREE; described as approximation |
| Combined superiority | AGREE; Pareto tradeoff |
| Jump-diffusion term | DECLINED rename; in-text clarification added |
| i.i.d. floor | AGREE; fixed contradictory site |
| Volatility-clustering / jumps-off | AGREE; already disclosed |
| Narrative restructure / demote arc | DECLINED demotion; reconciled + softened instead. Larger restructure out of scope |
| README A/B/C, paired-innovation E | AGREE; fixed |
| Include.jl instantiate (D) | DISAGREE; by design |
| Tests | DEFERRED |

## What we deliberately did not do, and why
1. **No rolling VaR forecast.** We chose the audit's minimal resolution (honest relabeling) over building an expanding-window forecast; the exercise is now described as what it is.
2. **No residual-covariance experiment / allocator re-run.** We named contemporaneous cross-asset covariance as the plausible dominant mechanism and flagged it as unquantified rather than asserting a mechanism we have not measured.
3. **No rename away from "HMM" or "jump-diffusion."** Genuine latent state in the simulator, disclosed deterministic training encoding, and arXiv/title continuity; technical caveats added in the body instead.
4. **No Student-t regeneration.** The scaling is self-consistent with the `ν = 5` selection and the passing marginal fits; a description fix suffices.
5. **No unconditional retune of the jump objective, no automated test suite, no main-text restructure, no abstract trim.** Acknowledged as reasonable; out of scope for a claims-accuracy pass.

---

# Follow-up Audit of the Author Response (2026-07-13)

## Overall assessment

The author response is thoughtful and materially improves the paper. In particular, it correctly distinguishes defects in the implementation from defects in the manuscript and pseudocode. The revisions make the paper substantially safer around the VaR language, drawdown claims, Student-t parameterization, marginal-preservation language, statistical uncertainty, and reproduction instructions.

The revision is not fully complete, however. Four targeted manuscript corrections remain, and the jump-calibration procedure is still the main substantive risk to the headline contribution.

## Highest-priority remaining issue: jump calibration

Disclosing that the calibration objective is conditioned on jump-active paths is honest, but disclosure does not resolve the statistical issue.

Once paths without a jump are discarded, the principal effect of \(\epsilon\)—how frequently jumps occur in the unconditional generator—is largely removed from the objective. The conditional objective mainly evaluates what paths look like given that at least one jump occurred. It therefore cannot cleanly calibrate the unconditional event probability that \(\epsilon\) is intended to represent.

This matters because:

- the selected \(\epsilon=10^{-4}\) is at the lower boundary of the grid;
- approximately 76% of 2,766-day paths contain no jumps;
- the probability of a jump is smaller still over a 249-day holdout horizon; and
- the headline model evaluation is unconditional while calibration is conditional.

The manuscript's rationale that jumpless paths “carry no information about \((\epsilon,\lambda)\)” is only partly correct. Jumpless paths carry direct information about \(\epsilon\), because their frequency is governed by it.

Recommended alternatives:

1. Calibrate \(\epsilon\) from an empirical tail-episode frequency and \(\lambda\) from empirical episode durations.
2. Include all paths in an unconditional ACF/kurtosis objective.
3. Use a two-part objective such as
   \[
   J = J_{\mathrm{conditional\ shape}}
   + w_p\left(p_{\mathrm{jump,obs}}-p_{\mathrm{jump,sim}}\right)^2.
   \]

Without one of these changes, a reviewer can reasonably argue that \(\epsilon\) is weakly identified and that the operating point was selected under an objective different from the unconditional generator being evaluated.

## Cross-sectional covariance remains a hypothesis rather than an established mechanism

The correction from serial dependence to contemporaneous cross-asset dependence is conceptually much better. However, the manuscript now states the new explanation too definitively. For example, the appendix says that “the synthetic \(D_\epsilon\) is inflated relative to the market,” even though the real-versus-synthetic residual covariance contribution has not been measured.

The proposed mechanism is plausible and likely important, but the current experiment does not establish how much of the approximately 22-percentage-point gap it explains. Until the diagnostic and allocator rerun are performed, statements such as “is inflated” should be softened to something like:

> The synthetic idiosyncratic diversification term is expected to be inflated when real residual covariance is positive; quantifying that contribution requires a joint-residual experiment.

Two older inconsistencies also remain:

- [`jfds-paper/sections/related.tex`](jfds-paper/sections/related.tex), around lines 106–110, still attributes the diversification-return difference to residual serial dependence.
- [`jfds-paper/sections/abstract.tex`](jfds-paper/sections/abstract.tex), around lines 31–33, says “i.i.d. residuals” without distinguishing independence across time from independence across assets.

### Per-ticker bootstrap and GARCH do not restore cross-asset dependence

The revised discussion says the block-bootstrap and GARCH alternatives “restore residual dependence directly.” Their implementations fit or resample each ticker separately. In particular, `Pipeline.jl` constructs a separate residual series and separate random-number stream for each ticker:

- [`code/downstream-evaluation/src/Pipeline.jl`](code/downstream-evaluation/src/Pipeline.jl), around lines 227 and 255–258;
- [`code/downstream-evaluation/src/Composers.jl`](code/downstream-evaluation/src/Composers.jl), around lines 124–151.

These alternatives can preserve a ticker's own temporal structure, but they do not restore contemporaneous cross-asset residual covariance. Similarly, [`jfds-paper/sections/appendix.tex`](jfds-paper/sections/appendix.tex), around lines 530–533, says that the residual block bootstrap preserves temporal and cross-sectional structure “by construction.” The per-ticker bootstrap used here does not preserve the cross-sectional structure.

Recommended correction:

- Say that the per-ticker block bootstrap and GARCH models restore **univariate temporal dependence** only.
- Reserve claims about cross-asset dependence for a joint/aligned block bootstrap, residual copula, or residual factor model.

## Algorithm 1 still does not match the simulator

The author response is correct that the underlying simulator emits exactly \(K\) forced observations and treats \(K=0\) as a normal transition. However, the revised pseudocode still differs from the implementation in two ways.

### Horizon truncation remains incorrect

The revised counter is

\[
k \gets \min(K,T-t)-1.
\]

After emitting the current forced observation, the correct number of remaining forced observations is

\[
k \gets \min(K-1,T-t).
\]

The current expression can become negative at the final step and truncates an episode one step too aggressively near the horizon.

### Tail sign is selected differently

The pseudocode chooses the negative or positive tail set once and retains that choice for the entire episode. The implemented simulator chooses the sign independently at every forced step. In the installed `JumpHMM` source, `rand() < p_neg` appears inside the loop over `1:K`.

Consequently, one implemented jump episode can alternate between positive and negative tail states, while Algorithm 1 describes a fixed-sign episode. This does not eliminate the absolute-return clustering mechanism, but it changes the interpretation of an episode and the gain/loss-asymmetry parameter.

Recommended resolution:

- Easiest: update Algorithm 1 so each forced step independently selects \(\mathcal S_-\) with probability \(p_{\rm neg}\) and \(\mathcal S_+\) otherwise, matching the results already generated.
- Alternative: change the simulator to select the sign once per episode, then regenerate all affected results.

## The “Free parameters” row remains misleading

Renaming “Parameters estimated” to “Free parameters” does not make the comparison valid. Transition probabilities, partition quantities, and state-specific emission moments are fitted quantities and are parameters of the state model even when they are estimated by direct plug-in counting.

The caption now explicitly discloses that most HMM/HSMM fitted quantities are excluded while the full GRU weight vector is included. That makes the asymmetry visible but does not make the values comparable. The displayed contrast—two or four versus 37,954—can still be read as rhetorical rather than scientific.

Recommended resolution:

- Preferred: remove the row.
- Alternative: report separate quantities for “tuned hyperparameters,” “plug-in fitted quantities,” and “total trained weights,” without implying direct equivalence across model families.

## VaR terminology should be corrected consistently

The revised Introduction accurately describes the exercise as an unconditional coverage check, but “VaR backtest” remains in several prominent locations, including:

- [`jfds-paper/sections/results.tex`](jfds-paper/sections/results.tex), around lines 322 and 342–358;
- [`jfds-paper/sections/conclusion.tex`](jfds-paper/sections/conclusion.tex), around lines 30–35;
- [`jfds-paper/Paper_v1.tex`](jfds-paper/Paper_v1.tex), in the keywords and code-availability language.

Because the experiment does not produce a sequence of ex ante forecasts, “unconditional VaR coverage check” is the more precise term and should be applied consistently throughout the manuscript.

The phrase “statistically indistinguishable” should also be avoided unless a direct paired comparison, equivalence test, or formal test of the difference was performed. Similar exceedance and Kupiec pass rates alone do not establish statistical indistinguishability.

## Julia environment instantiation remains a factual reproducibility issue

The author response marks the environment-instantiation finding as “DISAGREE,” but a committed `Manifest.toml` does not cause Julia to download missing packages automatically on first `using`. On a clean machine, activating a project and importing a dependency can fail if the project has not been instantiated.

This does not require calling `Pkg.instantiate()` inside every experiment script. The conventional fix is to add an explicit setup command to each project's README, for example:

```bash
julia --project=code/downstream-evaluation \
  -e 'using Pkg; Pkg.instantiate()'
```

The same pattern should be documented for the other self-contained Julia projects. After that one-time setup, the numbered scripts can run normally.

## Lower-priority judgment calls

### Student-t scaling

The response is defensible. The model was tuned and evaluated under the implemented scaling, and the revised manuscript now explains the induced conditional variance transparently. Regeneration is not mandatory if the scale choice is treated as a deliberate phenomenological parameterization rather than an empirical conditional standard deviation.

### HMM terminology

Keeping “HMM” is defensible if the deterministic training encoding and simulated latent state are distinguished clearly. The manuscript should avoid implying conventional latent-state maximum-likelihood estimation.

### “Jump-diffusion” terminology

Keeping “jump-diffusion” is harder to defend. The revised Methods explicitly says that the model has no continuous-time diffusion component, while the title continues to call it jump-diffusion. That can read as an acknowledgment that the title is technically inaccurate. ArXiv continuity is not a strong scientific reason because titles can change between versions.

### Stationary initialization

Describing the base-chain stationary distribution as an approximation is appropriate. However, the claims that the discrepancy affects only “the first few steps” and is “negligible” have not been demonstrated. A safer sentence is:

> This initialization introduces a small, unquantified transient because it is stationary for the base chain rather than the augmented jump process.

### Layout threshold

The response notes that there are no overfull boxes above 20 pt, while the original audit identified overflows of roughly 10–15 pt. Those overflows therefore remain. They are not a major scientific issue, but the stated threshold does not constitute a fix.

## Successful revisions

The following changes respond well to the original audit:

- the Introduction now describes the VaR exercise honestly;
- drawdown-preservation claims were removed;
- the Student-t scale and induced conditional standard deviation are disclosed;
- “marginal preservation” was narrowed to variance and tail-character retention;
- the KS/AD independence caveat and Monte Carlo-versus-fit uncertainty distinction were added;
- the conclusion now presents a Pareto tradeoff rather than undefined combined superiority;
- stale reproduction commands and Table 5 ordering were corrected; and
- the paired-innovation description now matches the Gaussian implementation.

## Recommended next revision pass

Before submission, make these four targeted corrections:

1. Fix Algorithm 1's horizon counter and per-step tail-sign selection.
2. Remove or redesign the “Free parameters” row.
3. Replace remaining “VaR backtest” terminology with “unconditional VaR coverage check.”
4. Treat contemporaneous residual covariance as an untested hypothesis and correct claims that independent per-ticker block-bootstrap/GARCH fits restore cross-asset dependence.

The one substantive experiment most worth considering is a proper calibration of \(\epsilon\). This is the remaining issue most likely to affect the core headline result rather than merely its wording.

## Follow-up bottom line

The claims-accuracy revision was worthwhile and resolved most of the original audit's presentation problems. The paper is now considerably more credible. Its main unresolved technical vulnerability is that the event-frequency parameter \(\epsilon\) is tuned using an objective conditioned on the event having occurred, while the model is evaluated unconditionally. The main remaining manuscript vulnerability is that the newly proposed contemporaneous-covariance explanation is stated as established even though the relevant joint-residual diagnostic has not yet been run.
