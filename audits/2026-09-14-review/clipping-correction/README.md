# R9: mean preservation under clipping

Completed 15 September 2026. Both manuscript versions now distinguish
retaining the fitted intercept from preserving the composed asset mean.
The correction documents the existing construction and its limits. Production
composition code, fitted models, generated results, and table values are
unchanged.

## Corrected claim

The composer centers each full-return draw and retains the fitted intercept
in every branch. Its exact sample mean is therefore
`mean(g_i) = alpha_i + beta_eff_i * mean(g_m)`.
Relative to the calibrated linear mean on the same supplied market path,
clipping changes the mean by
`(beta_eff_i - beta_i) * mean(g_m)`.

The clipped branch retains the intercept, generator-variance budget, and
minimum residual variance. It permits the mean to change when reducing the
loading. The shift can be positive or negative, depending on the signs of the
loading and market mean. It vanishes for a zero-mean market path. The tracker
branch retains the original loading, as does the unclipped ordinary branch.

Matching an observed training mean also depends on the supplied market path.
Online Appendix S9 now separates the difference from the observed asset mean
into two terms: a change in market mean under the original loading, plus the
additional effect of clipping. Using observed training SPY without clipping
matches the observed asset mean exactly. A new market path can have a different
mean even when the loading is unchanged. The appendix continues to distinguish
the retained intercept from its finite-sample OLS estimate.

The main Methods, sensitivity Results, Discussion, Conclusion, and appendix
now give the same interpretation. The broad statement that the construction
preserves the composed mean exactly has been replaced by the explicit target
and its conditions.

## Stress transformation

The implemented [market helper](../../../code/downstream-evaluation/src/SyntheticMarket.jl)
uses `mean(g_m) + gamma * (g_m - mean(g_m))`. It preserves the market mean
and multiplies the standard deviation by `gamma`. The sensitivity Results
previously said the entire market path was multiplied by `gamma`; both that
sentence and the Table S9 caption now specify the implemented transformation.
Because this transformation leaves the market mean fixed, the additional
asset-mean shift comes solely from clipping while retaining the intercept.

The historical clipping frequencies in Table S9 are unchanged. This correction
checks the transformation and mean identities; it does not rerun or newly
authenticate the complete historical stress simulation.

## Numerical evidence

[verify_mean.jl](verify_mean.jl) loads the unchanged production composer and
stress helper. All 192 assertions passed, covering:

- 24 combinations of positive, negative, and zero loadings/market means and
  ordinary/tracker branches, including six clipped cases;
- exact path-mean and training-mean identities, intercept/loading recovery on
  orthogonal input paths, and clipped residual/total variance budgets;
- the exact clipping boundary and three mean-preserving stress factors;
- the original audit's random-number schedule and mean-shift example.

The original example gives an observed shift of
`-0.18198511247090104`, matching the analytic identity. Maximum mean-identity
error in the deterministic cases was `4.44e-16`. Results are saved in
[mean-checks.toml](mean-checks.toml) and the [check log](mean-checks.log).
To repeat the check from the repository root:

```sh
julia --startup-file=no audits/2026-09-14-review/clipping-correction/verify_mean.jl
```

The [primary-experiment verification](primary-verification.json) checks the
recorded canonical training and Figure 4 replay hashes. All 42,300 hybrid paths
over 423 assets retained their calibrated loadings: 42,100 ordinary paths,
200 tracker paths, and no clipped paths. Combined with the verified composer
identity, this gives zero clipping-induced mean shift in the primary training
experiment. The check did not regenerate production paths. Canonical training
sources, inputs, fitted models, scores, and the variance replay are unchanged.
All 13 embedded table bodies in the reviewed sources and both Table 2 files
also remain unchanged.

## Manuscript verification

Both builds passed: `make -C arxiv-paper pdf` and `make -C jfds-paper all`.
The arXiv manuscript remains 53 pages, the JFDS manuscript 31 pages, and its
supplement 41 pages. The main clipping explanation is on arXiv page 7 and
JFDS page 11. The exact mean-shift equation is on arXiv page 45 and supplement
page 28; the training-mean decomposition follows on pages 46 and 29. The
revised stress caption is on arXiv page 43 and supplement page 26.

Contact sheets covering every page and nine detail pages at 120 dpi were
inspected. The changed equations, captions, and prose fit without new clipping,
overlap, or isolated single-line paragraph fragments. Final logs contain no
undefined or duplicate references. The arXiv build has no overfull boxes;
the four pre-existing JFDS width warnings remain. Installed JFDS outputs match
the built PDFs. The accepted Figure 4 assets remain unchanged.
[Final verification](verification.json) records hashes, labels, build results,
and visual inspection coverage.

R10 and R11, plus the additional audit follow-ups, remain open. These changes
are local and uncommitted; release archives have not been regenerated.
