# Results cold-read revision

The user authorized restructuring every Results subsection to at most three paragraphs and retaining critical displaced results in one or two clear supplementary paragraphs. The installed skill is `cold-read`; no `cold-review` skill was found. Existing author changes were snapshotted before editing and preserved as the baseline.

## Reader rounds

Counts are raw reader flags, not claims of independently verified scientific errors. Each round used fresh readers with preceding manuscript context. Reports are saved under each round directory. Overlapping flags are retained in the raw counts; they are not added together across rounds as unique problems.

| Round | Scope | Readers | Severity 3 | Severity 2 | Severity 1 |
|---|---|---:|---:|---:|---:|
| 1 | Original Results | 4 | 0 | 14 | 6 |
| 2 | Revised Results | 3 | 0 | 8 | 4 |
| 2 supplement | Two revised appendix paragraphs | 1 | 0 | 0 | 0 |
| 3 | Revised Results | 3 | 0 | 0 | 5 |
| 4 | Final saved Results | 1 | 0 | 0 | 2 |

The final reader found no stopped or slowed reading and no need for additional paragraphs or methods detail. Two minor wording preferences remain in the raw report: “weaker generators” could specify distribution-test performance more explicitly, and “stayed at 74.4%” could repeat the common-subset qualifier from the immediately preceding sentence. These were retained because the comparison metric and population are recoverable locally; they are not unresolved scientific or substantive comprehension problems. No wording changes were made after that final verdict. See `r4/report-final.md` for the full independent report.

## Paragraph and length verification

| Results subsection | Before | After |
|---|---:|---:|
| Single-asset generator validation | 5 | 3 |
| Variance-corrected multi-asset composition | 4 | 3 |
| Holdout performance and VaR coverage | 2 | 2 |
| Jump-enabled multi-asset composition | 1 | 1 |
| Sensitivity analyses | 3 | 3 |
| Total narrative paragraphs | 15 | 12 |

The skill's prose count fell from 3,801 to 2,672 words (29.7%). No page ceiling was imposed. Results occupies pages 11–15 of the rebuilt 60-page manuscript. The two revised supplementary paragraphs are on pages 44 and 46.

The default Results structure guard reports changed count and block order, as expected for explicitly authorized restructuring: 16 to 13 counted blocks, including one standalone label falsely counted as a paragraph. The original snapshot was retained. Manual and task-local automated checks confirmed 12 actual prose paragraphs, the required subsection counts, unchanged subsection order, and preserved citation keys and labels. The appendix guard passed unchanged paragraph count (80) and reduced prose length (12,073 to 11,992 words). No formatting, displayed equations, algorithms, tables, data, or code were changed.

## Triage and repairs

Round 1: the first two subsections repeated Methods and appendix material. Training benchmarks became one paragraph, jump effects and bounded sensitivity another, and holdout validation a third. The composition section retained variance preservation, distributional fit, and comparison with residual fitting as its three purposes. Centering and fallback diagnostics now qualify that last comparison directly. Repeated diagnostic setup was cut from the main text; existing appendix coverage was verified before cutting it. Two paragraphs in the appendix were revised to carry the jump-mixture experiment and the state-resolution experiment, including their constraints. No new supplementary paragraphs were added.

The readers also identified interpretations that exceeded the comparisons: the state-count sweep changed several factors together; larger market shares did not establish monotonically poorer distributional fit; matched-length blocks changed market-path treatment as well as length; the aggregate jump variance ratio did not establish preservation for each asset. These claims were narrowed to the observed evidence. The market-episode limitation now refers specifically to market jumps.

Round 2: supporting sweeps, fallback procedures, and the synthetic tracker specification still delayed the central findings. These were condensed further, with detailed values retained in their existing appendix tables. The holdout and jump subsections kept their original paragraph counts; their comparisons and qualifications were tightened within those boundaries. The loading-dependent shape interpretation moved next to the loading-quartile finding, leaving the stress paragraph focused on clipping. The precise relationship between fitted intercept error and loading error was restored in one sentence to explain why exact path means coexist with nonzero intercept errors. Requests for extra grid detail were optional and were not added.

Round 3: all five minor flags were addressed: the GRU temporal comparison now names the HMM variants; the holdout conclusion was condensed; VaR exceedance wording now states its direction directly; the jump KS decrease names the no-jump baseline; and the clipping threshold explicitly applies to the variance-preserving branch. The final saved wording was sent to a fresh reader.

## Critical detail and factual checks

The two revised appendix paragraphs contain (1) the 4,000-path jump/no-jump mixture experiment and its kurtosis/ACF tradeoff, and (2) the 30–200-state sweep, fixed five-state tail sets, repeated tuning, and SPY-only scope. The former rewrites the existing jump-kurtosis paragraph; the latter rewrites the existing state-resolution paragraph. Both passed an independent cold read without flags.

Other shortened details were already documented: emission ablation and its kurtosis values in the emission comparison, skewness in the generator-moment derivation, centering mechanics in the composition derivation and centering-control section, fallback states and paired replay in the fallback section, and the Gaussian tracker grid in its existing table and preceding paragraph. No critical diagnostic was left only in the scratch report.

The invariant check reports intentional changes to references and numerical mentions. The main Results no longer repeats the algorithm or calibration-equation reference, both retained elsewhere; it adds a direct fallback-appendix reference. Removed numerical mentions correspond to the details just listed, not changed observations. New main-text values are the existing 73.3% bootstrap KS rate and two calculated maximum deviations from the 15 displayed tracker-grid cells: 0.0011 for loading and 0.0017 for R-squared. Those maxima were recomputed from the source table. The 4,000-path count was transferred to the appendix. Remaining acronym-led flags are pre-existing text outside the two revised paragraphs.

The aggregate jump variance scope was checked in `code/downstream-evaluation/src/JumpAblation.jl`: replication totals average across all active calibrated assets, including trackers. The table and source support describing the mean ratio, not universal asset-level preservation. The GRU temporal comparison was checked against the main model-comparison table. Main numerical comparisons were checked against the existing aggregate, centering-control, jump-ablation, and tracker tables. This was a prose revision, not a new simulation or manuscript-wide technical audit.

## Build and visual verification

`make all` completed successfully. The final LaTeX log contains no warnings, undefined references, or overfull/underfull boxes. `git diff --check` passed. Pages 10–16 and 43–47 were rendered and visually inspected, including the revised passages and adjacent reflow: no clipping, overlap, isolated single-line paragraph starts/ends, or broken references were seen. Source hashes and paragraph counts are recorded in `verification.json`.
