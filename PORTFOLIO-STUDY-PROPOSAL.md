# Proposed follow-on study: rebalancing bias in synthetic-market backtests

**Status:** proposal, 2026-08-31. Material cut from the HMM-w-jumps manuscript
on this date and reserved for a separate paper.

## One-line claim

A synthetic multi-asset generator that matches every asset's marginal
distribution and its factor loading, but draws idiosyncratic residuals
independently across assets, will overstate the return of any rebalanced
portfolio backtested on it, by an amount that is large, derivable in closed
form, and not removable by improving the marginals.

## Why this is a separate paper, not a subsection

The parent manuscript contributes a per-asset generator (HMM-WJ) and a
variance-corrected single-index composition rule. Its evidence is per-asset:
marginal fit, factor recovery, variance preservation, tail coverage. Its own
Discussion says the evidence "supports per-asset variance correction and
distributional evaluation, not portfolio-level dependence fidelity."

The rebalancing result is a portfolio-level claim about how synthetic data is
*used*. It was also run on a different footing from every other experiment in
the parent paper: a 20-ticker allocator portfolio over 336 days with 5,000
paths, against the parent's 423 tickers over the 249 observed 2025 days with
100 replications per ticker. Reported inside the parent, that mismatch invites
a question with no good answer. Reported on its own, the allocator's
configuration is not a mismatch; it is the subject.

The parent keeps the limitation and the derivation that makes it rigorous
(Online Appendix, "Rebalancing under independent residuals"). What moved here
is the measurement and the correction.

## The result

Booth and Fama's decomposition splits a rebalanced portfolio's expected
compound growth into a weighted mean of asset growth rates plus a
*diversification return* set by cross-sectional dispersion. Under a
single-index model with residuals drawn independently across assets, the
dispersion term is inflated: real residuals share sector and style factors,
which reduce the pairwise dispersion below the independent-generator value.
Matching each asset's marginal variance does not restore the covariance, so
the synthetic diversification return exceeds its real-market counterpart.

Measured on a 20-asset long-only target-weight allocator over synthetic 2025:

| Allocation rule | median annualized growth | change from previous row |
|---|---|---|
| Equal-weight buy-and-hold | 7.68% | — |
| Target-weight, static (no rebalance) | 1.97% | −5.71 pp |
| Target-weight, daily rebalanced | 29.69% | **+27.73 pp** |
| Target-weight, daily rebalanced + signal | 29.83% | +0.13 pp |
| *Real 2025 history, same allocator* | *11.50%* | — |

Two readings, both worth publishing:

1. Daily rebalancing on independent residuals produced roughly 28 pp/yr that a
   real portfolio would not have earned. The synthetic median sits about 18 pp
   above the realized 2025 result.
2. The allocation signal contributed 0.13 pp. Essentially all of the apparent
   "engine alpha" on synthetic paths was the rebalancing artifact, not skill.
   Anyone validating an allocation rule on synthetic data of this kind would
   have measured almost entirely their own generator.

Reading 2 is the more useful contribution and should probably lead. It turns a
methodological caveat into a concrete warning about a common practice.

## What must be established, and what is missing

The central attribution is **not yet proven**. The parent paper's appendix is
explicit: quantifying how much of the gap is caused by omitted covariance
"requires a joint-residual experiment with the marginals and the allocation
rule held fixed, which we did not run." Without it, the 28 pp is consistent
with the covariance story but not attributed to it. Confounders already
identified: higher-moment corrections to the Taylor expansion (the JumpHMM
marginals have non-trivial third and fourth cumulants); time-varying
volatility and correlation across the 2014-2024 calibration window; and the
documented attenuation of realized diversification returns at all rebalancing
horizons (Bouchey, Nemtchinov and Wong).

**The experiment this paper needs.** Hold the marginals, the universe, the
allocator, and the rebalancing schedule fixed. Vary only the residual
dependence structure:

1. Independent residuals (the current construction) — the baseline.
2. A synchronized multivariate block bootstrap over the real residual matrix,
   which preserves contemporaneous cross-asset covariance by construction.
3. A residual copula (Gaussian, then Student-t for tail dependence) fitted to
   the real residual correlation matrix.
4. Optionally a residual factor model with sector factors.

If the diversification return collapses toward the real-market value as
residual covariance is restored, the attribution is established and the paper
has its result. If it does not, the confounders are the story instead, which is
also publishable and more interesting than the current framing.

