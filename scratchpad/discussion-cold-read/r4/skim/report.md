# Fresh discussion cold read

Read only the supplied file, in order: abstract and introduction as context, then discussion.P1–P5. Methods and Results were intentionally skipped. I treated the five developed paragraphs and their assigned roles as fixed.

## Paragraph purposes

- **discussion.P1:** Summarize the reuse construction, comparison design, and jump question. This purpose is clear.
- **discussion.P2:** Interpret reuse's practical benefit relative to naive composition and residual fitting, including the centering control that limits claims of superiority. The distinction between usefulness and distributional advantage is clear.
- **discussion.P3:** Interpret the failure of the single-asset jump improvement to transfer reliably to composed holdout paths, and identify calibration limits. This purpose is clear.
- **discussion.P4:** Explain why variance preservation does not preserve distributional shape or market exposure, particularly when clipping activates. The argument is understandable, with a minor notation issue below.
- **discussion.P5:** State limits on validation, tail inference, residual dependence, and terminal residual uncertainty, then identify what broader applications require. The final two limitations and their consequences are clear. The first two specialized validation examples need slightly clearer local identification.

## Specific issues

ID | TYPE | severity | quote | issue | guess
--- | --- | --- | --- | --- | ---
discussion.P4.S7 | NOTATION | 1 minor | “$(\\beta_i^{\\eff}-\\beta_i)\\overline{g}_m$” | The surrounding sentences identify the loading change, but the symbol for the market mean is not introduced in the supplied context. A short local identification would make the expression self-contained. | I read the two betas as reduced and originally fitted loadings, and the barred quantity as the unchanged market mean.
discussion.P5.S2–S3 | REFERENT / CONTEXT | 2 slowed | “Only two market-tracking assets tested the branch targeting $R^2$” | This is the first mention of a separate R-squared-targeting branch in the supplied reading. The next sentence's “Its Gaussian check” adds a second unidentified object. I can see that evidence is limited, but cannot tell what behavior this branch is meant to preserve or what part the Gaussian check actually checked. A brief identification of the branch and check is essential to this existing limitation; a derivation would be OPTIONAL DETAIL. | I assume this is a special correction for market-tracking assets that preserves explained variance, and that an idealized Gaussian experiment checked an algebraic property rather than fitted HMM behavior.
discussion.P5.S4 | MODEL DESCRIPTION | 1 minor | “states with identical observed returns” | “States” were introduced as distributions that generate returns. Here it takes a reread to recognize that “identical observed returns” probably describes the observations assigned to a state during fitting, rather than identical returns across states. Naming the fitted observations would clarify the premise of the fallback comparison. | A state has no observed within-state variation; near-constant emissions replace a fallback spread based on the whole asset series.

No additional placement issues. The quantitative comparisons support the three interpretation paragraphs, and the ending connects the two portfolio limitations to the required extensions. More detail about test thresholds, jump mechanics, or alternative dependence models would be OPTIONAL DETAIL for this reader.

TOTALS: severity-3 = 0; severity-2 = 1; severity-1 = 2
