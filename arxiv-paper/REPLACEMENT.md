# arXiv replacement metadata

Existing record: https://arxiv.org/abs/2603.10202 (currently v2).
Use **Replace** for this record. The revised title belongs to the same record.

## Title

Variance-Corrected Multi-Asset Equity Simulation with Hybrid Hidden Markov Marginals

## Authors

Abdulrahman Alswaidan; Jeffrey D. Varner

## Abstract

Synthetic multi-asset equity data must reproduce each asset's return distribution and its relationship with the market. Reusing a generator fitted to full asset returns creates a problem: adding its draws to a market factor counts market variance twice. We derived a correction that centers and rescales each draw before adding the market factor, allowing reuse without fitting a second generator to regression residuals. We tested the correction on 423 non-market assets in a 424-asset United States equity and exchange-traded-fund universe, using hidden Markov generators with heavy-tailed emissions. The corrected paths retained heavy tails and recovered the calibrated market loadings with low error. On 416 complete asset histories held out from 2025, the correction improved the mean Kolmogorov-Smirnov pass rate over naive composition and brought the median ratio of synthetic to observed variance close to one. Its one-day left-tail 99% Value-at-Risk exceedance rate was similar to that of the best residual-fit method, although both exceeded the nominal rate. We also tested a jump-duration mechanism that extended visits to extreme-return states and improved volatility clustering for the broad-market exchange-traded fund with ticker SPY. The multi-asset correction remained effective with jumps enabled, but transferring the SPY jump settings improved temporal fit in training and worsened it in the 2025 holdout. The method provides a way to reuse fitted asset generators, while dependence among asset-specific residuals remains unmodeled and can lead to overstated rebalancing returns. Code, cached inputs, result summaries, and instructions for fitting the per-asset models accompany the paper.

## Comments

45 pages, including supplementary material. Substantially revised and retitled: variance-corrected multi-asset composition, residual-fit baselines, 2025 holdout and VaR coverage checks, and jump-enabled multi-asset comparisons; revised claims about cross-asset dependence.

## Files and processing

Upload `HMM-w-jumps-arxiv-source.tar.gz` from this directory. The top-level
source is `Paper_v1.tex`; select pdfLaTeX with TeX Live 2025. The archive
includes the generated bibliography, local style, all input tables, and all
cited figures. References precede the main tables and figures, followed by
the SI. Algorithms remain in the body.

The manuscript and repository cleanup are prepared locally. Publish the
repository changes, including the three data symlinks replaced by ordinary
files and the revised reproduction instructions, with the manuscript release.
Fitted-model archives remain local caches; the manuscript now describes their
regeneration rather than claiming that they are distributed.

Check arXiv's processed PDF and metadata before final submission. The local
source archive was compiled independently with shell escape disabled.
Replacement guidance: https://info.arxiv.org/help/replace.html
