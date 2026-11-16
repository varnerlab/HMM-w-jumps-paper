Paragraph purposes

- results.P1: Compare the training marginal and temporal fit of the SPY generator with the seven alternatives and locate its main strength in heavy tails.
- results.P2: Quantify the training benefit of jump episodes and explain the calibration and transfer limits behind that benefit.
- results.P3: Assess frozen-model holdout fit, distinguish kurtosis from distribution-test performance, and introduce the multi-asset experiments.
- results.P4: Show that the correction removes excess composition variance across non-tracker assets while explaining finite-path deviations and the tracker exception.
- results.P5: Compare factor recovery and marginal fit, separate the centering effect from predictive performance, and explain remaining distributional limitations.

Problems

results.P1.S10 | AMBIGUOUS COMPARISON | severity-1 | “the GRU showed the same tradeoff” | The preceding GARCH statement combines a unique ranking (lowest ACF-MAE) with rare distribution-test passes. “Same tradeoff” leaves the GRU's temporal claim indeterminate: it cannot necessarily share that ranking, and no comparator is named for its temporal improvement. Replace the shorthand with the specific temporal comparison the table supports within this sentence. | Guess: GRU also improved temporal fit relative to the HMM variants while fitting the marginal distribution poorly.

results.P3.S9–S10 | REPETITION | severity-1 | “The SPY advantage over Laplace lay in excess kurtosis rather than pass rates or distances.” | S6–S7 already make this exact comparison, and S9 repeats the asset-dependent holdout result immediately after S8. The two recap sentences delay the transition to composition without supplying another limit or interpretation. Retain one connected synthesis or cut the duplicate statements within the existing paragraph. | Guess: these sentences are intended to establish the narrow basis for claiming successful single-asset validation before moving to composition.

TOTALS: severity-3 = 0; severity-2 = 0; severity-1 = 2.
