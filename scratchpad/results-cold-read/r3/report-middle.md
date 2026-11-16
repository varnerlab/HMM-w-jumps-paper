# Fresh cold read: results.P6–P10

Reader: quantitative finance; ordinary knowledge of HMMs, regression, KS/AD tests, VaR, kurtosis, and autocorrelation. Read only the supplied reader_results_2.txt. P9 is an empty label, not prose.

## Paragraph purposes

- **P6:** Establish that direct residual fitting is competitive with reuse, show how common centering and emission fallbacks affect the comparison, and limit the claim to improvement over naive reuse.
- **P7:** Report frozen-model holdout distribution and variance results, then distinguish apparent improvement from the effects of shorter samples and differences among assets.
- **P8:** Compare realized one-day VaR exceedances with nominal rates and explain why the descriptive results do not establish calibration or a reliable method ranking.
- **P10:** Test transfer of SPY jump settings to multi-asset composition, show the training/holdout reversal and marginal-fit cost, and delimit variance preservation and jump evidence.

## Findings

M1 | WORDING | severity-1 minor | “its thresholds were slightly too permissive on average” | With left-tail return thresholds, “permissive” does not give an immediate numerical direction: a reader can associate permissiveness either with accepting greater losses or with triggering fewer exceedances. The preceding exceedance numbers make the intended meaning recoverable. State directly that the thresholds understated the magnitude of tail losses on average, while retaining the existing qualification that this descriptive comparison could not confirm calibration. | Guess: “too permissive” means that the estimated loss limits were slightly too small, producing more observed breaches than nominal.

M2 | COMPARISON BASELINE | severity-1 minor | “fell by about $1.5$ percentage points when asset jumps were added” | P10 explicitly uses no jumps as the reference for the training ACF reduction, but the holdout KS sentence can mean either the additional change from market-only to market-plus-asset jumps or the total change from no jumps. This is a small ambiguity in the reported marginal-fit cost, resolved by naming its reference condition in the existing sentence. | Guess: the reported decrease compares market-plus-asset jumps with no jumps; “when asset jumps were added” could instead imply a comparison with market-only jumps.

## Overall reading

No passage stopped or materially slowed the reading. The comparisons and limitations are understandable without requesting further methods detail. P6’s fallback check remains connected to its claim about the gap between reuse and residual fitting; P7’s matched-length qualification directly limits the apparent holdout improvement; P8’s simulation convergence check and dependence caveat address different uncertainties. P10’s variance result supports the composition claim, while its qualification prevents an aggregate result from being mistaken for preservation in every asset.

The supplied paragraphs do not need splitting. P6 concludes the three-paragraph composition subsection; P7–P8 form a coherent two-paragraph holdout subsection. No additional explanatory material is necessary for the current claims. Any further implementation exposition would be OPTIONAL DETAIL suitable for the supplement.

TOTALS: severity-3 = 0; severity-2 = 0; severity-1 = 2.
