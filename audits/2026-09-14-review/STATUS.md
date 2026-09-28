# Review correction status

Updated 15 September 2026 after the synthetic-tracker scope correction. The review itself
and both Fable verification rounds are complete. All eleven ranked corrections
are now implemented and checked, with manuscript changes synchronized where needed.

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
| 9 | R9: mean preservation under clipping | Complete; retained-intercept policy and exact mean shift documented, stress scaling corrected, no clipping in 42,300 primary hybrid paths |
| 10 | R10: Kupiec boundary likelihood | Complete; likelihood limits and documentation corrected, inputs validated, 807 assertions passed; 40,650 legacy boundary p-values change with no changed 5% decisions at 249 days; current Table 5 unchanged |
| 11 | R11: synthetic-tracker validation scope | Complete by narrowing the grid claim to a Gaussian branch check at unit residual scale; nominal KS interpretation qualified; all 1,500 saved rows and 15 summaries reproduced exactly; 492 assertions passed including separate non-unit scaling checks |

The latest correction is documented in [the tracker report](tracker-correction/README.md),
with [grid replay checks](tracker-correction/grid-checks.toml) and
[build/visual verification](tracker-correction/verification.json).
The revised grid interpretation is on arXiv page 13 and JFDS page 24;
its construction is on arXiv page 40 and supplement page 22, with Table S6
on arXiv page 41 and supplement page 23. Both manuscripts retain the
grid's numerical results while limiting the validation claim to its actual design.

The preceding correction is documented in [the Kupiec report](kupiec-correction/README.md),
with [legacy diagnostic impact](kupiec-correction/legacy-impact.csv) and
[verification](kupiec-correction/verification.json). The current manuscript
does not report Kupiec p-values, so this correction requires no manuscript
or PDF change. The original pooled run provenance is preserved; its table writer
accepts only the explicitly recorded, verified helper correction.

The earlier clipping correction is documented in [the clipping and mean report](clipping-correction/README.md),
with [mean-identity checks](clipping-correction/mean-checks.toml),
[primary-experiment checks](clipping-correction/primary-verification.json), and
[final build/visual verification](clipping-correction/verification.json).
The main clipping explanation is on arXiv page 7 and JFDS page 11;
the exact mean-shift equation is on arXiv page 45 and supplement page 28.
The prior [metrics and GRU report](metrics-correction/README.md) records
the saved checkpoint and exact output reproduction.
The arXiv manuscript has 53 pages, the JFDS main manuscript has 32, and its
supplement has 41. Metric definitions start on arXiv page 28 and supplement
page 6; the GRU subsection starts on arXiv page 31 and supplement page 8.
Tables S17/S18 are now on arXiv pages 52/53 and supplement pages 38/40;
their correction is documented in [the fallback report](fallback-correction/README.md).
Figure 4 remains on arXiv page 24 and JFDS page 19; its correction
is documented in [the Figure 4 report](figure4-correction/README.md).

## Remaining work

The current session handoff is [REVIEW_HANDOFF.md](../../REVIEW_HANDOFF.md)
at the repository root. It lists the four confirmed remaining scientific
corrections, broader follow-ups, and the suggested resumption order.

No ranked finding from R1 through R11 remains open. Several were resolved
by qualifying the retained construction rather than replacing it; their
scientific limits remain part of the manuscript.

The next step is to triage the additional scientific and
presentation follow-ups in [the original audit](REVIEW.md).
Figure 4 now quantifies path-level variance error for the original
training experiment; this does not establish the analogous dispersion for
short holdout or jump-active paths.

All corrections remain local and uncommitted. The arXiv source archive and
JFDS submission package await the final release/reproduction step. Neither
this status nor the completed corrections mark the entire review resolved.
