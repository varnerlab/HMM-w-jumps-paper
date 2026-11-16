# Fresh reader report

Read the supplied abstract and introduction, then discussion.P1–P5, front to back. Methods and Results were intentionally skipped. Reader perspective: applied finance/statistics, familiar with regression, distributions, and simulation.

## Paragraph purposes

- **discussion.P1:** Summarize the reuse correction, evaluation, and jump-transfer question.
- **discussion.P2:** Interpret reuse's practical benefit and delimit its distributional performance relative to residual fitting.
- **discussion.P3:** Interpret the jump experiments as evidence that temporal improvements do not transfer automatically to composition or holdout data.
- **discussion.P4:** Explain why variance control does not ensure distributional fidelity or preserve calibrated exposure under market stress.
- **discussion.P5:** Collect validation limitations and explain what portfolio and cumulative-risk uses additionally require.

The five paragraphs have the requested summary / three result interpretations / limitations structure. I found no placement problem that requires another paragraph or methods exposition.

## Specific comprehension problems

ID | TYPE | severity | quote | problem | guess
--- | --- | --- | --- | --- | ---
discussion.P2.S10 | REFERENT | 1 minor | “Some assets also had lower pass rates in the holdout” | The preceding sentences compare the correction, JumpHMM-on-residuals, and block bootstrap. This sentence does not identify which method has the lower asset-level holdout rates, so I cannot tell whose generalization it qualifies. | It probably refers to the corrected method, qualifying its aggregate holdout improvement.
discussion.P5.S13 | INTERPRETATION | 2 slowed | “leaving no residual uncertainty in terminal cumulative returns” | The supplied context does not establish whether these are log returns or arithmetic returns. A zero residual sum fixes the cumulative additive return, but it does not generally fix the compounded terminal return for arithmetic returns. That distinction determines the meaning of this limitation in a portfolio discussion. | The modeled returns are probably log returns, so terminal cumulative log return—and therefore terminal wealth conditional on the stated quantities—is fixed.

No additional detail is necessary to follow the other claims at discussion level.

TOTALS: severity-3 = 0; severity-2 = 1; severity-1 = 1
