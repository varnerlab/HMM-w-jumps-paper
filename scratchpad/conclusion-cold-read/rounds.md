# Conclusion cold-read record

Shortened one paragraph from 330 to 150 prose words (55% reduction), preserving its role as a concise conclusion and all existing figure/table reference targets. Only conclusion.tex was edited for this task; the manuscript PDF was rebuilt.

| Round | Reader context | Severity 3 | Severity 2 | Severity 1 |
|---|---|---:|---:|---:|
| 1 | Full paper | 0 | 4 | 3 |
| 1 | Abstract/introduction skim | 0 | 4 | 3 |
| 2 | Full paper | 0 | 0 | 0 |
| 2 | Abstract/introduction skim | 0 | 1 | 0 |
| 3 | Full paper | 0 | 0 | 0 |
| 3 | Abstract/introduction skim | 0 | 0 | 0 |

Each round used fresh independent readers. Raw reports are stored in r1, r2, and r3 under each context directory.

## Changes and triage

Removed repeated contribution statements and endings, the numerical inventory of sample sizes and VaR exceedances, and the detailed clipping explanation. These details remain in Results and Discussion; no supplement relocation was needed. Preserved the reuse contribution, distributional improvement against centered naive composition, lack of established advantage against residual fitting, failed holdout transfer of the temporal improvement, and essential tail, portfolio, and cumulative-risk limits.

The second skim reader found that “effective loading” was unclear without Methods. Replaced it with “the loading used in composition.” Final readers found no remaining friction. No optional detail was added to lengthen the conclusion.

## Verification

Structure guard passed: one paragraph before and after, 330 to 150 prose words. Invariant check retained all citation, label, and reference targets. Deliberately removed numerical details were 423, 416, 99, 1.12, 1.16, and nominal 1; no numerical results were changed.

`make all` succeeded. The final LaTeX log contained no warnings, undefined references, or overfull/underfull boxes. `git diff --check` passed. Rendered pages 16–17 were inspected: the conclusion is wholly on page 16, with clean layout and subsequent text reflow. Source and PDF hashes are recorded in verification.json.
