**Pre-arXiv scientific and code review, 14 September 2026**

**Recommendation: resolve the six P1 findings below before posting the replacement.** The variance-budget algebra is sound under the stated assumptions, and the saved multi-asset jump comparison is internally consistent. However, the release contains stale training results, a baseline implementation that fails on a fresh run, a materially misspecified Laplace comparison, and two methodological issues affecting the interpretation of simulated paths and VaR coverage. Figure 4 also labels a different variance denominator from the one its code computes.

Reviewed working-tree commit: `2d9c8e5`. The working tree was clean at the start. This review added only this directory; it did not change the manuscript, experiment code, published results, or source archive.

Scope: the active 45-page `arxiv-paper/Paper_v1.pdf`, its complete active LaTeX input tree, the main composition and jump-evaluation pipeline, the pinned JumpHMM simulation/fitting implementation, relevant single-asset/baseline scripts, and saved results. Legacy notebooks and the retired JDIQ manuscript were not treated as the current paper. External checks were targeted to statistical definitions and selected references, not a comprehensive literature or bibliographic audit.

**Priority overview**

| ID | Priority | Finding | Main consequence |
|---|---|---|---|
| R1 | P1 | Centering each realized path eliminates terminal idiosyncratic return variation | These are constrained finite-horizon paths; ordinary cumulative-risk interpretations fail |
| R2 | P1 | Distributed training caches disagree with Table 3 | Published results cannot be regenerated from the advertised cache |
| R3 | P1 | Fresh GARCH fitting caches nonstationary models | The documented six-method reproduction stops during simulation |
| R4 | P1 | Figure 4 computes observed-variance ratios but labels generator-variance ratios | The main variance-preservation exhibit does not measure its stated quantity |
| R5 | P1 | VaR thresholds use only 249 synthetic observations | Coverage errors conflate generator quality with substantial quantile-estimation error |
| R6 | P1 | The Laplace benchmark uses the mean instead of the MLE median | Correcting this changes SPY KS performance dramatically |
| R7 | P2 | Fallback emissions affect 39 of 424 freshly fitted marginals but are not specified in Methods | The implemented generator differs from the stated within-state estimator |
| R8 | P2 | Single-asset ACF scoring and uncertainty are inadequately documented | Readers cannot reconstruct Table 2's estimand from the cited appendix |
| R9 | P2 | Clipping changes the calibrated mean when the market mean is nonzero | The unrestricted mean-preservation conclusion is false in that branch |
| R10 | P2 | Kupiec boundary cases return incorrect p-values | Shorter-window uses can make the wrong rejection decision |
| R11 | P2 | The synthetic-tracker experiment bypasses full-return generation | It validates a restricted algebraic case, not the complete reuse pipeline |

P1 means an issue that should block this release until corrected, rerun, or explicitly resolved by narrowing the method's scope. P2 means a substantive correction or qualification. These priorities are recommendations from this review, not evidence that all empirical conclusions are invalid.

**R1. Realized-path centering removes all terminal residual uncertainty**

Source: [Composers.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/src/Composers.jl:18), especially lines 18-20, 47-51 and 98-124; [Methods](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/method_sim.tex:43), lines 43-55 and 166-171.

For every simulated path, the code subtracts that path's own sample mean. Since the residual scale is constant within the path, it follows exactly that

\[
\sum_{t=1}^{T}\epsilon_i(t)=0,\qquad
\Delta t\sum_{t=1}^{T}g_i(t)
=T\Delta t\alpha_i+\beta_i^{\mathrm{eff}}\Delta t\sum_{t=1}^{T}g_m(t).
\]

Thus, conditional on a market path and an unclipped loading, all asset-specific randomness disappears from terminal cumulative log return. The tracker branch has the same problem. In the clipped branch, the loading can vary between paths, but the residual sum is still exactly zero. With a common market path and fixed loadings, terminal asset returns lie on a single-factor affine relation even if their daily residual variance is large.

