P1: Motivation, composition problem, reuse question
First: Researchers and practitioners use synthetic equity paths to test risk models, evaluate portfolio strategies, and examine market scenarios beyond those observed in a historical sample.
Last: The question is whether such a transformation can control the mean and variance of the composed paths while retaining the generator's heavy tails and volatility clustering.

P2: Empirical heavy tails and clustering; SPY context
First: The transformation is useful only if each generator reproduces the behavior of its own asset.
Last: Large and small absolute growth rates therefore cluster in time, a property that synthetic financial data often miss even when their return histogram appears realistic.

P3: HMM construction and duration motivation
First: A hidden Markov model (HMM) offers an interpretable way to represent both features: it draws growth rates from state-dependent distributions and uses transitions between states to represent temporal behavior.
Last: Adding the market component, however, changes the distribution and temporal behavior of the composed returns, so an improvement from such a mechanism, whether added to SPY's generator or to the asset generators, must be checked again after composition.

P4: Study approach and comparison design
First: In this study, we developed a variance correction for combining full-return generators, each fitted to one asset, with a shared market path (Fig. [fig:preservation]; Table [tab:aggregate]).
Last: Volatility clustering of the composed paths, which the duration mechanism targets, was measured in a separate comparison with and without that mechanism.

P5: Main distributional and tail-risk findings
First: The Kolmogorov--Smirnov pass rate measured distributional fit as the share of simulated paths that a two-sample test at the $5%$ level did not distinguish from an asset's observed growth rates.
Last: Because the assets shared one market and holdout days were not independent, we treated these rates as descriptive rather than as a formal test of calibration.

P6: Jump mechanism and transfer experiment design
First: We assessed the SPY hidden Markov generator in more detail, together with a jump-duration variant that implements the duration mechanism (Table [tab:model_comparison]).
Last: Both configurations used the jump parameters calibrated on SPY's $2014$--$2024$ data, without recalibration for each asset, and each configuration was run with both naive and corrected composition.

P7: Jump findings, contribution and scope
First: Both jump configurations reduced the autocorrelation error of the composed paths in training and raised it in the $2025$ holdout (Table [tab:jump_ablation]).
Last: Neither reuse nor residual fitting, as tested here, modeled dependence among the residuals of different assets, which portfolio evaluation also requires.
