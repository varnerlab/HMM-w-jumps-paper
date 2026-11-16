# Appendix cold-read record

Edited source: arxiv-paper/sections/appendix.tex. Existing author edits were the baseline. No other manuscript source was changed during this task.

| Round | Audit range | Severity 3 | Severity 2 | Severity 1 |
|---|---|---:|---:|---:|
| 1 | P1–P26, F1–F4 | 0 | 7 | 3 |
| 1 | P27–P51, F5–F7 | 0 | 5 | 3 |
| 1 | P52–P80, F8–F24 | 0 | 5 | 3 |
| 2 | P1–P26, F1–F4 | 0 | 1 | 1 |
| 2 | P27–P51, F5–F7 | 0 | 1 | 0 |
| 2 | P52–P80, F8–F24 | 0 | 2 | 2 |
| 3 | Final changes: P5, P8, P24 | 0 | 0 | 0 |
| 3 | Final changes: P51 | 0 | 0 | 0 |
| 3 | Final changes: P61, P67, F11, F17 | 0 | 0 | 0 |

Each reader was fresh and received only manuscript text, standard field knowledge, and the editing contract. Rounds 1 and 2 covered the whole appendix with preceding manuscript context. Round 3 independently read every passage changed after round 2; unchanged passages retain their round-2 verdicts. Raw reports are in each round directory. Multi-location flags addressing the same problem are counted once in their raw reader report. The rounds identified different issues rather than repeated unresolved flags. No substantive flags remain. Final readers explicitly treated further implementation requests as optional; these were not added.

## Structure and length

Preserved 58 prose paragraphs and 24 captions, along with section order, paragraph boundaries and roles, all equations, tables, labels, citations, and formatting. The parser also counts 22 empty label-only blocks, so its automated count is 80 → 80. Prose count: 11,992 → 11,963 words. No page budget or permission to restructure was supplied. No material was relocated.

## Main repairs and claim scope

Clarified finite-path versus population approximations, conditional Monte Carlo uncertainty, jump-duration approximations, and replication conventions. Corrected the inclusive R-squared threshold, the sign of the clipping mean shift, and several imprecise mathematical referents. Identified the specific model and percentile definitions behind supplementary checks.

Narrowed two unsupported interpretations: a synthetic-minus-realized portfolio gap does not by itself bound the effect of independent residuals, and similar naive/hybrid kurtosis does not isolate the effect of rescaling. Distinguished loading quartiles from variance-share comparisons. Necessary assumptions for large-sample factor recovery are now explicit. Equations and numerical results remain unchanged. Added settings only document the existing implementation. Detailed decisions and evidence are in triage.md.

## Verification

Structure guard and manual paragraph-identity review passed. Invariant check and an exact comparison confirmed unchanged displayed equations (55 blocks), tabular bodies, citations and labels. The inherited caption acronym-definition flags were reviewed; no new narrative acronym issue was introduced.

`make all` passed, with no LaTeX warnings, undefined references, or overfull/underfull boxes. `git diff --check` passed. All final appendix pages (27–59) were visually inspected; prose, equations, figures and tables remain legible, with no new widow/orphan or overflow issue. The appendix previously ended on page 60. Existing float placement and formatting were retained. Source/PDF hashes are in verification.json.

Suggested PDF spot-checks: pages 30–34 (portfolio and metric qualifications), 41–44 (jump derivation and duration convention), and 48–56 (composition and tail checks).