The review's 1,000-path reproduction gave terminal residual log-return standard deviations of `6.6e-17` for naive composition and `6.3e-17` for hybrid composition, compared with `0.12165` for a Gaussian residual control with a comparable variance budget. The first two values are numerical zero.

This also forces dependence across residual times: in the elementary iid case, demeaning gives off-diagonal covariance `-sigma²/T`. Moreover, centering and scaling by whole-path statistics make the distribution of an initial segment depend on the requested final horizon. This is not leakage from observed 2025 data, but it is a constraint imposed using the entire synthetic future.

The paper explicitly states that the sample mean is fixed, but does not spell out the resulting loss of cumulative uncertainty. The residual-fit comparators retain random sample means, so their intercept errors and marginal-test behavior are not measured under the same constraint.

**Resolution:** for an ordinary generative time-series model, center using a fitted population mean or a separately estimated generator mean, and assess whether scale parameters should likewise be fixed independently of the realized evaluation path. Then re-evaluate the affected results. Alternatively, explicitly define this as generation conditional on a fixed residual sum and restrict claims accordingly. Add cumulative-return distributions at several horizons and an equal-centering comparison across methods. The present construction should not be presented as preserving ordinary multi-period asset-specific risk.

**R2. The committed training cache is from a different construction than Table 3**

