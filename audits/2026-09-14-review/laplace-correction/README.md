# Laplace estimator correction — 14 September 2026

**The estimator is corrected in both production scripts. A paired rerun shows a large improvement in distribution-test pass rates, including on the 2025 holdout. Kurtosis and temporal fit remain essentially unchanged.**

Changed files: [Baseline-Comparison.jl](../../../code/baseline-comparison/Baseline-Comparison.jl) and [Table2-StudentT-Emissions.jl](../../../code/spy-experiment/Table2-StudentT-Emissions.jl). Both now use `fit_mle(Laplace, insample_obs)` and sample from that fitted distribution. The Gaussian estimator is unchanged.

## Experiment

The Laplace distribution is fitted once to the 2,766 training returns (2014–2024), then held fixed for both windows. The holdout contains 249 returns from 2025. Both cached observation vectors were checked for exact equality against the package’s raw SPY VWAP data with the production risk-free rates and time step.

Old location/scale: **0.06310027 / 1.45824311**. Corrected location/scale: **0.14192448 / 1.45611913**. The location equals the sample median; the scale equals the mean absolute deviation about that median. Training log likelihood improves by 4.031708.

Each old/corrected pair uses the same 1,000 uniform paths, transformed through the corresponding Laplace quantile functions. The production metric functions are loaded directly without running unrelated models or changing their caches. Both Table 2 metric implementations agree on a common check input. There are 500 bootstrap replications with identical resampling seeds for old/corrected fits.

Values below are estimate (standard error). The published column is copied from the current manuscript for context; the old/corrected rerun columns use a new controlled random stream. Small differences between the published and old-rerun columns are therefore expected.

## Training: 2014–2024

| Metric | Published Laplace | Old fit, rerun | Corrected MLE |
|---|---:|---:|---:|
| KS pass (%) | 44.0 (1.6) | 42.1 (1.6) | 98.4 (0.4) |
| AD pass (%) | 43.3 (1.6) | 44.3 (1.6) | 96.8 (0.6) |
| Excess kurtosis | 3.0 (0.02) | 3.0 (0.02) | 3.0 (0.02) |
| ACF-MAE | 0.060 (<0.001) | 0.060 (0.000035) | 0.060 (0.000035) |
| Quantile-envelope coverage (%) | 37.4 (1.5) | 35.4 (1.1) | 78.8 (1.0) |
| Wasserstein-1 | 0.138 (0.001) | 0.136 (0.000638) | 0.119 (0.000670) |
| Hellinger distance | 0.072 (<0.001) | 0.072 (0.000188) | 0.069 (0.000184) |

## Holdout: 2025

| Metric | Published Laplace | Old fit, rerun | Corrected MLE |
|---|---:|---:|---:|
| KS pass (%) | 88.0 (1.0) | 87.9 (1.0) | 96.7 (0.6) |
| AD pass (%) | 92.9 (0.8) | 92.5 (0.8) | 98.1 (0.4) |
| Excess kurtosis | 2.7 (0.05) | 2.8 (0.05) | 2.8 (0.05) |
| ACF-MAE | 0.043 (<0.001) | 0.043 (0.000082) | 0.043 (0.000081) |
| Quantile-envelope coverage (%) | 74.7 (1.0) | 75.8 (2.5) | 99.0 (0.4) |
| Wasserstein-1 | 0.263 (0.002) | 0.268 (0.001963) | 0.242 (0.001747) |
| Hellinger distance | 0.211 (0.001) | 0.211 (0.000644) | 0.207 (0.000648) |

## Consequences for the paper

- Training KS rises from 42.1% to 98.4%; training AD rises from 44.3% to 96.8%. The original large distribution-test gap between Laplace and the HMM models is substantially reduced.
- Holdout KS rises from 87.9% to 96.7%, and AD from 92.5% to 98.1%. The corrected holdout Wasserstein-1 value is 0.242, below the currently reported HMM-NJ/WJ values of 0.259/0.275. These compare the new Laplace run with existing HMM rows; the other models were not rerun and no significance of their ranking was established.
- Corrected kurtosis is 2.981 in training and 2.759 in the holdout, versus observed values 7.715 and 6.867. Laplace still misses the observed fourth moment. Kurtosis is invariant under the paired affine change, so the identical old/corrected values are expected.
- ACF-MAE remains approximately 0.060 in training and 0.043 in the holdout. The independent Laplace draws still do not reproduce volatility clustering. Novelty and diversity also remain unchanged; their complete results are in the CSV.
- The Results sentence claiming the HMM variants gave the strongest overall distributional fit should be replaced with a metric-specific comparison when integrating this correction. The HMM models retain advantages on some metrics, including training Wasserstein-1 and observed-kurtosis recovery; the corrected Laplace benchmark is competitive on several marginal-fit diagnostics.

This experiment deliberately retains the current metric definitions, including the existing Hellinger binning and the KS/AD conventions. It isolates the Laplace-estimator correction and does not close the separate metric audit findings. Quantile-envelope coverage here is the Table 2 metric, not VaR coverage.

## Reproduction and artifacts

Run from the repository root:

```sh
julia --compiled-modules=existing --threads=4 --project=code/baseline-comparison audits/2026-09-14-review/laplace-correction/compare_laplace.jl
```

- [Run log](run.log): all checks and results.
- [Comparison CSV](comparison.csv): estimates, standard errors, and changes for all nine metrics in both windows.
- [Saved Julia results](results.jld2) and [metadata](metadata.toml): numerical output, seeds, environment versions, and input/source hashes.
- [Original Table 2](table2_before.tex) and [replacement Table 2 draft](table2_laplace_mle.tex): corrected Laplace rows with best-value highlighting recomputed at displayed precision; other model numbers are retained.
- [Checks](checks.json): verification record.

The production code fix and numerical comparison are complete. After author agreement, the corrected Laplace rows and metric-specific Results comparison were integrated into both arXiv and JFDS on 14 September 2026. Both manuscripts were rebuilt. The original table snapshot and experiment results remain unchanged.
