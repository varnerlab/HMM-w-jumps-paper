# Emission reconstruction: how a growth rate is generated from a state

Date: 2026-07-08

Scope: documents the emission step of HMM-WJ (state -> continuous excess growth rate), cross-checked
between the code (`JumpHMM.jl/src/Emission.jl`, `JumpHMM.jl/src/Simulate.jl`) and the manuscript
Algorithm 2, `alg:decode` ("State decoding and continuous excess growth rate reconstruction"),
`sections/supplemental.tex:231-238` in each paper variant (arxiv / jdiq-paper / jfds-paper) and
`chapters/papers/paper-one/supplemental.tex` in the thesis. Written to answer a defense-prep question:
"we say only 4 parameters are estimated; how are returns generated from the quantile states, is it MLE
per state?"

The code and the algorithm agree on the math. Three points below are not visible from the manuscript
and are recorded so they are not lost before the M-exam.

## 1. Step by step: from state to return

There are two phases. The emission table is built once after fitting; the draw happens once per
simulated step.

### Phase A, build the per-state emission table (once)

Code: `fit_emissions`, `Emission.jl:7-32`. Paper: Algorithm 2, lines 231-234.

1. Every training day already carries a state label k (the Laplace-quantile bin its excess growth
   rate G_t fell into).
2. For each state k = 1..N, gather all training returns assigned to k.
3. Set mu_k = sample mean, sigma_k = sample std of that set. These are plain empirical moments.
4. nu (degrees of freedom) is fixed at 5. It is a hyperparameter, not fit.
5. Store (mu_k, sigma_k, nu) as state k's emission.

### Phase B, draw a return at simulation time (per step)

Code: `sample_emission`, `Emission.jl:39-41`, called from `Simulate.jl:43,55,67,76`. Paper:
Algorithm 2, lines 236-238.

1. The simulator supplies the current state k = S_t. It comes from a normal Markov transition, or is
   forced into a tail state during a Poisson jump excursion. The emission does not care which.
2. Draw a standard Student-t variate Z ~ t_5.
3. Emit G_hat_t = mu_k + sigma_k * Z.

Structural note: the paper presents Phase B as a separate post-hoc pass over a completed state
sequence, while the code fuses the draw into the forward simulation (it emits inline as each state is
visited). These are mathematically identical because emissions are conditionally independent given
the state sequence.

## 2. Are we fitting MLE to each state? No.

This is the key answer.

- The only maximum-likelihood fit in the entire model is the single global Laplace fit (mu_L, b_L)
  that places the quantile bin edges: `Partition.jl:11`, `fit_mle(Laplace, observations)`.
- The per-state mu_k, sigma_k are plug-in empirical moments: slice the training data by bin and take
  its mean and std (`Emission.jl:19-20`). No per-state likelihood is maximized, no EM, no optimizer.
- nu is fixed at 5.

Reconciliation with the "4 estimated parameters" claim (results.tex table row, HMM-WJ column = 4):
the four are the 2 Laplace partition parameters (mu_L, b_L) plus the 2 jump parameters (epsilon,
lambda) from the grid search. The 100 pairs of per-state (mu_k, sigma_k) and the transition matrix are
treated as sufficient statistics of the data, computed by direct counting / plug-in, and are therefore
not counted as fitted parameters. That framing is what keeps the count at 4.

Subtlety worth stating at the exam: sample mean and std ARE the MLE for a Gaussian, but they are NOT
the MLE for a Student-t with nu = 5. A true t MLE would robustly down-weight the outliers and return a
smaller scale. So sigma_k is best described as "the empirical bin standard deviation reused as the t
scale," not "the fitted t parameter." Calling the per-state emissions "fitted" would be generous;
"empirical" is the accurate word, and it is exactly why they count as sufficient statistics.

## 3. Reproducibility gap: a fallback missing from Algorithm 2

The code has degenerate-bin handling that Algorithm 2 does not show (`Emission.jl:15-28`):

- If a state has fewer than min_obs = 2 assigned observations, its emission falls back to the GLOBAL
  mean and std, not the bin's.
- If sigma_k < 1e-12 (a near-constant bin), sigma is floored to the global std.

Algorithm 2 as printed (lines 231-234) simply sets mu_k = mean and sigma_k = std for every k. With the
fine N = 100 partition over roughly 2,766 in-sample days, the extreme tail bins are exactly the ones at
risk of being sparse, so this branch can actually fire. A reader reimplementing purely from the
algorithm would not add the guard and could produce NaN emissions (std of a 0- or 1-element set) in
those bins.

Suggested one-line fix to the algorithm block (to make the manuscript exactly reproducible), inside
the `for k = 1 to N` loop:

    IF |{G_t : S_t = k}| < 2 (or std is ~0) THEN set (mu_k, sigma_k) = global (mu, sigma) of all
    training G_t.

This is a documentation fix only. It does not change the model; it records what the code already does.

## 4. Variance-scaling nuance (verify intent)

The emission is G_hat_t = mu_k + sigma_k * Z with Z a standard Student-t, t_5. A standard t has
variance nu / (nu - 2) = 5/3, not 1. Therefore the realized per-state variance is

    Var(G_hat_t | k) = sigma_k^2 * nu/(nu-2) = sigma_k^2 * 5/3 ~ 1.67 * sigma_k^2.

So the emitted spread is about 1.67x wider than the bin's own empirical variance. In other words,
"sigma_k = the bin's standard deviation" and "the emitted standard deviation" are not the same number.

This is recorded as a characteristic to confirm was intentional, not a claim of error. Heavier per-bin
spread plausibly helps reproduce the tails and the observed kurtosis. If instead the intent was to
match each bin's empirical variance exactly, the scale would need to be sigma_k * sqrt((nu-2)/nu) so
that Var(G_hat_t | k) = sigma_k^2. Worth a quick check against the in-sample KS / variance diagnostics
before the exam so the answer is ready if an examiner asks.
