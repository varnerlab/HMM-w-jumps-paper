# Reformulating the Jump-HMM: From a Joint (Regime, Jump) State Space to Regime + Poisson Override

## Provenance and authorship caveat

**This document was drafted by Claude (an LLM assistant) at the request of the principal investigator (Varner) on 2026-04-30, by inspection of the JumpHMM.jl source tree (`varnerlab/JumpHMM.jl`, commit unknown / latest pinned in this course's `Manifest.toml`).** It is *not* a record of the library author's documented design rationale — to my knowledge no such record exists in the repository. The "reasons" given in §5 are *hypotheses* consistent with the code, not interview-elicited intent. Anyone using this writeup as the basis for an arXiv preprint should verify the rationale against the actual author and replace §5 with the genuine reasoning.

The mathematical statements in §2–§4, §6, and §7, and the code-evidence citations in §3, are objective and derived from the source. They should hold up regardless of the design intent.

---

## 1. Summary

The CHEME 5660 paper [`varnerlab/HMM-w-jumps-paper`](https://github.com/varnerlab/HMM-w-jumps-paper) introduced a Hidden Markov Model with stochastic jumps for one-day-ahead market growth-rate density. In that paper, the latent state space was the **product of a regime index $k\in\{1,\dots,N\}$ and a binary jump indicator $j\in\{0,1\}$**, giving a $2N$-state chain. With $N=50$ partition bins the realized state space is $2N = 100$ states.

The implementation used in this course (`varnerlab/JumpHMM.jl`) **does not preserve that joint state space**. Instead, it parameterizes the model with $N$ regime states *plus* a separate Poisson jump-override mechanism that operates on top of the regime chain. The fitted market surrogate used throughout Sessions 1–4 reports `length(emissions) = 50` and `size(transition) = (50, 50)`. There is no $100$-state object anywhere in the live codebase.

The two formulations are **not mathematically equivalent**. They make different assumptions about how jump rate depends on regime, and — important for the regime-aware sentiment notebook in Session 2 — they yield **different forward-filter posteriors over the same observation sequence**, because the JumpHMM.jl forward filter is *jump-blind* (see §6). This document records what changed, what evidence supports the changes, where the two formulations diverge mathematically, and what the implications are for course narrative consistency with the original paper.

---

## 2. Original formulation (paper, $2N$ states)

Let $G_t$ be the day-$t$ continuously-compounded growth rate of the index, and let the partition discretize the support of $G$ into $N$ bins. The original paper defines a latent state

$$Z_t = (k_t, j_t) \in \{1, \dots, N\} \times \{0, 1\}$$

so $|\mathcal{Z}| = 2N$. The transition kernel
$$T_{(k,j) \to (k', j')} \;=\; P(Z_{t+1} = (k', j') \mid Z_t = (k, j))$$
is a $2N \times 2N$ row-stochastic matrix with structural sparsity reflecting the assumption that a jump out of regime $k$ lands in a tail regime $k'$ from the regime-$k$-dependent jump-target distribution. Emissions are conditional on the joint state:
$$G_t \mid Z_t = (k, j) \;\sim\; \mathcal{T}\!\left(\mu_{k,j},\, \sigma_{k,j},\, \nu\right).$$
In practice the paper ties $\mu_{k,1} = \mu_{k,0}$ for non-tail regimes and uses a separate distribution for jump-induced tail regimes.

**Inference**: the standard forward-backward recursion runs on the $2N$-state chain. Posteriors $P(k_t, j_t \mid G_{1:t})$ are computed jointly; marginals over $k_t$ and over $j_t$ are then read off as marginal sums.

**Number of free parameters** (with mild structural ties): the $2N \times 2N$ transition has $\mathcal{O}(N^2)$ rows × $2N$ cols = $\mathcal{O}(N^2)$ free entries, plus $2N$ emission means and scales. With $N=50$: roughly $4 \times N^2 = 10{,}000$ transition entries (sparser if regime/jump are made conditionally independent in transition).

---

## 3. Current formulation (JumpHMM.jl, $N$ states + Poisson override)

The struct definition (`JumpHMM.jl/aSLHo/src/Types.jl:79-88`) is:

```julia
struct JumpHiddenMarkovModel <: AbstractMarkovModel
    partition::LaplacePartition
    transition::Matrix{Float64}        # N × N (no jump dimension)
    emissions::Vector{StudentTEmission} # length N (no jump dimension)
    stationary::Vector{Float64}
    jump::JumpParameters                # ϵ, λ, p_neg, N_tail — global
    ν::Float64
    rf::Float64
    dt::Float64
end
```

So the latent **state space is $\{1, \dots, N\}$ with $N=50$**, and the transition kernel is $N \times N$. The jump mechanism is captured separately in a single `JumpParameters` struct:

```julia
struct JumpParameters
    ϵ::Float64        # per-step Bernoulli jump probability (regime-independent)
    λ::Float64        # Poisson rate for jump-event size (number of consecutive forced steps)
    p_neg::Float64    # probability the jump lands in the negative-tail bucket (default 0.52)
    N_tail::Int       # number of states at each tail edge of the partition (default 5)
end
```

### 3.1 Generative model used by the simulator

From `Simulate.jl`:

```julia
for each step t:
    if ϵ > 0 and rand() < ϵ:
        K ∼ Poisson(λ)              # jump-event length
        if K == 0:
            s ∼ T[s, :]             # normal transition
        else:
            for _ in 1:K:
                if rand() < p_neg:
                    s ∼ Uniform({1, ..., N_tail})              # bottom-tail bucket
                else:
                    s ∼ Uniform({N - N_tail + 1, ..., N})      # top-tail bucket
                emit G_t ∼ Student-t(emissions[s])
                jumps[t] = true
    else:
        s ∼ T[s, :]                  # normal transition
        emit G_t ∼ Student-t(emissions[s])
        jumps[t] = false
```

Two structural commitments worth flagging:

1. **The jump rate $\epsilon$ is regime-independent.** The Bernoulli check `rand() < ϵ` does not depend on the current state $s$. In the paper, jump rate could in principle depend on regime; here it cannot.
2. **The jump-target distribution is tail-fixed**, not regime-conditional. When a jump fires, the target is sampled uniformly over the bottom-`N_tail` or top-`N_tail` partition bins regardless of which regime the chain was in immediately prior. The paper allows the jump-target distribution to depend on the current regime.

### 3.2 The forward filter is jump-blind

This is the most consequential difference for the Session 2 *Regime-Aware Sentiment* notebook. From `Decode.jl:62-122`, the forward filter is implemented as the standard $N$-state HMM forward recursion:

$$\alpha_t(k) \;\propto\; p(G_t \mid s_t = k) \cdot \sum_j \alpha_{t-1}(j) \cdot T_{j \to k}.$$

The recursion **never references `model.jump`**. There is no jump-augmented latent variable in the filter, no marginalization over a jump indicator, no acknowledgment that the simulator could have produced $G_t$ via the override pathway with probability $\epsilon$.

The filter therefore returns posteriors that are **correct under the assumption that the data were generated by the $N$-state HMM with no jumps**, and **biased** when the data were generated by the full simulator (or by real markets if jumps are real). The bias is concentrated on observations following a jump event, where the next several $G_t$ realizations were drawn from tail-bucket emissions but the filter explains them using the standard transition kernel.

In the original $2N$ paper formulation the filter would naturally see jumps because $j_t$ is part of the latent state, and posteriors $P(j_t \mid G_{1:t})$ would be a direct output. In the current JumpHMM.jl formulation that quantity is **not computed by `forward_filter`**.

### 3.3 Number of free parameters

- Transition: $N^2 = 2{,}500$ entries (with row-sum constraints, $N(N-1) = 2{,}450$ free).
- Emissions: $2N = 100$ free parameters ($\mu_k, \sigma_k$ for each state).
- Jump: $4$ scalars ($\epsilon, \lambda, p_{\text{neg}}, N_{\text{tail}}$).

Total: $\sim 2{,}550$ free parameters. The paper's $2N$ formulation has $\sim 10{,}000$ transition entries before any structural ties, so the reduction is $\sim 4\times$.

---

## 4. Mathematical relationship between the two formulations

The two are *not* equivalent. They imply different joint distributions over $(G_1, \dots, G_T)$ in two specific ways:

### 4.1 Regime-conditional jump rate

In the paper:
$$P(\text{jump at } t \mid s_t = k) \;=\; \pi_k.$$
The jump rate is a $k$-indexed vector that is fit from data. In the current implementation:
$$P(\text{jump at } t) \;=\; \epsilon, \qquad \text{independent of } s_t.$$
A single scalar. This is a **strict restriction** — the JumpHMM.jl model class is a subset of the paper's model class.

### 4.2 Jump-target distribution

In the paper: jump-target $s_{t+1}$ given $s_t = k$ has distribution $q_k(\cdot)$ that can vary across regimes (e.g., a calm regime may jump to a different tail than a volatile regime). In the current implementation: jump-target is uniform on bottom-$N_{\text{tail}}$ or top-$N_{\text{tail}}$ with a fixed split $p_{\text{neg}}$, regardless of $s_t$.

Again a **strict restriction**.

### 4.3 Marginal-distribution implications

For a single observation $G_t$ drawn from the stationary distribution, the marginal density under JumpHMM.jl is the mixture
$$f(G) \;=\; (1-\epsilon)\sum_k \pi_k\, f_k(G) \;+\; \epsilon\!\left[p_{\text{neg}}\,\bar f_{\text{neg}}(G) + (1-p_{\text{neg}})\,\bar f_{\text{pos}}(G)\right],$$
where $\bar f_{\text{neg}}, \bar f_{\text{pos}}$ are uniform mixtures over the tail-bucket emissions. Under the paper's $2N$ model, the analogous mixture has regime-conditional weights
$$f(G) \;=\; \sum_k \pi_k \!\left[(1-\pi_k^J)\,f_{k,0}(G) + \pi_k^J\,f_{k,1}(G)\right],$$
which is strictly more flexible. The two collapse to the same marginal only if $\pi_k^J \equiv \epsilon$, $f_{k,1} \equiv \bar f_{\text{tail}}$, and the tail emissions match — a measure-zero subset of the paper's parameter space.

### 4.4 Conditional-distribution implications

The differences in §4.1 and §4.2 imply that conditional moments $E[G_{t+h} \mid G_{1:t}]$ for $h \geq 1$ also differ, since after a jump in the paper's model the chain's regime memory persists differently than in the current formulation. Quantitative impact depends on $\epsilon$ and the regime-dependence of $\pi_k^J$ in real data.

---

## 5. Hypothesized reasons for the change *(speculative — see §1)*

The following are plausible motivations consistent with the code; they are *not* documented intent.

1. **Parameter reduction and identifiability.** A $2N \times 2N$ transition matrix with $N=50$ has $\sim 10{,}000$ entries; estimating it from a decade of daily SPY data ($\sim 2{,}500$ observations) is severely under-determined. Collapsing the jump dimension into a four-parameter `JumpParameters` struct is a sharp regularization that makes the fit identifiable on realistic sample sizes.

2. **Baum-Welch fitting stability.** Joint posteriors $P(k_t, j_t \mid G_{1:t})$ have a multimodality that the EM update is sensitive to (a "calm" interpretation and a "post-jump tail-bucket" interpretation can both fit the same observation). Separating the jump as a global override removes that multimodality from the regime fit.

3. **Tractable posterior computation.** Forward filtering on $N=50$ states is $\sim 4\times$ faster than on $2N=100$. For Session 2's regime-aware sentiment loop, which calls `forward_filter` once per Monte Carlo path (5,000 paths × 336 days), the wall-clock matters.

4. **Interpretability of jump parameters.** $\epsilon, \lambda, p_{\text{neg}}, N_{\text{tail}}$ are directly readable: "jumps happen on $\epsilon$ of trading days, last $\sim\lambda$ days each, $p_{\text{neg}}$ of them are negative, hit one of the $N_{\text{tail}}$ extreme partition bins." Pulling that information out of a fitted $2N \times 2N$ transition matrix requires post-processing.

5. **Tuning workflow.** `JumpHMM.jl/Tune.jl` exposes a wrapper that fixes the regime fit and sweeps $(\epsilon, \lambda)$ to match path-level statistics. With the joint formulation, every $(\epsilon, \lambda)$ candidate would require a refit of the joint transition matrix; with the override formulation, the regime fit is held constant and only `JumpParameters` change.

**Critique of these hypotheses, for completeness.** Reasons 1, 2, and 5 only hold if the paper's $2N$ formulation cannot be fit with structural ties (e.g., $T_{(k,j)\to(k',j')} = T^{(0)}_{k\to k'} \cdot T^{(j)}_{j\to j'}$ assumption of conditional independence between regime and jump transition). With such ties the parameter count of the paper's model can be brought close to JumpHMM.jl's, and Reasons 1/2 weaken. Whether the paper's authors used such ties is not documented in the JumpHMM.jl source.

---

## 6. Implications for the course

### 6.1 The "50 states" print versus the paper's "100 states"

The Session 2 *Regime-Aware Sentiment* notebook prints
```
HMM market model has 50 states: 23 bear (μ<0), 27 bull (μ≥0)
```
A senior student who has read the original paper expects $2N = 100$. The print is *correct for the current implementation* but inconsistent with the paper-of-record. Three resolutions:

- **(a) Notebook-level disclaimer.** Add an aside in the cell explaining that JumpHMM.jl uses an $N$-state regime chain plus a global Poisson override, so the count is regime states only; the paper's $2N$ formulation would have produced $100$. Cheapest, but leaves a discrepancy on the page.
- **(b) Re-fit a $2N$ JumpHMM.** Extend `JumpHMM.jl` with an optional joint-state fitter and fit a $2N$-state surrogate for the course. Most consistent with the paper, highest engineering cost.
- **(c) Update the paper-of-record.** Publish a methodology note (the present document, or a derivative) on arXiv documenting that the production library uses a different parameterization, and reference both. Lowest engineering cost; cleanest scholarly trail.

### 6.2 The regime-aware-$\lambda$ construction

The notebook builds
$$\lambda_t^{\text{regime}} \;=\; 2 \cdot \!\left(P_{\text{bear}}(t) - 0.5\right), \qquad P_{\text{bear}}(t) \;=\; \sum_{k:\, \mu_k < 0} \alpha_t(k)$$
where $\alpha_t(k)$ is the output of `forward_filter`. Because the filter is jump-blind (§3.2), $\lambda_t^{\text{regime}}$ is computed under the implicit assumption that the data were generated by the $N$-state HMM with no jumps. On observations where the simulator did fire a jump, $\alpha_t$ will assign weight to the tail-bucket regimes (since the emission $G_t$ was drawn from a tail emission), but it will not separately report "$j_t = 1$" because there is no such latent dimension in the filter.

Practical consequence: $\lambda_t^{\text{regime}}$ over-attributes jump-induced tail observations to the bear-regime mass when in truth they were jump events (and may not persist into a true regime change). This is a model-mismatch bias that the paper's formulation would not have, because in the paper $\alpha_t$ would explicitly carry $P(j_t \mid G_{1:t})$ and the bear/bull regime mass could be computed conditional on $j_t = 0$.

### 6.3 What the *Why does my prior change not move the table* / *What does daily rebalancing buy* questions look like with this in mind

These questions, raised earlier this session, are downstream of (a) the prior-CCGR anchor and (b) the SIM-residuals iid assumption — *not* of the $2N$ vs $N$+override choice. The reformulation discussed here does not affect them. What it does affect is the *interpretation* of $\lambda_t^{\text{regime}}$ as a regime detector versus as a tail-event detector.

---

## 7. What was actually changed in the JumpHMM.jl repo

To be concrete about what an arXiv methodology note would describe (assuming the paper's $2N$ was the starting point and the library is the endpoint):

| Aspect | Paper ($2N$) | JumpHMM.jl ($N$ + override) |
|---|---|---|
| Latent state space | $\{1,\dots,N\}\times\{0,1\}$ | $\{1,\dots,N\}$ |
| `transition` size | $2N \times 2N$ | $N \times N$ |
| `emissions` length | $2N$ | $N$ |
| Jump rate | $\pi_k$ (per-regime) | $\epsilon$ (global scalar) |
| Jump target | regime-conditional $q_k(\cdot)$ | tail-bucket uniform |
| Forward filter | runs on joint $(k,j)$ | runs on $k$ only |
| Posterior of $j_t$ | first-class output | not computed |
| Free parameters (rough) | $\mathcal{O}(4N^2)$ | $\mathcal{O}(N^2)$ |

---

## 8. References and artifacts

- `varnerlab/HMM-w-jumps-paper` — original CHEME 5660 paper repository.
- `varnerlab/JumpHMM.jl` — current production library.
- `JumpHMM/aSLHo/src/Types.jl:79-88` — current `JumpHiddenMarkovModel` struct.
- `JumpHMM/aSLHo/src/Simulate.jl:6-86` — current generative model.
- `JumpHMM/aSLHo/src/Decode.jl:62-122` — current forward filter (jump-blind).
- This course's instantiation: `MyMarketSurrogateModel()` returns a fitted `JumpHiddenMarkovModel` with $N=50$, $\epsilon, \lambda$ tuned via `Tune.jl`.

---

## 9. Recommended next steps before posting on arXiv

1. **Verify §5 with the JumpHMM.jl author.** Replace the speculative reasons with documented ones (or excise §5 and present this as a pure methodology comparison).
2. **Empirically quantify the §4 differences.** Fit both formulations (or simulate from JumpHMM.jl and refit a $2N$ model from the simulated paths) and report KL divergence on the marginal density and on the conditional density $f(G_{t+1} \mid G_{1:t})$.
3. **Quantify the §6.2 jump-blind-filter bias.** Simulate from JumpHMM.jl with a known $\epsilon > 0$, run `forward_filter` on the paths, and report the discrepancy between $P(s_t \in \text{bear} \mid G_{1:t})$ as computed and as defined under the joint-state filter. This is the load-bearing diagnostic for any regime-aware-$\lambda$ deployment claim.
4. **Decide on the §6.1 resolution path** (notebook disclaimer / re-fit / methodology note).

---

*Drafted 2026-04-30 by Claude (Anthropic), at the request of the course PI, by direct inspection of the JumpHMM.jl source. Not authoritative on author intent.*
