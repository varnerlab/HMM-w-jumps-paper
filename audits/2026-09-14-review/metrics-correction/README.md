# R8: metric definitions and GRU reproduction

Completed 15 September 2026. Both manuscripts now define the Table 2 metrics,
their uncertainty calculations, and the GRU benchmark. A complete GRU retraining
and regeneration reproduced both original path CSVs byte for byte. Table 2's
16 numerical rows are unchanged in both versions.

## Metric definitions and interpretation

The active Online Appendix S3 now specifies the implementations used by the
stored evaluators, with matching Methods, Results, table notes, and captions.

| Quantity | Implemented calculation |
|---|---|
| KS and AD pass percentage | Fraction of complete simulated paths with two-sample p-value greater than 0.05, multiplied by 100; approximate KS and modified, tie-aware AD with asymptotic p-values |
| Wasserstein-1 distance | Mean absolute difference between equal-length sorted samples, in growth-rate units of inverse years |
| Histogram Hellinger score | 50 equal-width bins spanning the pooled observed/simulated samples, with the original endpoint convention described below |
| Excess kurtosis | Fourth central population moment divided by squared second central population moment, minus three; no finite-sample bias correction |
| Quantile-envelope coverage | Percentage of the 99 observed quantiles at levels 0.01 through 0.99 lying within the inclusive 5th–95th percentile envelope of corresponding simulated quantiles; type-7 interpolation |
| Absolute-return ACF | Full-series centering, overlapping lag-product numerator, and full-series squared-deviation denominator; lag zero omitted |
| Hill tail index | Upper 5% of absolute returns, with the kth ordered value as threshold and the mean log ratio of the first k−1 exceedances |

The two autocorrelation error summaries are now given separately:

- Table 2 averages the simulated ACF curves before taking absolute differences
  from the observed curve. It uses lags 1–252 for the 2,766-observation training
  series and 1–248 for the 249-observation holdout. The state-resolution and
  emission comparisons use the same convention.
- Table 6 computes each path's ACF error first, then averages across paths and
  assets. It uses 25- and 60-lag limits in both windows. The fallback control
  uses this path-level convention at 25 lags.

Even at a common lag limit and on the same paths, averaging curves can cancel
errors with opposite signs. The ensemble-curve error cannot exceed the mean
path error. The manuscripts therefore explicitly limit comparisons of the
scores across experiments. The diagnostic
[ACF results](gru-rerun-metrics/acf-estimands.csv) record both conventions at
25, 60, and the full evaluation lag limit. For the regenerated GRU paths, the
252-lag training scores are 0.0356583 and 0.0421562 respectively; the 248-lag
holdout scores are 0.0327610 and 0.0493696.

The stored histogram code excludes observations equal to the pooled maximum:
every bin is lower-inclusive and upper-exclusive, including the final bin.
Counts are divided by the original sample lengths, so bin weights can sum to
less than one. This existing convention is now disclosed as part of the
histogram approximation; the evaluator and reported scores were retained.

## Uncertainty and Figure 3

The Table 2 standard errors describe simulation uncertainty conditional on one
fitted model and observed history:

- Pass percentages use the binomial standard error, in percentage points.
  A zero estimate when every simulated path passes or fails does not establish
  an underlying probability of exactly one or zero.
- Mean kurtosis, Wasserstein distance, and Hellinger score use the sample
  standard deviation across 1,000 path scores divided by the square root of
  1,000.
- Ensemble ACF error and quantile-envelope coverage use 500 bootstrap resamples
  of 1,000 complete path indices with replacement. Every resample recomputes
  the curve or quantile envelopes. The standard error is the standard deviation
  of these 500 statistics, without another square-root divisor.
- Multi-asset jump contrasts retain the replication-level cross-asset mean as
  the unit, preserving the shared market draw when calculating paired errors.

The text distinguishes descriptive distribution-test nonrejection from evidence
of equivalence, and quantile-envelope agreement from daily VaR exceedance or
simultaneous confidence coverage. These errors do not quantify fitting,
model-selection, or historical-regime uncertainty.

The Figure 3 caption now identifies its mean ACF curves, 10th–90th percentile
bands across paths, the jump-active subset used by the solid HMM-WJ curve and
band, and the all-path dashed HMM-WJ curve. It also identifies the horizontal
dotted lines as white-noise reference levels. Figure assets, including the
accepted Figure 4 with outlined circles, are unchanged by R8.

## Recovered GRU reproducibility

The repository search, including ignored files and Git history, found the
training script and generated paths but no original saved weights or training
log. The original script does not save a checkpoint. The author authorized a
rerun if those artifacts could not be found.