A rebalancing-frequency sweep (daily, weekly, monthly, quarterly) across all
arms should be included: the artifact should scale with rebalancing frequency
in a predictable way, and that scaling is a sharp, falsifiable prediction of
the second-order formula.

## On the location-shift correction

The parent paper carried a correction that subtracts a constant drift in
log-wealth so the ensemble median matches an external long-run prior (8%/yr:
risk-free plus roughly 3.5 pp active premium net of frictions). It preserves
per-path rank order, centered moments of terminal log growth, and the
volatility envelope; it changes the drawdown distribution, so drawdowns were
evaluated on the uncorrected ensemble.

It should be presented here honestly, as a stopgap rather than a fix: it
adjusts the level and does not restore the missing covariance, and it requires
choosing a prior, which is a modeling commitment the rest of the construction
avoids. Alternatives already considered and rejected, worth keeping as a
section because they document the search: path filtering above a growth
threshold (turns the threshold into a tuning target); inflating transaction
costs to absorb the artifact (needs ~70 bps round trip against a 1-10 bps
realistic range, relocating the misrepresentation into the cost model);
parameter drift at 0-5x the OLS standard error (left median Sharpe essentially
unchanged); an AR(1) on the residual draw (conflicts with the copula reorder
step, since reordering destroys temporal structure); per-ticker block
bootstrap (preserves each ticker's temporal structure but not cross-ticker
covariance); and a multiplicative haircut on the raw-versus-static deviation
(hits the target but changes path rank order).

If arm 2 or 3 above works, the correct recommendation is the joint residual
model and the location shift becomes a documented dead end. That is a cleaner
paper than shipping the stopgap as the contribution.

## Provenance and reproducibility

The measurement was **not** produced by the HMM-w-jumps pipeline. It came from
`varnerlab/eCornell-AI-finance-lectures` at commit `6463280` (2026-04-23),
notebook `lectures/session-2/eCornell-AI-Finance-S2-Example-MonteCarloEvaluation-May-2026.ipynb`,
on `code/src/Compute.jl`. See `code/allocator-experiment/README.md` in this
repository, which captures the exact 20-ticker universe, the allocator
configuration, and the reported output, and records what is missing for a
rerun.

The commit pin is load-bearing. Upstream `HEAD` will not reproduce these
numbers: the universe changed from 20 tickers to 22 different names,
`target_growth` went 0.07 to 0.16, `cash_fraction` 0.30 to 0.0, and
`Compute.jl` gained about 1,500 lines.

**Before any of this is written up, the allocator code and the frozen SIM fits
must be vendored into a self-contained repository.** Roughly 180 KB of Julia
(`Compute.jl`, `Types.jl`, `Factory.jl`) plus `sim-parameter-estimates.jld2`
(7.9 MB) and `minvar-allocation.jld2` (25 KB). The market data is already in
`code/downstream-evaluation/data/`. A course repository is not an acceptable
dependency for a journal submission, and the numbers cannot currently be
regenerated by anyone, including us.

## Relationship to the parent paper

Cite it as the source of the generator and the composition rule. The parent's
"Rebalancing under independent residuals" appendix derives the diversification
return for this composition rule and states the limitation; this paper measures
it, attributes it, and proposes the fix. There should be no overlap in claims:
the parent asserts only that the limitation exists and is derivable, and makes
no portfolio-level quantitative claim.

## Suggested venue and framing

Frame as a methods-and-evaluation paper about synthetic financial data rather
than a portfolio-management paper. The audience is people who generate
synthetic market data and validate strategies on it. The title should carry
the warning, not the machinery: the finding is that a standard, careful
synthetic-data construction silently manufactures alpha under rebalancing, and
that the alpha it manufactures dwarfs the signal being tested.

## Open questions

- Does the artifact scale with the number of assets? The dispersion term grows
  with cross-sectional spread, so a 100-asset book should be worse than a
  20-asset one. Cheap to test and a strong result if it holds.
- How much of the effect survives realistic transaction costs and turnover
  caps at each rebalancing frequency?
- Does the same artifact appear in copula-based and multivariate-GARCH
  generators, or is it specific to factor-model residual construction? If it
  generalizes, the paper is considerably more important.
- Is there a diagnostic a practitioner can run on a synthetic dataset, before
  backtesting, that flags the missing covariance? A comparison of synthetic and
  real pairwise residual correlation matrices is the obvious candidate and
  would make the paper actionable.
