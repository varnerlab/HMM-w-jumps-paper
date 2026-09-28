# Review correction status

Updated 15 September 2026 after the metric definitions and GRU reproduction correction. The review itself
and both Fable verification rounds are complete. Eight ranked corrections
are now implemented and checked in both manuscript versions.

| Ranked item | Finding | Status |
|---|---|---|
| 1 | R6: Laplace estimator | Complete; corrected and rerun |
| 2 | R1: realized-path centering | Complete under the author's retained-construction choice; scope qualified and equivalent-centering control added |
| 3 | R3: GARCH fit acceptance | Complete; original 393 eligible fits recovered exactly |
| 4 | R5: short-path VaR thresholds | Complete under the author's pooled-threshold choice |
| 5 | R2: canonical training cache | Complete; all 250,800 scores reproduced and tables reconciled |
| 6 | R4: Figure 4 denominator and aggregation | Complete; per-draw generator denominators, tracker distinction, corrected reference, and path-error quantiles |
| 7 | R7: emission and transition fallbacks | Complete under the author's retained-fit policy; exact rules, 39-asset inventory, and paired sensitivity added |
| 8 | R8: metrics, ACF estimands, uncertainty, and GRU reproducibility | Complete; definitions synchronized, 252/248 lag limits corrected, full GRU rerun reproduces both original path files byte for byte, checkpoint and log saved |

The latest correction is documented in [the metrics and GRU report](metrics-correction/README.md),
with [checkpoint checks](metrics-correction/gru-checkpoint-verification.json),
[table checks](metrics-correction/table-verification.json), and
[final build/visual verification](metrics-correction/verification.json).
The arXiv manuscript has 53 pages, the JFDS main manuscript has 31, and its
supplement has 41. Metric definitions start on arXiv page 28 and supplement
page 6; the GRU subsection starts on arXiv page 31 and supplement page 8.
Tables S17/S18 are now on arXiv pages 52/53 and supplement pages 38/40;
their correction is documented in [the fallback report](fallback-correction/README.md).
Figure 4 remains on arXiv page 24 and JFDS page 19; its correction
is documented in [the Figure 4 report](figure4-correction/README.md).

## Remaining named findings

- R9: finish the mean-preservation qualification under clipping.
- R10: Kupiec boundary likelihood helper in legacy diagnostics. The
  primary pooled VaR table no longer uses the helper.
- R11: scope and evidence of the synthetic-tracker validation.

R9 is the next remaining named finding. The additional scientific and
presentation follow-ups in [the original audit](REVIEW.md) also need final
triage. Figure 4 now quantifies path-level variance error for the original
training experiment; this does not establish the analogous dispersion for
short holdout or jump-active paths.

All corrections remain local and uncommitted. The arXiv source archive and
JFDS submission package await the final release/reproduction step. Neither
this status nor the completed corrections mark the entire review resolved.