Source: `code/downstream-evaluation/data/results.jld2`, `results-summary.csv`, [the table reader](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/scripts/04-Tables.jl:25), and [Table 3's input](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/tables/table1_aggregate.tex:5).

Independent aggregation of the committed JLD2 gives:

| Quantity | Table 3 | Committed `results.jld2` |
|---|---:|---:|
| Hybrid KS pass | 73.6% | 50.3735% |
| Naive KS pass | 7.1% | 4.4681% |
| Hybrid median intercept error | 0.002 | 0.08305 |
| Naive median intercept error | 0.002 | 0.10213 |
| Hybrid median W1 | 0.249 | 0.27186 |

The residual-fit rows do agree to the table's rounding. This localizes the discrepancy to the changed full-return composition. Fresh fits and the current composer reproduce the expected direction: AAPL's hybrid KS pass rate is 87% over 100 paths, versus 12% in the cached AAPL row; its median intercept error is 0.00151 versus 0.14624. JNJ changes from 80% to 93%, and QQQ from 98% to 100%.

The separate `results-summary.csv` contains only the three older composers, 126,900 rows, and repeats the old hybrid rate. It is described in the README as the source of the manuscript values. `results.jld2` contains six methods and 250,800 rows, but still carries the old naive/hybrid results. Running formatter 04 against the advertised cache will replace the current JFDS table with the old numbers.

This does **not** establish that 73.6% is wrong; the fresh checks and jump-off experiment support that it is plausible. It establishes that the distributed evidence is inconsistent with the manuscript and current code.

**Resolution:** regenerate the canonical training results after resolving the method choices, distribute the matching summaries, and add a source/data/configuration fingerprint plus a table-agreement check. Make figure and table generation update the arXiv tree first and then the JFDS tree. Most current formatters write only to JFDS, despite the active arXiv workflow.

**R3. A fresh GARCH run does not implement the stated stationarity exclusion**

Source: [01c-Fit-GARCH.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/scripts/01c-Fit-GARCH.jl:76), lines 76-92; [Pipeline.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/src/Pipeline.jl:319), lines 319-324 and 494-499.

The fitting script catches exceptions from `ARCHModels.fit`, then immediately stores successful fits. It no longer simulates a trial path or checks persistence before caching. The pinned ARCHModels package permits these fits but rejects their simulation. Three fresh reproductions from the committed OLS residuals show:

| Ticker | Fitting | ARCH+GARCH persistence | Simulation |
|---|---|---:|---|
| ALB | Succeeds | 1.0074237 | `Model is nonstationary.` |
| ALL | Succeeds | 1.0002108 | `Model is nonstationary.` |
| AMAT | Succeeds | 1.0006978 | `Model is nonstationary.` |

These are among the 30 tickers listed in the existing skipped-fit CSV. The later pipeline has no corresponding catch around simulation, so a clean regenerated cache does not reproduce the documented exclusion and the evaluation terminates. Previously generated valid caches can conceal this failure.

**Resolution:** validate coefficient admissibility and finite positive unconditional variance before caching; record excluded tickers and reasons from that same run. Check optimizer convergence as well. Add a regression test using a fit that returns successfully but cannot be simulated. Report that the training GARCH row covers 393 assets, rather than the 423 implied by Table 3's general caption. For comparative rankings, also report all methods on the common GARCH-eligible set.

**R4. Figure 4's generator-variance label disagrees with its calculation**

Source: [05-Figures.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/scripts/05-Figures.jl:45), lines 45, 62-71 and 174-185; [Figure 4 caption](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/main_figures.tex:147).

`sigma²_real` is calculated from observed training returns. `summary.var_rel` is then the median composed variance divided by that observed variance. Panel (b) plots `var_rel`, but its axis and caption identify the denominator as the generator variance. The purported generator-median reference in the theoretical curve is also computed from `sigma²_real`.

Observed variance and generator variance are not interchangeable here. The paper itself derives Student-t emission variance inflation, and fallback emissions introduce another difference for some assets. A plot near one relative to observed variance does not directly verify the intended per-draw generator-variance identity.

**Resolution:** store the actual generator variance for each paired draw and plot the corresponding ratio, with tracker cases identified separately. Alternatively, relabel this as a composed-to-observed variance diagnostic and add a separate generator-target diagnostic. Also correct the caption's aggregation: KS pass rates are fractions, not per-ticker medians, and the current plotted smoothing lines use Gaussian-kernel weighted medians rather than ordinary beta-bin medians. The newer jump experiment correctly records per-draw generator-variance ratios and is a useful implementation reference.

**R5. The VaR experiment includes substantial short-sample threshold bias**

Source: [VaRBacktest.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/src/VaRBacktest.jl:31), lines 31-35; [the holdout scorer](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/src/Pipeline.jl:412), lines 412-427. Related claims: [Results](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/results.tex:170).

Each threshold is the sample quantile of **one 249-day synthetic path**. The 100 replications produce 100 noisy thresholds; averaging their exceedance rates does not turn them into a threshold estimated from 24,900 synthetic observations.

Julia's default quantile uses Hyndman-Fan type 7 interpolation. At probability 0.01 with 249 observations, the quantile lies between order statistics 3 and 4 at rank 3.48. For a uniform population, its exact expected breach probability on a new draw is `3.48 / 250 = 1.392%`, even though the generator is correct. The formula for the interpolation is documented in the [Julia Statistics manual](https://docs.julialang.org/en/v1/stdlib/Statistics/#Statistics.quantile).

A 50,000-replication review experiment evaluated the true CDF at each estimated threshold, eliminating test-sample noise:

| Correctly specified generator | Nominal breach probability | Mean actual breach probability |
|---|---:|---:|
| Uniform | 1% | 1.3948% |
| Normal | 1% | 1.3728% |
| Student-t(5) | 1% | 1.3622% |

Monte Carlo standard errors were approximately 0.0032 percentage points. The Student-t result is a demonstration of the evaluation procedure's bias, **not** a numerical correction that can simply be subtracted from the paper's 1.67%. Its exact contribution for each fitted composer remains to be measured.

Consequently, the reported excess over 1% cannot presently be attributed solely to a generator's tail inadequacy. The same estimation noise affects the Kupiec pass fractions. A wider, variance-inflated naive distribution can appear comparatively well calibrated partly by offsetting this bias. The paper's caution about a short observed holdout does not address the separate and avoidable shortage of synthetic calibration data.

**Resolution:** estimate each frozen generator's unconditional one-day threshold from a sufficiently large independent simulation ensemble, check convergence as that ensemble grows, then evaluate the fixed threshold on 2025. If the intended target is specifically a 249-observation historical-simulation estimator, retain that experiment but identify the target and include a correctly specified null benchmark. Use dependence-aware inference where coverage tests require it. Reassess Table 5 and its interpretation after this change; the present numbers are legitimate outputs of the current procedure, but not isolated measures of generator-tail calibration.

**R6. The Laplace baseline is not fitted by the estimator used elsewhere in the paper**

Source: [Baseline-Comparison.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/baseline-comparison/Baseline-Comparison.jl:262), lines 262-269; the same construction appears in [Table2-StudentT-Emissions.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/spy-experiment/Table2-StudentT-Emissions.jl:238). Compare the correctly derived estimator in [Appendix S4.2](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/appendix.tex:573).

The baseline sets Laplace location to `mean(insample_obs)`. For this SPY sample, that is 0.06310; the MLE location is the median, 0.14192. Its scale is likewise computed about the wrong location. The fitted Laplace partition and descriptive table use the median-based fit, so the manuscript contains two different Laplace specifications without identifying the benchmark discrepancy.

Using the same uniforms for both Laplace specifications, 1,000 newly simulated paths with review seed 20260914 gave:

| Laplace fit | In-sample KS pass |
|---|---:|
| Implemented mean-centered fit | 42.6% |
| Median-based MLE fit | 98.6% |

The first result is consistent with Table 2's reported 44.0% within simulation variability. The second changes the apparent gap between Laplace and the HMM variants. It does not imply that Laplace reproduces kurtosis or volatility clustering; those remain separate criteria.

**Resolution:** use `fit_mle(Laplace, insample_obs)` consistently, rerun both windows and every reported Laplace metric, and regenerate the comparison table. If a mean-matched Laplace distribution is intentional, label it as such and also include the standard MLE comparator. Revisit the claim of strongest distributional fit after the corrected comparison.

**R7. Specify and assess the fallback emissions actually used across assets**

Source: [per-asset fitting](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/src/Pipeline.jl:140) and the pinned dependency's `JumpHMM/src/Emission.jl`, lines 5-30. The paper's estimator is in [method_hmm.tex](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/method_hmm.tex:37).

Freshly fitting all 424 training assets succeeded, but **39 models use at least one fallback emission**. States with fewer than two observations use global moments; states with near-zero within-state standard deviation use the global standard deviation. These are not all empty states: NWS has a fallback state with 119 observations and about 4.30% stationary mass, while F has a 65-observation fallback state and about 2.35% mass across its fallback states.

Replacing a concentrated return state with a distribution on the scale of the entire asset can materially broaden the generated marginal. Methods currently specifies within-state sample standard deviations without this exception. The SPY statement that no fallback was required is correct, but does not describe the multi-asset fits. The N=350 discussion also describes undefined emission parameters even though the library has a defined fallback policy.

**Resolution:** document the exact fallback and zero-count transition-row rules, publish counts and affected stationary mass per ticker, and assess sensitivity for affected assets. Consider a small scale floor or explicit point-mass treatment for tied returns if justified. Do not change that policy without rerunning the relevant results.

**R8. Define the ACF estimand, lag windows, and uncertainty in the active appendix**

Source: [single-asset scoring](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/baseline-comparison/Baseline-Comparison.jl:133), lines 133-176, and [jump scoring](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/src/JumpAblation.jl:35), lines 35-47. See [Table 2's caption and notes](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/tables/table2_model_comparison.tex:3).

Table 2 computes the absolute error of the **ensemble-average ACF**. Table 6 computes each path's ACF error and then averages those errors. These differ by the order of averaging and the absolute value; they are not directly comparable even at a common lag window. Table 2 says ACF-MAE runs through lag 252, but the 249-observation holdout uses lags 1-248. Its cited metric appendix only expands the ACF-MAE acronym; it does not define the calculation, the quantile-envelope coverage statistic, or the promised standard-error calculations.

The code also uses different uncertainty calculations: binomial SE for pass fractions; across-path SE for mean kurtosis and distances; path-resampling bootstrap for ensemble ACF error and coverage. These describe simulation uncertainty conditional on one fitted model and observed history, not sampling uncertainty across historical markets. The main GRU row has no implementation/training specification in the active Methods or appendix.

**Resolution:** write the two estimands explicitly, correct the holdout lag limit, document all Table 2 metrics and SEs, and add a compact GRU specification and reproducible environment. Use common 25- and 60-lag scores for a clean direct temporal comparison if comparing across experiments.

**R9. Mean preservation needs a clipping qualification**

Source: [Composers.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/src/Composers.jl:110), lines 110-124; [Conclusion](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/conclusion.tex:1).

The implementation preserves `alpha`, but replaces `beta` with `beta_eff` when clipped. Its mean is then `alpha + beta_eff*mean(gm)`, differing from the calibrated mean by `(beta_eff-beta)*mean(gm)`. A nonzero-market-mean reproduction gives a shift of -0.181985 annualized growth-rate units, exactly matching that identity. The issue is dormant in the reported primary training branch assignments, but matters for the advertised stress/clipping behavior.

**Resolution:** qualify mean-preservation claims to the unclipped case or adjust the intercept against an explicitly chosen reference market mean. State which target is retained under clipping.

**R10. Correct the Kupiec boundary likelihood**

Source: [VaRBacktest.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/src/VaRBacktest.jl:60), lines 60-68.

For zero or all breaches, the function substitutes a rounded-count heuristic for the likelihood-ratio limit. At zero breaches, 100 observations and 99% VaR, it returns 0, while the likelihood calculation gives 0.1562584. This changes a 5% rejection decision. At the paper's 249 observations and 99% VaR, the correct value is 0.0252732, while the implementation again returns 0; both reject at 5%, so this bug alone does **not** change that published pass fraction. The function's docstring also reverses the null's breach/non-breach probabilities, although its interior implementation uses the correct orientation.

**Resolution:** evaluate the log-likelihood with the limit `0*log(0)=0`, validate probability/sample-size inputs, fix the docstring, and test the boundary cases. The original [Kupiec paper](https://fedinprint.org/item/fedgfe/34596/original) motivates the coverage test; a finite-sample binomial check is also useful for this short holdout, provided its independence assumptions are addressed.

**R11. The tracker grid is an algebra check with Gaussian residuals**

Source: [08-Synthetic-Tracker-Eval.jl](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/code/downstream-evaluation/scripts/08-Synthetic-Tracker-Eval.jl:60), lines 60-83; [Table S6 description](/Users/jdv27/Desktop/julia_work/HMM-w-jumps-paper/arxiv-paper/sections/appendix.tex:1227).

The experiment constructs target returns with Gaussian residuals, then supplies another Gaussian **residual** draw directly to the composer. It sets the alleged generator variance to the target residual variance, making the tracker scale one. It does not fit a full-return HMM to the synthetic tracker, and does not test the nontrivial full-return-to-residual scaling. Both samples also share the same observed market path, which helps explain their 100% KS pass rates.

**Resolution:** identify this as a restricted branch unit check. To claim validation of the full pipeline over the grid, fit full-return marginals to the constructed trackers, simulate new market paths, and test non-unit scaling and the resulting marginal/temporal behavior.

**Additional scientific and presentation corrections**

- **Quantify path-level variance error.** The cross-covariance diagnostic averages signed correlations over 100 replications. Its mean near `1.5e-4` does not describe a typical path's error. The saved full-return diagnostic has median within-ticker path-correlation SD `0.01916`. Report absolute errors or quantiles of the omitted cross term, especially for the 249-day and jump-active paths. The paper correctly qualifies its variance target as asymptotic, but the supporting exhibit should show dispersion as well as cancellation in the mean.
- **Calibrate or narrow jump-incidence claims.** Appendix S4.6 already acknowledges that conditioning the tuning objective on jump-active paths largely removes information about epsilon, whose selected value sits at the lower grid boundary. Main-text statements that calibration selected a balanced one-quarter episode mixture should reflect that limitation. Treat epsilon as a scenario-frequency choice or identify it using an unconditional frequency-sensitive objective; the existing jump-transfer experiment is still a useful conditional comparison.
- **Tighten the long-run arguments.** At appendix lines 243-248, stationarity alone is insufficient for convergence to the unconditional expectation; ergodicity and integrability are required. At lines 318-327, maintaining AR(1) variance while changing persistence does not generally preserve the full marginal law for arbitrary non-Gaussian innovations; either specify Gaussian innovations or restrict the claim to second moments. The final “upper bound” claim at lines 344-346 is not established by a second-order expansion without controlling the remainder. Also qualify the spectral bound at lines 883-897: a general stochastic matrix need not be diagonalizable, and short state dwell times alone do not imply rapid mixing across groups of states. The directly computed SPY spectrum supports the numerical SPY conclusion.
- **Correct the tail-figure interpretation.** Appendix lines 1474-1477 attribute the gap in kurtosis solely to the generator and deny composition distortion. The paper's own Eq. S43 says independent composition changes population excess kurtosis to `kappa_m*rho² + kappa_gen*(1-rho)²`. Plot the uncomposed generator if assigning the observed gap between generator and composition; naive composition is not that control.
- **Use comparable Hellinger bins.** The single-asset scorer at `Baseline-Comparison.jl:118-124` chooses a new range from each observed/synthetic pair. A synthetic outlier can widen bins and make central differences look smaller. The right-open histogram also omits the sample maximum at the last edge, so the declared probability masses do not sum exactly to one. Use a fixed documented grid, explicit overflow bins or another common density estimate, then normalize. This is secondary to fixing the Laplace fit.
- **Expose reproducible analysis provenance.** Include the exact Julia version used for results, not only a broad version recommendation; the current jump settings record 1.12.7 while the manifest was generated under 1.12.6. A `repo-rev="main"` entry is not itself an unpinned dependency when `git-tree-sha1` is committed. Keep that distinction. Make default all-method runs fail clearly when required residual/GARCH caches are absent rather than silently publishing a smaller comparison. Put the correct figure-generation destinations and active figure numbers in the README.
- **Strengthen evidence where it is inexpensive.** Add paired simulation intervals for the main 2025 hybrid-minus-naive difference using the shared market replication as the unit; distinguish these from uncertainty across regimes. Add a fit-time/reuse-time comparison to substantiate the practical advantage of avoiding residual fits. Multiple historical holdouts would strengthen generalization, but no claim of such validation should be added without doing it. Document split/dividend adjustment and the source-universe selection rule; the existing survivorship caveat is appropriate.

**What checked out**

1. The ordinary variance budget, clipping algebra, tracker residual target, conditional transition-count MLE, stationary mixture moments, and rare-episode renewal fraction are consistent with the stated assumptions and inspected implementation. The kurtosis-composition derivation correctly distinguishes fixed population scales from finite-path statistics.
2. The holdout pipeline uses training fits, calibrations and generated SPY paths; inspected code uses observed 2025 returns for scoring. No direct observed-holdout input to fitting or scaling was found. This does not establish when a human selected settings during the research history.
3. All complete histories in each cached raw-data window share identical ordered timestamps, without duplicates; their closing prices are finite and positive. Training has 424 complete assets. The full raw holdout has 473 complete histories before intersection with the training universe. The paper's evaluation uses the appropriate training/holdout intersection.
4. The portable-input test passed **20/20**, including agreement of regenerated prices, growth rates and OLS calibration with the committed inputs. All **424** full-return marginal models also fitted successfully in the independent review.
5. Existing composition tests passed **24/24**. The existing jump-mechanism test bodies passed **31/31** using freshly fitted SPY models in a temporary location. This included agreement of the optimized AD scorer with the pinned reference implementation. The test setup was adapted to avoid depending on the absent per-asset fitted-model cache; assertions were unchanged.
6. Independent CSV aggregation reproduced all 12 jump-summary rows, all 252 paired contrasts and their Monte Carlo SEs. Maximum numerical differences were about `3.6e-14` for summaries and `4.5e-16` for contrasts/SEs. Source, input, configuration and manifest fingerprints checked by `verify_artifacts.py` agree with recorded provenance. The holdout scorecard and VaR summary CSVs also match their table values to displayed precision.
7. The existing arXiv source archive compiled independently with shell escape disabled to **45 pages**. The final LaTeX log has no undefined citations/references, duplicate labels, or overfull-box warnings; the epstopdf shell-escape warning is harmless because the supplied graphics are PDFs. All 45 existing PDF pages were rendered and inspected for gross layout problems. No clipped tables or missing graphics were found, although several tables are dense and page 14 has substantial unused space. Source `.tex`, `.bib`, and `.sty` files in the archive agree with the active tree.
8. The paper appropriately acknowledges complete-case selection, a single holdout year, residual-dependence omissions, poor extreme-tail coverage under its current procedure, and the failure of transferred jumps to improve the 2025 temporal score. Those qualifications should be retained.

**Recommended repair sequence**

1. Decide whether the construction should generate unconstrained paths or paths conditional on a fixed residual sum; resolve R1 and the clipped mean target before regenerating results.
2. Fix GARCH admissibility checks and the Laplace estimator. Specify fallback emissions and all scoring conventions.
3. Recompute training and holdout comparisons, using sufficiently precise VaR thresholds and a common baseline population where appropriate. Save per-draw generator variance and source/configuration fingerprints.
4. Regenerate tables and figures from those outputs, correct Figure 4's denominator, and revise claims that changed. Synchronize arXiv and JFDS content.
5. Run the portable workflow from a checkout without fitted caches, verify every released table against its source summary, build a fresh source archive, and inspect that archive's processed PDF.

**Reproduction files and limits**

The scripts and logs in this directory preserve the review's numerical evidence:

```sh
julia --compiled-modules=existing --project=code/downstream-evaluation audits/2026-09-14-review/reproduce_findings.jl
julia --compiled-modules=existing --project=code/downstream-evaluation audits/2026-09-14-review/garch_probe.jl
julia --compiled-modules=existing --project=code/downstream-evaluation audits/2026-09-14-review/laplace_probe.jl
julia --compiled-modules=existing --project=code/downstream-evaluation audits/2026-09-14-review/data_probe.jl
julia --compiled-modules=existing --project=code/downstream-evaluation audits/2026-09-14-review/jump_tests_fresh.jl
python3 audits/2026-09-14-review/verify_artifacts.py
```

Run from the repository root. The first script regenerates full-return models into `/private/tmp/hmm-review-2026-09-14/`; the data and adapted jump-test probes consume those temporary models. `--compiled-modules=existing` avoids an environment-specific permission error when compiling an uncached ARCHModels package and does not change the tested source. `archive-build.log` records the successful final LaTeX pass. Other `.log` files contain the corresponding numerical output.

This review did not regenerate the entire six-method simulation ensemble, retrain the GRU, repeat all tuning grids, or rerun all multi-million-path jump computations. It independently refitted the full-return universe, reproduced selected composed results, refitted three failing GARCH examples, tested the statistical mechanisms, and re-aggregated available detailed outputs. Missing raw holdout and jump checkpoint archives limit independent trajectory-level verification beyond the saved summaries and targeted reruns. The report provides evidence and a release repair plan; it does not certify the paper as error-free.
