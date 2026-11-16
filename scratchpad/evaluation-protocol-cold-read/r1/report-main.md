evaluation_protocol.P2.S7–S8 | PURPOSE | 1 | “Across the sample, $\beta_i$ ranged” | The fitted parameter ranges interrupt the comparison design and already point to figures; they seem dispensable here. | Best guess: they establish the breadth of market exposures.

evaluation_protocol.P2.S14 | PURPOSE | 2 | “after JumpHMM, the software package that implements our generator” | The naming history and synthetic-price conversion bury the essential comparator: an HMM fitted directly to OLS residuals. | Best guess: the package name explains the table label, and compounding accommodates its fitting interface.

evaluation_protocol.P2.S17 | REFERENT | 2 | “These four methods” | The four residual-based comparators are interleaved with naive and hybrid methods, requiring a backward count. | Best guess: Gaussian SIM, residual-fit HMM, block bootstrap, and GARCH.

evaluation_protocol.P2.S18–S22 | PURPOSE | 2 | “We accepted a GARCH fit only if” | The detailed acceptance checklist and stored-fit recheck overwhelm the essential eligibility result: 30 nonstationary fits were excluded. | Best guess: these are implementation safeguards documenting why GARCH covers fewer assets.

evaluation_protocol.P3.S5–S8 | PURPOSE | 1 | “Only the residual mean differed between the two versions” | Several sentences restate how the paired centering control works before directing readers to its existing appendix definition. | Best guess: the essential point is that the control holds draws fixed and compares all methods on the same 393 assets.

evaluation_protocol.P4.S13–S14 | PURPOSE | 2 | “We archived all $250,800$ training-path scores” | Archive contents, exact archive size, and table-generation provenance interrupt the explanation of scores without changing their interpretation. | Best guess: these sentences establish reproducibility and consistency among reported summaries.

evaluation_protocol.P5.S12 | REREAD | 2 | “without any change specific to $2025$” | This sounds like the comparison isolates sample-size effects, although randomly selected historical blocks also differ in market conditions and use fitting-period observations. | Best guess: it supplies a training-data reference at the same sample length, avoiding direct comparison of long-training and short-holdout pass rates.

evaluation_protocol.P6.S7–S8 | PURPOSE | 1 | “we fixed the ensemble size and a set of smaller pool sizes” | The chronology of pool-size checks and the additional verification ensemble distract from how the fixed VaR thresholds were constructed and scored; an appendix is already identified. | Best guess: these checks establish that Monte Carlo noise does not materially determine the thresholds.

evaluation_protocol.P1 purpose: Identify the evaluation-protocol section.
evaluation_protocol.P2 purpose: Define the training universe, six composition methods, and GARCH eligibility.
evaluation_protocol.P3 purpose: Explain paired draws and the control for differences in residual centering.
evaluation_protocol.P4 purpose: Define the training scores, their interpretation, and replication summaries.
evaluation_protocol.P5 purpose: Explain the frozen-model holdout experiment and its length-matched reference.
evaluation_protocol.P6 purpose: Explain pooled VaR thresholds, holdout exceedance scoring, and limits of interpretation.

TOTALS: severity-3 = 0; severity-2 = 5; severity-1 = 3.
