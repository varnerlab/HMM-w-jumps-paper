# Discussion summary correction

Author request: begin P1 with synthetic generators and three stylized facts, then describe the study. Only P1 changed. It now moves from heavy tails, weak raw-return autocorrelation, and volatility clustering to the hidden Markov generators, their multi-asset reuse, the variance correction, and training/holdout evaluation.

| Read | Context | Severity 3 | Severity 2 | Severity 1 |
|---|---|---:|---:|---:|
| Final P1 | Abstract and Introduction; Methods/Results intentionally skipped | 0 | 0 | 0 |

The prior full Discussion review supplies the baseline; this was a targeted author correction, not a new review of P2–P5. P2–P5 were verified byte-for-byte unchanged. Five paragraphs remain; the skill's total prose count decreased from 981 to 970 words. The structure/word guard passed. The invariant checker found only the intentional added empirical-motivation figure reference, which supports the three stylized facts. No numerical values, citations, or existing reference targets were removed. No claim that all three facts were perfectly reproduced was added; the text states the generator requirements and what was tested.

The fresh reader found no clarity or placement issues. `make all` and `git diff --check` passed. The LaTeX log contains no warnings or unresolved references. Revised Discussion pages 15–16 were rendered and visually checked without layout defects. The earlier discussion-review PDF hash is superseded by this author-requested P1 correction.