The [original training script](../../../code/baseline-comparison/neural-baseline/train_gru.py)
is unchanged. A new
[reproduction wrapper](../../../code/baseline-comparison/neural-baseline/reproduce_gru.py)
records weights, normalization, epoch losses, environment, random-number state,
and source/input/output hashes. It invokes the original model and scalar path
sampler. Parallel workers receive the NumPy state for their original serial
path position. A one-epoch comparison required identical weights from the
original and instrumented training loops, and serial/parallel generation parity
passed before the full generation.

The model uses two 64-unit GRU layers, dropout probability 0.1 during training,
and separate linear mean and log-variance heads: 37,954 trainable parameters.
It predicts the next standardized SPY growth rate from a 50-value input window.
Normalization uses only the training series. The Gaussian likelihood loss,
Adam settings, batch construction, learning-rate schedule, weight selection,
and rolling Gaussian sampler are documented in Online Appendix S3.1 and the
[benchmark README](../../../code/baseline-comparison/neural-baseline/README.md).

The full CPU run used Python 3.14.2, PyTorch 2.10.0, NumPy 2.4.3, and SciPy
1.17.1, with 24 training threads and 12 single-thread generation workers.
Direct and complete runtime dependencies are pinned. With seed 1234, training
completed 200 epochs and selected epoch 199, whose mean training loss was
−0.06385544408112764. Selection used training loss, with no validation split.

Saved artifacts are in
[saved-runs/r8-20260915](../../../code/baseline-comparison/neural-baseline/saved-runs/r8-20260915/):

- [Checkpoint](../../../code/baseline-comparison/neural-baseline/saved-runs/r8-20260915/checkpoint.pt)
- [Selected weights](../../../code/baseline-comparison/neural-baseline/saved-runs/r8-20260915/best-weights.pt)
- [Epoch log](../../../code/baseline-comparison/neural-baseline/saved-runs/r8-20260915/epochs.jsonl)
- [Run metadata](../../../code/baseline-comparison/neural-baseline/saved-runs/r8-20260915/metadata.json)
- [Full console log](gru-training.log)

Both original path files were exactly reproduced:

| Window | Output shape | Comparison |
|---|---|---|
| Training | 2,766 observations × 1,000 paths | Identical file bytes and all values |
| Holdout | 249 observations × 1,000 paths | Identical file bytes and all values |

All 3,015,000 generated values match, with maximum absolute difference zero.
The [comparison record](gru-path-comparison.json) includes both SHA-256 hashes.
An independent [checkpoint check](gru-checkpoint-verification.json) reloaded
the saved weights and reproduced three full-length serial paths from each
window, including the original random-number advancement through all training
paths before the holdout.

The successful one-epoch check is recorded in
[gru-smoke-verified/metadata.json](gru-smoke-verified/metadata.json).
The full-run metadata's `original_loop_smoke_parity: false` means that the
optional smoke comparison was not repeated inside the full run; the separate
successful smoke record has this field set to true. The earlier `gru-smoke`
directory/log records an unsuccessful shared-memory transport attempt, before
workers were changed to load the saved checkpoint from disk.

## Verification and manuscript outputs

The [metric checker](verify_metrics.jl) loads definitions directly from the
original Julia evaluators and checks their agreement, observed-data exports,
ACF centering/normalization, both orders of averaging, histogram endpoint
behavior, coverage, and standard-error calculations. The final run used the
newly regenerated GRU paths; its authoritative results are in
[gru-rerun-metrics](gru-rerun-metrics/), with a
[successful log](gru-rerun-metrics.log). Earlier root-level metric outputs
retain the initial check against the original CSVs.

The [table check](table-verification.json) verified all 56 printed GRU means
and standard errors across both manuscript versions. All 16 Table 2 numerical
rows remain identical to their pre-R8 versions. Frozen scoring/training
sources and the canonical multi-asset inputs, fits, and scores also retain
their recorded hashes.

Both builds passed: `make -C arxiv-paper pdf` and `make -C jfds-paper all`.
The arXiv manuscript has 53 pages; the JFDS main manuscript has 31, and its
supplement has 41. Online Appendix S3 starts on arXiv page 28 and supplement
page 6; the GRU subsection starts on arXiv page 31 and supplement page 8.
Table 2 remains on arXiv page 19 and JFDS page 17. Figure 4 remains on arXiv
page 24 and JFDS page 19.

Contact sheets covering all pages and 12 detail renders at 120 dpi were
inspected. The revised equations, table notes, and captions fit without new
clipping, overlaps, or isolated single-line paragraph fragments. Final logs
contain no undefined or duplicate references; the arXiv build has no overfull
boxes, and the four pre-existing JFDS width warnings remain. Installed JFDS
PDFs match the built files. [Final verification](verification.json) records
hashes, labels, page counts, and inspection coverage.

This reproduction authenticates the stored GRU outputs for the recorded CPU
environment and seed. It does not establish robustness across training seeds
or neural architectures. R9–R11 and the additional audit follow-ups remain
open. Changes are local and uncommitted; final release archives have not been
regenerated.
