# Fresh reader report

Read front-to-back after the supplied abstract and introduction, with Methods and Results intentionally skipped. Reader perspective: applied statistics/finance, familiar with regression, distributions, and simulation. Citation-related sentence splits were treated as extraction artifacts.

## Paragraph purposes

- **discussion.P1:** Summarize the reuse correction, the principal comparisons, and the separate jump experiment. The purpose is clear.
- **discussion.P2:** Interpret improved distributional fit as a practical reuse benefit, while qualifying comparisons with direct residual fitting. The matched-centering comparison supplies an understandable reason for the qualified conclusion.
- **discussion.P3:** Interpret the failure of improved single-asset temporal fit to transfer reliably through composition, with calibration transfer as a possible explanation. The purpose is clear.
- **discussion.P4:** Explain why variance control does not preserve distribution shape or all calibrated market-exposure properties. The stress-test discussion belongs here, although its loading-adjustment terminology causes a small forward-reference problem.
- **discussion.P5:** Delimit validation and application scope, ending with the two requirements for portfolio and cumulative-risk applications. Most limitations are understandable without the skipped sections; the first two specialized checks are less self-contained.

## Specific reading issues

1. **discussion.P4.S5–S8 | FORWARD | severity 1 | “The loading adjustment was unnecessary at observed market variance” |** The paragraph introduces a loading adjustment before identifying either what it adjusts or why increased market variance activates it. “Clipping” then appears as another name without an explicit connection. S7–S8 allow me to reconstruct that these describe the same mechanism, so this is a minor reread rather than a missing-methods problem. **Guess:** When the market component would consume too much of the asset variance budget, the method reduces the magnitude of the fitted loading to retain some residual variance.

2. **discussion.P5.S2 | UNDEFINED | severity 2 | “Only two assets tested the $R^2$-preserving branch” |** I know what regression $R^2$ means, but the supplied context has not established a separate branch, and this sentence does not say which feature of the correction distinguishes it. Consequently I cannot tell what application regime has only two-asset support or how that limitation relates to the preceding stress/clipping discussion. This requires a brief identifying phrase, not a tutorial. **Guess:** A special case of the correction targets the regression variance fraction, distinct from the ordinary variance-preserving construction; its empirical validation is sparse.

3. **discussion.P5.S3–S4 | UNDEFINED | severity 2 | “Assigning empirical rather than full-series spreads to states containing identical returns” |** “Empirical” does not identify the observations supplying the alternative spread. Taken literally as the within-state empirical spread, identical returns give zero, which makes it unclear what distribution was assigned and how it improved fit. S4 identifies a scale choice but does not resolve this distinction. **Guess:** This is a sensitivity check on a fallback emission-scale assignment for degenerate fitted states; using a state-specific empirical quantity instead of the asset-wide spread improved training fit.

## Optional detail

No additional detail is needed for the KS comparison, jump-ablation logic, pooled-threshold VaR limitation, residual dependence, or terminal-centering limitation to make sense on this reading. More procedural detail on those points would be OPTIONAL DETAIL. The five-paragraph structure already fulfills the requested summary / three result interpretations / final considerations arrangement; no added paragraphs or headings are needed in the manuscript.

TOTALS: severity-3 = 0; severity-2 = 2; severity-1 = 1
