# Paper review handoff

Saved 15 September 2026.

## Where we stopped

All eleven numbered audit findings, R1–R11, have been addressed at their
recorded scope. Some were resolved by qualifying the retained construction.
The arXiv and JFDS manuscripts are synchronized, rebuilt, and visually checked.
The current PDFs have 53 pages (arXiv), 32 pages (JFDS main), and 41 pages
(JFDS supplement).

The paper is ready for manual reading, but the entire scientific audit is
not complete. The original audit also contained an unnumbered list of
scientific and presentation follow-ups. Four concrete corrections remain
before scientific sign-off. They were checked against the current files
but have not yet been implemented.

All changes remain local and uncommitted. Release archives and submission
packages have not been regenerated for the completed corrections.

## Four substantive corrections to address next

### 1. Qualify the long-run mathematical claims

Current source: [arXiv appendix](arxiv-paper/sections/appendix.tex), with
matching text in the [JFDS appendix](jfds-paper/sections/appendix.tex).

- Near line 244: convergence to the unconditional expectation is asserted
  for any stationary residual process. State the needed ergodicity and
  integrability conditions.
- Near line 322: changing autoregressive persistence while preserving variance
  is said to preserve the entire one-time marginal distribution. Restrict
  the claim to second moments or specify conditions, such as Gaussian
  innovations, that support the stronger statement.
- Near line 345: the synthetic excess is called an upper bound without a
  remainder bound for the second-order approximation. Remove or justify
  that claim.
- Near line 1063: qualify the general eigenvalue-based geometric decay bound
  and distinguish the measured behavior of the fitted SPY transition matrix
  from a universal claim about transition-count models.

Suggested action: correct assumptions and scope in both appendices, preserving
supported numerical SPY results. No new production simulation is implied.

### 2. Narrow the jump-frequency interpretation

Current sources: [Methods](arxiv-paper/sections/method_hmm.tex), near lines
193–201; [Results](arxiv-paper/sections/results.tex), near lines 78–79;
[appendix](arxiv-paper/sections/appendix.tex), near lines 1263–1276.

The tuning objective evaluates only jump-active paths. That conditioning
removes most information about the frequency parameter, epsilon. The appendix
already explains its weak identification and selection at the lower search
boundary, but the Results describe the roughly one-quarter jump-active
mixture as balancing kurtosis and autocorrelation error.

Suggested action: align Methods and Results with the appendix. Distinguish
the observed episode share under the selected settings from evidence that
the objective identified an optimal episode frequency. Preserve the useful
conditional jump comparisons.

### 3. Correct the heavy-tail figure interpretation

Current source: [appendix](arxiv-paper/sections/appendix.tex), the caption
labelled `fig:tails`, near lines 1667–1681. Figure asset:
`figs/supplement/FigS02-Tail-Preservation.pdf` in each manuscript tree.

The caption attributes the kurtosis shortfall to the generator and excludes
composition as a cause. The paper's own kurtosis derivation shows that
composition can change kurtosis. Naive composition is not an uncomposed
generator control.

Suggested action: correct the attribution in both captions. If retaining a
claim that separates generator and composition effects, add the actual
uncomposed generator comparison and verify it from the saved evidence.

### 4. Correct the Hellinger-distance calculation

Current implementation:
[Baseline-Comparison.jl](code/baseline-comparison/Baseline-Comparison.jl),
the `hellinger` function near line 118.

- Each observed/simulated comparison chooses its own histogram range, so an
  outlier can change the bins and the apparent difference between distributions.
- The existing endpoint convention excludes the maximum, so histogram masses
  divided by the original sample counts do not necessarily sum to one.
- R8 documented this convention but deliberately retained the calculation
  and its reported values. This correction remains open.

Suggested action: select and document a common binning protocol, include all
observations, normalize the distributions, and rescore the affected Hellinger
results. Trace every scorer and table that uses the metric. Prefer existing
saved paths; changing the metric does not itself require retraining the GRU.

## Broader follow-ups requiring prioritization

### Variance-error dispersion

The Figure 4 correction quantified path-level variance error for the original
training experiment. Corresponding dispersion for 249-day holdout and
jump-active paths has not been established by that correction. Decide whether
to add those checks or retain explicit limits on the existing evidence.

### Reproducibility and data documentation

Much of the original provenance work is now complete, including canonical
training results, recovered GARCH fits, pooled VaR fingerprints, and the
reproduced GRU checkpoint and log. Remaining work includes a final check of
data split/dividend adjustments, source-universe documentation, required-cache
failure behavior, and reproduction from the actual release package. Do not
repeat completed provenance work without identifying a remaining gap.

### Additional evidence proposals

- Paired simulation uncertainty for the main 2025 hybrid-minus-naive
  comparison, retaining the shared market replication as the unit.
- Fit-time versus reuse-time measurements to support practical cost claims.
- Additional historical holdouts to assess generalization.

These are proposals for prioritization, not an instruction to launch every
experiment. Distinguish the main holdout comparison from the jump-ablation
contrasts, which already have paired uncertainty estimates. Additional
historical holdouts are a larger extension.

## Suggested resumption order

1. Correct the long-run assumptions and bounds.
2. Reconcile the jump-frequency interpretation.
3. Correct the heavy-tail caption and determine whether a new control is needed.
4. Correct and rescore Hellinger distance.
5. Decide which broader follow-ups need implementation or an explicit scope limit.
6. Rebuild, inspect, and perform the author's manual review.
7. Complete package reproduction and regenerate release artifacts.

The next session can start with: **“Open REVIEW_HANDOFF.md and tackle item 1.”**

## Working rules and references

- Never use star-shaped plot markers. Keep the accepted Figure 4 markers.
- Preserve unrelated edits and recorded experiment hashes. Version and validate
  any necessary scientific implementation changes.
- Synchronize substantive text in the arXiv and JFDS trees.
- Rebuild and visually check the PDFs after manuscript changes.
- Follow [HOUSE_STYLE.md](HOUSE_STYLE.md).

Reference records:

- [Current numbered-finding status](audits/2026-09-14-review/STATUS.md)
- [Original audit and unnumbered follow-up list](audits/2026-09-14-review/REVIEW.md)
- [Latest correction: R11 tracker scope](audits/2026-09-14-review/tracker-correction/README.md)
- [Latest PDF verification](audits/2026-09-14-review/tracker-correction/verification.json)
- [R8 metric definitions and retained Hellinger convention](audits/2026-09-14-review/metrics-correction/README.md)

Line numbers above identify the saved state and will move as edits proceed.
