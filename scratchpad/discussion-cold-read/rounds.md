# Discussion cold-read revision

The user explicitly requested exactly five paragraphs: a summary; three paragraphs interpreting the paper's three key results; and a final paragraph on limitations and further considerations. Existing manuscript edits were the baseline. Only `arxiv-paper/sections/discussion.tex` was edited, with the manuscript PDF rebuilt afterward.

## Reader rounds

Every context and round used a fresh independent reader. Full readers received preceding manuscript context; skim readers received only the abstract and Introduction, with an explicit note that Methods and Results were skipped. Raw counts are reported separately; the same problem can appear in both contexts and is not counted as a distinct scientific issue merely because two readers flagged it.

| Round | Context | Severity 3 | Severity 2 | Severity 1 |
|---|---|---:|---:|---:|
| 1 | Full | 0 | 8 | 3 |
| 1 | Skim | 0 | 10 | 3 |
| 2 | Full | 0 | 1 | 2 |
| 2 | Skim | 0 | 5 | 0 |
| 3 | Full | 0 | 0 | 2 |
| 3 | Skim | 0 | 2 | 1 |
| 4 | Full | 0 | 0 | 0 |
| 4 | Skim | 0 | 1 | 2 |
| 5 | Full | 0 | 0 | 0 |
| 5 | Skim | 0 | 1 | 1 |
| 6 | Full | 0 | 0 | 0 |
| 6 | Skim | 0 | 0 | 0 |

Both final readers found no comprehension or placement issues in the saved five-paragraph text. No source wording changed after those verdicts. Reports are retained in the corresponding `rN/full/report.md` and `rN/skim/report.md` files.

## Final paragraph structure

1. Study summary: reuse problem, centering/rescaling construction, comparisons, holdout, and jump experiment.
2. Practical meaning of reuse: improvement over naive composition, training and holdout support, competitive direct residual fits, and the centering control.
3. Meaning of the jump result: a single-asset temporal improvement did not automatically survive composition or holdout evaluation; calibration transfer remained an issue.
4. Meaning of variance preservation: it did not preserve complete distributional shape or calibrated market exposure under clipping.
5. Further considerations: restricted validation, constant-return-state treatment, tail calibration, independence assumptions, residual dependence, and terminal cumulative uncertainty.

The original had three paragraphs and 1,042 skill-counted prose words; the final draft has five paragraphs and 981 words (5.9% shorter). There was no page budget. Both initial readers independently identified reuse, jump transfer, and variance-versus-shape as the existing three principal interpretive themes. Holdout evidence was therefore retained with reuse rather than made into a separate key-result paragraph. This choice preserves the original argument while meeting the requested summary/three-interpretations/limitations structure.

## Triage

Round 1: summary, comparative evidence, tail validation, and limitations were interleaved in the opening and closing paragraphs. Those purposes were reassigned to the user's five slots. Ambiguous 'neither method' wording was removed; the unit of holdout heterogeneity was corrected from paths to assets; corrected composition is named consistently. The market-exposure interpretation was narrowed from an asserted cause to a pattern consistent with dilution. Independence is attached explicitly to the variance calculation, and omitted residual dependence is scoped to the evaluated construction, since the algorithm allows an optional dependence step. Terminal uncertainty is explicitly cumulative, not the final daily return. The rank-reordering aside was cut because it introduced a proposed remedy only to reject it, without developing the Discussion's argument. The underlying limitation remains explicit.

Round 2: the common-centering comparison and the distinct training-to-holdout comparison were named directly. The third key-result paragraph was refocused on shape and exposure; restricted branch-validation evidence and covariance assumptions moved into the final paragraph. 'Variance budget and residual floor' was replaced with the concrete target and residual contribution. Fallback language was simplified rather than expanded into implementation detail. No new methods material was added.

Round 3: 'met the target variance' was narrowed to 'targeted total variance' to preserve finite-path covariance qualifications. The final sentence of the fourth paragraph now distinguishes distributional shape from calibrated market exposure instead of attributing both to the univariate generator. Clipping is briefly identified at first local use. The rarely used branch is identified by the fraction of variance explained by the market, and the constant-return-state check is described as generating nearly constant values. The main comparisons' retained scale choice remains explicit. No additional paragraphs were added.

Round 4: the full-context reader found no issues. The skim reader needed the tracker branch and its check identified together: the revised limitation now says that the branch targets the market-explained fraction of variance, and that the Gaussian simulation checked its formula without fitting full-return generators. A local phrase identifies the market-mean symbol, and the constant-return observations are explicitly identified as training observations assigned to a state. This is local interpretation support, not a new Methods explanation.

Round 5: the full-context read remained clean. The skim read correctly requested an explicit distinction between cumulative log returns and arithmetic compounding; the terminal-uncertainty limitation now says cumulative log returns. The isolated asset-level holdout comparison explicitly names corrected composition. Both changes clarify existing scope rather than changing results.

Requests for extra test-construction, jump-calibration, grid, or dependence-method details were judged optional and not added. The readers' raw severities were retained rather than reclassified to conceal an unresolved issue.

## Evidence and invariants

The correction and comparator interpretation were checked against the current Results and aggregate/holdout tables. The shape interpretation was checked against the Results' bounded wording and the existing excess-kurtosis composition derivation. The optional residual-dependence step and terminal cumulative uncertainty were checked in `method_sim.tex`. The fallback diagnostic is the existing paired training check described in the appendix; no alternative model was fitted or simulated for this edit.

The invariant checker reported no changed numbers, citation keys, reference targets, labels, displayed mathematics, algorithms, tables, or new style violations. All original numerical mentions, citations, and cross-reference targets remain. The original mean-shift expression is retained. Some interpretation was narrowed, as noted above; no numerical result or model behavior changed.

The default structure guard reports changed paragraph count and block order, as expected under the user's explicit restructuring request. Its original snapshot was not replaced. Manual and task-local automated checks confirmed exactly five narrative paragraphs with the requested roles, unchanged formatting, no inserted headings or lists, and a prose word count below the original ceiling. Source/PDF hashes and the manual structure contract are retained in the scratch directory.

## Build and layout

`make all` completed. `git diff --check` passed; the LaTeX log had no warnings, undefined references, overfull boxes, or underfull boxes. Discussion appears on pages 15–16 of the rebuilt PDF. Pages 14–17, including neighboring Results and Conclusion text affected by reflow, were rendered and inspected. No clipping, overlap, broken references, or isolated one-line paragraph starts/ends were found.
