# Issue 2: path-centering scope and comparison

Status: the author selected **retain the construction and qualify/test it** on September 14, 2026. The six-method paired control is complete and the qualifications are integrated into both manuscript versions. This is item 2 in the ranked correction list, corresponding to R1 in the original audit. Implementation, results, and validation are recorded in [the correction report](centering-correction/README.md).

## What the implementation does

The naive and hybrid composers subtract each full-return draw's own sample mean. A scalar rescaling leaves the residual sum at zero. With a fixed market path and fixed effective beta, the terminal cumulative log return therefore has no asset-specific residual uncertainty. Daily and intermediate-horizon residual variation remain. In a clipped branch, the effective beta can vary between paths, so terminal returns can also vary through that loading; the residual sum still equals zero.

In the primary training comparison, OLS gives `alpha = observed_asset_mean - beta * observed_market_mean`. Naive and unclipped hybrid paths therefore match the observed asset mean exactly. Residual-fit comparators retain random path means. Their distribution-test and location-error comparisons consequently use different mean constraints. The variance-correction identity itself remains valid under its stated covariance assumption.

Before this correction, the Discussion stated that the evaluation did not validate portfolio-level risk or rebalancing performance, but did not explicitly identify loss of terminal residual uncertainty. The revised manuscript now explains that separate limitation and the horizon dependence of the construction.

## Controlled diagnostic

[centering_probe.jl](centering_probe.jl) refits the no-jump generator for AAPL, JNJ, and QQQ from committed training prices. For each asset and horizon it draws 1,000 paths and compares the production composer with a diagnostic version that subtracts the fitted stationary generator mean. It keeps each path's market, scale, and effective beta fixed. The no-jump stationary mean is the stationary-probability-weighted emission location; it is not asserted to be the jump-process mean.

| Asset | Training hybrid KS, current centering | Training hybrid KS, fitted-mean centering | Median W1, current | Median W1, fitted mean |
|---|---:|---:|---:|---:|
| AAPL | 89.5% | 82.8% | 0.1934 | 0.1984 |
| JNJ | 92.9% | 85.7% | 0.1302 | 0.1334 |
| QQQ | 100.0% | 99.9% | 0.1168 | 0.1181 |

This is a three-asset training sensitivity check, not a full-universe reranking or a matched-centering comparison across all six methods. The differences isolate the mean treatment for these draws. They do not establish its contribution to every reported result.

With a fixed market path over 249 observations, terminal residual log-return standard deviations were:

| Asset | Current hybrid | Fitted-mean diagnostic |
|---|---:|---:|
| AAPL | Numerical zero | 0.2388 |
| JNJ | Numerical zero | 0.1536 |
| QQQ | Numerical zero | 0.0485 |

The 249-observation market is a prefix of the training history, not the 2025 holdout. These are standard deviations in log-return units, not percentage-point losses. Across all checked pairs, daily sample variance changed by at most approximately `2.2e-14`, and recovered beta by less than `7e-16`. No paths clipped. The fitted-mean diagnostic still uses path-dependent scaling; it is not a finished replacement generator with horizon-independent calibration.

Full results: [training CSV](centering_training.csv), [terminal-return CSV](centering_terminal.csv), [run log](centering_probe.log), and [provenance](centering_metadata.toml).

## Decision and resolution

The author selected the first option below. The production centering and scaling remain unchanged. A paired control applied the same zero residual mean to all six methods while holding each draw, effective loading, and scale fixed. On the common 393-asset training set, hybrid's KS pass rate remained 74.4%; JumpHMM-on-residuals rose from 75.8% to 78.4%, and block bootstrap from 73.5% to 76.7%. Both residual-fit comparators also exceeded hybrid's AD pass rate and had lower Wasserstein distance. Hybrid still improved on naive composition, which already used the same centering. The revised claims make this distinction explicit.

The paper now describes constrained finite-horizon paths, gives the terminal cumulative-return identity, qualifies intercept recovery, and includes Supplementary Table S14 with the paired results. This resolves R1 under the selected scientific scope. It does not restore cumulative residual uncertainty or resolve the separate GARCH-admissibility finding.

### Original alternatives

**Retain the current finite-horizon construction.** Explicitly describe the zero residual sum and resulting limit on cumulative-risk interpretation. Qualify interpretation of mean/intercept recovery. Add a comparison that applies equivalent centering to all six methods, retaining the original results as the construction-specific comparison. This preserves the paper's current variance-composition focus. It closes the issue only when the controlled comparison and revised claims agree.

**Change the generator for cumulative-return applications.** Subtract a fitted generator mean rather than each realized path mean. Decide separately how to fix scaling independently of the evaluation path, handle jump-enabled means, and define clipping targets. Validate cumulative residual variability over several horizons and regenerate affected composition tables and figures. This changes the method and has broader downstream consequences.

For the currently stated paper scope, the first choice is a proportionate starting recommendation. The second is appropriate if ordinary cumulative-return simulation is an intended deliverable of this paper. The choice should follow the scientific scope, not whichever version gives a higher KS pass rate.
