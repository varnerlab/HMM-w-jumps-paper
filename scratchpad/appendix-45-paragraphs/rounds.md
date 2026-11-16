# Cold-read rounds for the 45-paragraph revision

| Round | Range/context | Severity 3 | Severity 2 | Severity 1 |
|---|---|---:|---:|---:|
| 1 | First chunk, P1–P28/F1 | 0 | 4 | 3 |
| 1 | Second chunk, P29–P66/F2–F7 | 0 | 6 | 4 |
| 2 | First chunk, P1–P28/F1 | 0 | 1 | 1 |
| 2 | Second chunk, P29–P66/F2–F7 | 0 | 0 | 2 |
| 3 | Focused final caption/paragraph check, F1/P50/P59 | 0 | 0 | 1 |
| 4 | Final numerical-summary caption, F1 | 0 | 0 | 0 |

Each assignment used a fresh reader with preceding manuscript context and no earlier reports or editor reasoning. Input table bodies were expanded in the reader copies so the retained tabular evidence could be read. Empty label-only blocks are excluded from actual paragraph counts.

Round 1's 17 issues were repaired in place; see `triage.md`. Round 2's four issues were repaired in the final saved source: define absolute returns and the subdominant eigenvalue in the numerical-generator caption, identify its no-jump moments, specify the unclipped variance-preserving training paths, and distinguish episode incidence among enabled asset paths from the share of assets enabled. Round 3 rereads only these final changed passages; all other wording retains the round-2 read.

The section-purpose review retained necessary derivations and limitations, removed repeated prose and 17 redundant floats, and preserved all 55 displayed mathematical blocks byte-for-byte. Actual prose paragraphs: 58 → 45. Guard-counted prose words: 11,963 → 9,358. Figures/tables: 24 → 7. Appendix PDF span: pages 27–59 → 27–49, or 33 → 23 pages. Manual paragraph grouping and mathematical verification replace the default no-structure-change guard for the user-authorized restructuring; no original baseline was overwritten.

Round 3 found one minor caption omission: aggregation of sample skewness over simulated paths. The caption now states “mean sample skewness,” consistent with the original numerical calculation; round 4 checks that final caption. No prose paragraphs or mathematics changed.

Completion: all reported clarity issues repaired. The final caption read is clean; other saved passages retain their clean round-2/round-3 reads. Build and reference checks pass without LaTeX warnings; `git diff --check` passes. All final appendix pages27–49 were inspected, with page34 re-rendered after the final two-word caption clarification.
