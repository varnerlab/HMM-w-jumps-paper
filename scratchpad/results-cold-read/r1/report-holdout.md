Purpose — results.P10: Compare holdout distributional fit and variance across composition methods, then distinguish sample-length effects from remaining temporal and cross-ticker differences.

Purpose — results.P11: Compare descriptive VaR exceedance rates while explaining why one dependent, short holdout cannot establish calibration or a reliable ranking.

Purpose — results.P13: Show that transferred jump settings improve training temporal fit at a distributional cost, preserve average variance targeting, and worsen holdout temporal fit.

results.P12 is an empty label artifact and was not audited.

results.P10.S8 | REREAD | 2 | “therefore accounted for much of the shrinking gap and part of the rise” | I reread S7 to find evidence for “much.” Rates lying between the training and holdout rates establish an ordering, but do not quantify how much the gap shrank. The simultaneous switch to simulated SPY also prevents clean attribution to sample length alone, despite the sentence acknowledging that confound. | Guess: The matched-length results support shorter samples as a substantial contributor, while leaving their separate contribution unidentified. Soften the causal wording; numerical matched-length rates would be an optional detail request.

results.P13.S1–S5 | ORDER | 2 | “With these conventions and different seeds and replication counts” | Five setup and comparability sentences precede the first result. Having already read the detailed Methods protocol, I slowed while waiting for the training-versus-holdout finding that gives this subsection its purpose. The distinctions matter, but their placement makes this opening feel like a second protocol description. | Guess: Lead with the finding that transferred settings help training fit but worsen holdout fit, then retain a shorter comparability reminder beside the quantitative results. No additional paragraphs are required.

results.P13.S10–S11 | REFERENT | 2 | “the mean ratio of composed to generator variance under hybrid composition” | The asset scope is missing. Earlier text explicitly excludes the two trackers from generator-variance preservation because their branch targets observed \(R^2\). Here “across all settings and both windows,” followed by “held the variance target,” leaves me unsure whether the statistic excludes those trackers or averages them into a near-one overall result. This matters to the interpretation, even if the reported number is correct. | Guess: The statistic either describes the variance-preserving assets or is an aggregate whose closeness to one does not establish preservation for the tracker branch. State its scope and keep the conclusion explicitly about the reported mean.

Optional detail request — results.P13.S1: The opening announces naive and hybrid composition, but the prose subsequently reports hybrid results only. A brief statement of whether jumps changed naive temporal fit similarly would help complete that announced comparison. This is not a comprehension blocker; the cited table may already supply sufficient detail.

P11 was understandable on the first pass. Its numerical comparisons and limits are clearly separated, and it does not need restructuring.

TOTALS: severity-3 = 0; severity-2 = 3; severity-1 = 0.
