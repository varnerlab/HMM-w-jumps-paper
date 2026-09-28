# Review correction status

Updated 15 September 2026 after the Figure 4 correction. The review itself
and both Fable verification rounds are complete. Six ranked corrections
are now implemented and checked in both manuscript versions.

| Ranked item | Finding | Status |
|---|---|---|
| 1 | R6: Laplace estimator | Complete; corrected and rerun |
| 2 | R1: realized-path centering | Complete under the author's retained-construction choice; scope qualified and equivalent-centering control added |
| 3 | R3: GARCH fit acceptance | Complete; original 393 eligible fits recovered exactly |
| 4 | R5: short-path VaR thresholds | Complete under the author's pooled-threshold choice |
| 5 | R2: canonical training cache | Complete; all 250,800 scores reproduced and tables reconciled |
| 6 | R4: Figure 4 denominator and aggregation | Complete; per-draw generator denominators, tracker distinction, corrected reference, and path-error quantiles |

The latest correction is documented in [the Figure 4 report](figure4-correction/README.md),
with [numerical checks](figure4-correction/numerical-checks.json) and
[final build/visual verification](figure4-correction/verification.json).
Figure 4 is on page 24 of the 49-page arXiv manuscript and page 19 of the
30-page JFDS manuscript. The JFDS supplement has 34 pages.

## Remaining named findings

- R7: emission fallback and zero-count transition rules, affected assets,
  and sensitivity assessment.
- R8: metric definitions, ACF estimands and lag windows, uncertainty, and
  GRU specification/reproducible environment.
- R9: finish the mean-preservation qualification under clipping.
- R10: Kupiec boundary likelihood helper in legacy diagnostics. The
  primary pooled VaR table no longer uses the helper.
- R11: scope and evidence of the synthetic-tracker validation.

R7 is the next remaining named finding. The additional scientific and
presentation follow-ups in [the original audit](REVIEW.md) also need final
triage. Figure 4 now quantifies path-level variance error for the original
training experiment; this does not establish the analogous dispersion for
short holdout or jump-active paths.

All corrections remain local and uncommitted. The arXiv source archive and
JFDS submission package await the final release/reproduction step. Neither
this status nor the completed corrections mark the entire review resolved.
