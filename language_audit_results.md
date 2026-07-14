# Language Audit: JFDS Manuscript

## Purpose

This audit reviews the current manuscript for simple, direct, and concise language. It does not revisit the technical audit except where wording obscures the meaning. The goal is to make the paper easier to read without making it informal or imprecise.

## Overall assessment

The paper is difficult to read because it is dense, not because the ideas are inherently hard. The prose often combines four jobs in one sentence:

1. introduce a method;
2. justify the method;
3. report a result; and
4. defend a limitation.

Many paragraphs also repeat information already stated in a table, figure caption, or earlier section. The result is a manuscript that sounds careful but feels effortful.

The main text contains about 12,700 words before the appendix; the appendix adds about 6,200. A focused language edit could remove 20–30% of the main-text prose without losing technical content. The Discussion could be reduced by about one third.

The paper's best voice is plain and factual:

> HMM-WJ reduced ACF-MAE from 0.059 to 0.052, but its KS pass rate was lower than HMM-NJ's.

Its weakest voice uses metaphors, corporate language, or layered qualifications:

> The two findings together draw the tradeoff ... when the same generator feeds univariate and multivariate pipelines ...

The first form is easier to understand and sounds more confident.

## Recommended style rules

### 1. Put the subject and result first

Prefer:

> HMM-WJ reduced ACF-MAE from 0.059 to 0.052.

Avoid:

> On the temporal dimension, HMM-WJ scored 0.052 on ACF-MAE, closing 28% of the gap between the i.i.d. floor and the GARCH ceiling.

### 2. Give each sentence one main job

If a sentence contains two semicolons, several parenthetical clauses, or more than one contrast word (`but`, `while`, `whereas`, `although`), split it.

### 3. Prefer verbs over abstract nouns

| Abstract wording | Direct wording |
|---|---|
| performed an evaluation of | evaluated |
| produced an improvement in | improved |
| provided a comparison of | compared |
| achieved recovery of | recovered |
| imposed a floor on | required at least |
| carried out calibration | calibrated |
| exhibited attenuation | decreased |

### 4. Use technical terms only when they add precision

Keep terms such as `variance`, `autocorrelation`, `tail index`, and `stationary distribution`. Reduce general research jargon such as:

- framework;
- pipeline;
- workflow;
- operating point;
- mechanism;
- artifact;
- downstream use case;
- scope boundary;
- fidelity;
- characterization;
- deployment.

These words are not always wrong, but the manuscript uses them so often that they blur the concrete action.

### 5. Do not turn comparisons into metaphors

Avoid `ceiling`, `floor`, `anchor`, `gap closing`, `sits between`, `feeds`, `carries`, `falls out`, `sweeps in`, `lands inside`, and `draws the tradeoff` when a literal statement is available.

### 6. Report the result once

Choose one place for detailed numbers:

- table or figure caption: define what is shown;
- Results: state the two or three findings that matter;
- Discussion: explain why they matter and state limitations.

Do not repeat the same sequence of values in all three places.

### 7. Cut defensive language

Phrases such as `defensible claim`, `honest percentile`, `not a data-peeked threshold`, `audit trail`, and `what is reproducible is` sound argumentative. State the evidence and limitation directly.

### 8. Use `we` for actions and the model name for results

Prefer:

> We fitted the model to 2014–2024 data. HMM-WJ achieved a 97.6% KS pass rate.

This is clearer than making `the framework`, `the construction`, or `the pipeline` the subject of every sentence.

## Words and phrases to replace

| Current phrase | Suggested replacement |
|---|---|
| faithfully preserve | reproduce |
| central challenge | difficult problem, or delete |
| plausible but unobserved market scenarios | unobserved market scenarios |
| Bridging the gap ... requires | A useful model must ... |
| closing the volatility-clustering gap | improving volatility clustering |
| closed this limitation | corrected this variance increase |
| surfaced an artifact | found a bias |
| sits between two incomplete baselines | trades off the strengths of two baselines |
| inherited the historical realization wholesale | resampled only observed returns |
| carried the best temporal score | had the lowest ACF error |
| paid a small distributional cost | reduced distributional fit |
| the two findings together draw the tradeoff | together, these results show |
| feeds univariate and multivariate pipelines | is used for both single- and multi-asset simulations |
| left an audit trail | recorded the selected branch |
| set aside two questions | did not test two issues |
| the two deferred questions compose | these two issues interact |
| a separate scope boundary concerns | we also did not test |
| natural extension | possible extension |
| carries enough variance | has enough variance |
| carries an increasing share | accounts for a larger share |
| makes explicit | shows |
| lands inside the ensemble | falls within the ensemble |
| an honest percentile | the 63rd percentile |
| the pieces combine into | Algorithm 2 summarizes the method |
| falls out deterministically | follows directly |
| without sweeping in single names | without including individual stocks |
| the cumulative distribution sorts itself cleanly | the two groups were separated in this sample |
| loss is auditable | the output records this loss |
| path taken per asset | branch used for each asset |
| body-fidelity gap propagated into VaR accuracy | distributional differences affected VaR coverage |
| mechanism panel made ... explicit | right panel shows |
| hybrid sat on the unit line | hybrid remained near one |
| naive collapsed | the naive pass rate fell |
| stability mechanism rather than a degradation | clipping maintained or improved the KS pass rate |
| operating point | selected parameter values |
| headline analysis/result | main analysis/result |
| in play | considered |

## Section-by-section audit

## Abstract

### Main problem

The abstract is 274 words and contains three papers' worth of claims: the univariate model, multi-asset composition, and allocator correction. Almost every sentence contains multiple clauses. The reader must retain too many details before learning the main result.

### Specific issues

- Lines 4–8 open with a long list and the phrase `underpin`, which is less direct than `are used for`.
- Lines 8–13 stack three model components into one sentence.
- Lines 14–18 list every baseline. The list interrupts the argument.
- Lines 19–23 say `only addition`, `meaningfully`, and `without sacrificing`, but do not give the size of the tradeoff.
- Lines 24–30 compress the full SIM contribution into one long sentence.
- Lines 31–34 introduce the allocator correction too late and with `surfaced` and `anchored`.

### Recommended target

Reduce the abstract to 180–210 words. Use this order:

1. problem;
2. method;
3. SPY result and tradeoff;
4. multi-asset variance result;
5. one-sentence limitation;
6. code availability.

The allocator location shift should be omitted from the abstract unless it remains a central contribution.

### Example of a plainer abstract

> Synthetic equity returns should reproduce heavy tails, weak autocorrelation in raw returns, and persistent autocorrelation in absolute returns. We developed a discrete-state Markov generator that assigns returns to Laplace-quantile states, samples state-specific Student-t emissions, and uses Poisson-distributed tail episodes to increase volatility persistence. We fitted the model to SPY data from 2014–2024 and evaluated it on 2025 data against seven baseline generators. The jump model retained strong distributional fit and reduced the absolute-return autocorrelation error from 0.059 for the no-jump model to 0.052, although GARCH achieved the lowest error at 0.031. We then used a single-index model to generate correlated returns for 424 US equities and exchange-traded funds. A closed-form scale correction removed the variance increase caused by adding the market factor. The corrected composition recovered factor loadings and retained heavy-tailed returns, but dedicated residual models fit the center of the distribution more closely. Independent residual draws can also overstate gains from daily rebalancing because they omit cross-asset residual dependence. Code and fitted marginal models accompany the paper.

This version is still technical, but each sentence makes one claim.

## Introduction

### Main problem

The Introduction starts clearly, but the final two paragraphs become a compressed Methods and Results section. Lines 71–115 introduce the HMM, its estimation, its emissions, the full baseline set, all validation metrics, the SIM correction, the allocator bias, the location shift, and the VaR check. This is too much for one contribution statement.

### Specific edits

#### Lines 10–17

Current:

> Generating synthetic financial time series that faithfully preserve the statistical properties of real market data is a central challenge in quantitative finance.

Direct:

> Synthetic financial data often fail to reproduce the statistical properties of real returns.

The following list of applications can be shortened to three items.

#### Lines 18–30

The definition of the three stylized facts is useful. Split the sentence at lines 24–28:

> SPY returns from 2014–2024 show all three patterns (Fig. 1). Their distribution is sharply peaked and heavy-tailed. Raw returns have little autocorrelation, while absolute returns remain correlated over time.

#### Lines 50–69

This literature summary is readable but repetitive. Four consecutive sentences use the pattern `model family captures X but fails Y`. Combine them into a compact comparison and remove `Bridging the gap`.

Suggested closing sentence:

> We therefore sought a model that retained distributional fit while improving volatility persistence and remaining practical for many assets.

#### Lines 71–92

This paragraph should state the contribution, not reproduce the entire study design. Remove the complete metric and baseline lists. They belong in Methods.

Possible version:

> We developed a discrete-state return generator with Laplace-quantile states, Student-t emissions, and Poisson-distributed tail episodes. State assignments allow direct estimation of the transition matrix. We fitted the model to SPY returns from 2014–2024 and evaluated it in and out of sample against parametric, semi-Markov, bootstrap, and neural baselines.

#### Lines 94–115

This paragraph introduces three additional issues. Keep the SIM correction here, but reduce the allocator and VaR material to one sentence each or move them to the end of Methods.

Replace `We closed this limitation with a closed-form variance correction` with:

> We derived a scale factor that restores the target asset variance after adding the market factor.

Replace `We corrected the resulting level inflation` with:

> We report this bias and a prior-based level adjustment, but the adjustment does not restore the missing cross-asset dependence.

## Related Work

### Main problem

The section reads as a historical survey rather than a focused argument for this model. The first paragraph moves from Bachelier through Black–Scholes, Mandelbrot, Fama, ARCH, stochastic volatility, and jump diffusion. Much of this is correct but not necessary for the paper's contribution.

### Recommendation

Reduce the section from about 870 words to 550–650. Organize it around three direct comparisons:

1. methods for heavy tails and volatility clustering;
2. HMM and HSMM duration models;
3. multi-asset dependence and factor models.

Remove phrases such as:

- `picks the latent-state route`;
- `sparse intervention`;
- `the body of the chain keeps`;
- `at the cost of copula-family selection`.

Use literal descriptions of how the methods differ.

## HMM Method

### Main problem

The section mixes definitions, motivations, caveats, literature positioning, and figure explanation. Several sentences define five symbols at once. The model can be described more simply.

### Recommended order

1. data and return definition;
2. state partition;
3. emissions;
4. transition estimates;
5. tail episodes;
6. parameter selection.

Do not justify every design decision in the same paragraph where it is defined.

### Examples

Current, around lines 29–42:

> We defined the hybrid hidden Markov model with jump-duration mechanism ... as the tuple ... where the hidden state ..., the observation ..., the observation space ..., the transition matrix ..., the emission model ..., and the stationary distribution ...

Recommendation: keep the tuple, then define the components in two or three sentences or a compact notation table.

Current:

> the observation was the per-ticker growth rate ... with the asset index suppressed when only one ticker is in play

Direct:

> For a single asset, we write the observed growth rate as \(G_t\).

Current:

> the discrete state assignments allowed straightforward counting of observed transitions

Direct:

> We estimated each transition probability from observed state-transition counts.

Current:

> the short-horizon window in which the empirical ACF ... carries most of its variation

Direct:

> We used lags 1–25 because most of the observed ACF variation occurs in that range.

### Parameterization caveats

The Student-t scale explanation is accurate but interrupts the model definition. Put the equation and scale definition in the main text; move the full variance explanation and sensitivity grid to a short note or appendix.

The paragraph explaining why `jump-duration` is not a continuous-time diffusion is also awkward because it discusses naming rather than the method. State the model directly:

> This is a discrete-time state model; it does not include a continuous diffusion process.

## SIM Method

### Main problem

This section is mathematically clear but verbally overexplained. The algebra already shows the reasoning, yet the prose repeats every step. It also uses `branch`, `pipeline`, `auditable`, `falls out`, and `the pieces combine`, which make a simple scale correction sound more elaborate than it is.

### Recommended cuts

- Lines 29–43: reduce the Gaussian baseline discussion by about half.
- Lines 45–67: keep the variance derivation; delete prose that repeats each displayed line.
- Lines 119–166: simplify the tracker exception. This is the hardest paragraph in the section.
- Lines 168–203: Algorithm 2 already summarizes the procedure. Reduce the preceding paragraph to the three guarantees and one limitation.

### Specific examples

Current:

> Any fixed parametric residual family ... inherits the same limitation: pinning the residual to a separate distribution discards the per-asset marginal we already have.

Direct:

> A separately fitted residual distribution does not retain the fitted full-return marginal.

Current:

> the cumulative distribution sorts itself cleanly ... captures the trackers without sweeping in single names

Direct:

> In this sample, the two index ETFs had \(R^2>0.80\), while all individual stocks had \(R^2<0.65\). We therefore used 0.80 as the threshold.

Current:

> the SPY-against-itself identity ... falls out deterministically without special-casing

Direct:

> When \(R^2=1\), Eq. 10 sets the residual variance to zero.

Current:

> The pieces combine into a single procedure.

Direct:

> Algorithm 2 summarizes the procedure.

Current:

> recorded alongside the output so the path taken per asset can be recovered without external bookkeeping

Direct:

> The output records the branch used for each asset.

### Terminology

`Composer` is implementation language. In the paper, prefer `composition method` or `method` unless `composer` is defined once as a formal term.

## Results

### Main problem

The Results section is about 4,000 words with no subsections. It contains ten long narrative blocks, extensive setup that belongs in Methods, and repeated interpretation of figures and tables. This is probably the largest source of reading difficulty.

### Add short descriptive subsections

Suggested structure:

1. `Single-asset fit and temporal tradeoff`
2. `Multi-asset composition`
3. `VaR coverage`
4. `Sensitivity analyses`

These headings are functional, not decorative. They let readers locate the main results.

### Move protocol text to Methods

Move or sharply shorten lines 218–298, which define:

- the 424-asset universe;
- jump settings;
- six composition methods;
- paired innovations;
- all evaluation metrics;
- replication counts.

Results should not spend roughly 800 words explaining the experiment after the results have begun.

### Remove argumentative setup

Current, lines 31–36:

> the specific argmin is not the defendable claim; the empirically reproducible claim is that the chosen operating point delivers strong distributional and temporal fidelity

Direct:

> Several grid points had similar objective values. We therefore interpret \((10^{-4},100)\) as one suitable setting rather than a unique optimum.

Current:

> Bootstrap resampling set the non-parametric ceiling ... Gaussian anchored the thin-tailed floor. Between these anchors ...

Direct:

> Bootstrap had the best marginal fit. Gaussian sampling had the worst. GARCH had the lowest ACF error but poor marginal fit.

Current:

> HMM-WJ scored 0.052 on ACF-MAE, closing 28% of the gap between the i.i.d. floor and the GARCH ceiling

Direct:

> HMM-WJ reduced ACF-MAE from 0.059 for HMM-NJ to 0.052. GARCH achieved 0.031.

Percent-of-gap calculations add cognitive load without adding much information.

### Compress model comparison

The paragraph explaining Table 1 should identify only the main tradeoffs:

- HMM-NJ had the best parametric marginal fit.
- HMM-WJ improved temporal fit but slightly reduced marginal pass rates.
- GARCH had the best temporal fit and weak marginal fit.
- bootstrap reproduced the empirical marginal but added no new temporal structure.

The table contains the remaining detail.

### Simplify multi-asset results

Current:

> With the per-asset marginals validated ... we evaluated ... and asked whether those validated marginals composed into a multi-asset construction without breaking either target.

Direct:

> We next tested whether SIM composition preserved each asset's variance and factor loading.

Current:

> The differences between composers appeared everywhere else.

Direct:

> The methods differed in \(R^2\), marginal fit, and tail behavior.

Current:

> The advantage sat in the body of the distribution rather than the tails.

Direct:

> Residual-fit methods improved the center of the distribution but had similar tail estimates.

### Reduce figure-caption interpretation

Several captions explain not only what the figure shows but also the causal interpretation. Keep captions descriptive. Put the interpretation in one or two Results sentences.

For example, the preservation figure caption can be reduced to:

> Per-ticker KS pass rates and variance ratios versus calibrated \(\beta\). Points show ticker medians across 100 replications; lines show binned medians. The dashed line in panel B marks a variance ratio of one.

### Avoid theatrical verbs

Replace:

- `naive collapsed` with `the naive pass rate fell`;
- `hybrid sat on the unit line` with `the hybrid ratio remained near one`;
- `we traced where the advantage came from` with `we compared the variance ratio with \(\beta\)`;
- `clipping is a stability mechanism rather than a degradation` with the observed result: `under stress, clipping increased the KS pass rate`.

## Discussion

### Main problem

The Discussion repeats most of the Results, then adds long lists of caveats, deferred questions, and proposed extensions. It is about 2,700 words. A reader reaches the same numbers several times before reaching the limitations that matter.

### Recommended target

Reduce the Discussion to 1,600–1,900 words with four subsections or clearly separated paragraphs:

1. main single-asset result;
2. multi-asset result;
3. limitations;
4. next work.

### Paragraph 1: do not replay the table

Lines 7–44 repeat nearly every baseline result. Replace them with one short synthesis:

> HMM-WJ improved volatility persistence relative to HMM-NJ but slightly reduced marginal fit. GARCH had the lowest ACF error, while HMM-NJ had the strongest parametric marginal fit. The model therefore offers a tradeoff rather than a uniformly better result.

Then state the KS/AD dependence caveat.

### Paragraph 2: shorten caveats

The three caveats can be stated in six direct sentences:

- 100 states worked for the SPY sample but may be too many for shorter histories.
- Jump parameters were selected for SPY and may not transfer to other assets.
- Student-t emissions improved kurtosis but do not model skewness directly.

Remove `defensible`, `operating point`, `refinement`, and `at the cost of`.

### Multi-asset discussion

Lines 76–125 contain useful content but repeat the method and all six baselines. Start with the result:

> The variance correction reduced the variance error and improved KS pass rates relative to naive composition. Residual-fit methods still had better marginal fit, while all four heavy-tailed methods had similar 99% VaR coverage.

Then explain the tradeoff in no more than one paragraph.

### Deferred questions

Lines 127–162 are especially hard to read because they discuss `questions that compose`, `layers`, `scope boundaries`, and `framing`. Replace this with a direct limitation list:

> We did not simulate the market factor or impose cross-asset residual dependence. We also evaluated VaR by ticker rather than at the portfolio level. These choices isolate the variance correction but do not validate a full joint market simulator.

### Allocator section

Lines 244–303 remain too long and defensive. The key message is:

> Independent residuals may overstate diversification returns because they omit cross-asset residual covariance. In one 20-asset example, the synthetic median exceeded the real 2025 return by about 22 percentage points. We applied a constant drift adjustment to match an external long-run prior. This changes return levels and drawdowns and does not restore the missing covariance.

Most discussion of `honest percentiles`, `ensemble-shape information`, rejected alternatives, and why the correction is not circular belongs in the appendix.

The phrase `an honest percentile` should be removed. A percentile is a calculation, not a moral property.

### Final paragraph

The four extensions can be a short list or four simple sentences. Avoid describing each as `natural`, `structural`, `most consequential`, or `precisely the regime`.

## Conclusion

### Main problem

The conclusion is only 336 words, but it restates methods, many results, the VaR analysis, the allocator example, and the correction. It reads like another abstract.

### Recommended target

Use 180–230 words. State:

1. what was developed;
2. the main tradeoff;
3. what the SIM correction achieved;
4. the main limitation.

### Example of a plainer conclusion

> We developed a discrete-state return generator with Laplace-quantile states, Student-t emissions, and Poisson-distributed tail episodes. For SPY, the jump model improved absolute-return autocorrelation relative to the no-jump model but slightly reduced marginal goodness-of-fit. GARCH retained the lowest autocorrelation error, so HMM-WJ should be viewed as a tradeoff between marginal and temporal fit rather than as the best model on every metric.
>
> We also derived a scale correction for single-index composition. The correction restored each asset's target variance and recovered its factor loading across 423 non-market assets. It retained heavy-tailed behavior, although models fitted directly to residuals reproduced the center of the distribution more closely. The current multi-asset implementation does not model cross-asset residual covariance. This omission can overstate diversification gains in rebalanced portfolios. A full joint residual model is therefore needed before using these paths for portfolio-level return forecasts.

This conclusion ends with the most important limitation instead of adding a separate correction story.

## Appendix

### Main problem

The appendix often explains routine algebra one manipulation at a time. This may help a classroom audience but slows a journal reader.

### Recommended cuts

- In the Taylor expansion, do not narrate every distribution, substitution, and grouping step. State the expansion, show the result, and define the terms.
- Remove phrases such as `To make the consequences precise`, `We expand this in two stages`, `distributing`, `pulling outside the sums`, and `applying the identity` when the equations already show them.
- Reduce the allocator correction defense. State what the transform does and does not preserve.
- Shorten captions that restate full Results paragraphs.
- Keep detailed validation definitions, but avoid explaining standard statistics twice.

### Example

Instead of several paragraphs explaining the expansion of

\[
\log\sum_i w_i e^{g_i\Delta t},
\]

write:

> A second-order expansion in \(\Delta t\) gives
> \[
> g_p(t)=\sum_iw_i g_i(t)+\frac{\Delta t}{2}
> \left[\sum_iw_i g_i(t)^2-\left(\sum_iw_i g_i(t)\right)^2\right]
> +O(\Delta t^2).
> \]
> Taking expectations under stationarity yields Eq. X.

That is sufficient for the intended audience.

## Repetition audit

The following points appear too many times:

### Jump tradeoff

Repeated in the abstract, Introduction, Results, figure captions, Discussion, Conclusion, and appendix emission comparison. Keep the full result in Results, summarize it once in Discussion, and state it in one clause in the abstract and conclusion.

### Variance inflation formula

Repeated in Methods, Results, captions, Discussion, Conclusion, and appendix derivation. Show the derivation in Methods. Elsewhere, refer to `the variance correction` without re-explaining \(\beta_i^2\sigma_m^2\).

### Residual-fit versus full-return tradeoff

Repeated in Results and Discussion in nearly identical language. Results should report the numbers. Discussion should state why a user might choose one method over the other.

### Cross-sectional dependence limitation

Repeated in the Introduction, Methods, Discussion, and appendix. State the assumption in Methods, its consequence in Discussion, and the derivation in the appendix.

### Location-shift correction

The main text mentions the correction in the abstract, Introduction, Discussion, and Conclusion. If retained, describe it once in Discussion and derive it in the appendix. It does not need to appear in both the abstract and conclusion.

## Suggested editing workflow

### Pass 1: structural cuts

- Add Results subsections.
- Move experimental protocol from Results to Methods.
- Cut the Discussion by one third.
- Decide whether the allocator correction is a main contribution or an appendix limitation.

### Pass 2: sentence cuts

For each paragraph:

1. underline the one sentence that states the paragraph's point;
2. move that sentence first;
3. delete repeated setup and defense;
4. split sentences longer than about 35 words;
5. replace metaphors with literal statements.

### Pass 3: terminology

Search for and review every use of:

```text
framework
pipeline
workflow
artifact
mechanism
fidelity
operating point
scope
gap
ceiling
floor
anchor
carry
sit
land
surface
meaningfully
by construction
at the cost of
```

Do not remove every occurrence automatically. Keep only those that are clearer than a concrete alternative.

### Pass 4: captions

- Define panels and symbols.
- State sample sizes.
- Remove argumentative conclusions and repeated Results prose.

### Pass 5: read aloud

Read the abstract, first sentence of every paragraph, and conclusion aloud. If the first sentence does not state the paragraph's subject and point, rewrite it.

## Priority list

### Highest priority

1. Rewrite the abstract to about 200 words.
2. Split Results into four subsections and move protocol material to Methods.
3. Cut the Discussion by about one third.
4. Remove metaphorical comparison language (`floor`, `ceiling`, `sits between`, `gap closing`).
5. Reduce the allocator correction to one direct limitation paragraph in the main text.

### Medium priority

6. Shorten the Related Work history.
7. Simplify the tracker branch explanation in the SIM method.
8. Remove result interpretation from long captions.
9. Compress standard algebra in the appendix.

### Final polish

10. Standardize `model`, `method`, and `composition method`; reduce `framework`, `pipeline`, and `composer`.
11. Replace argumentative words such as `defensible`, `honest`, and `auditable`.
12. Check that each paragraph begins with its main point.

## Bottom line

The manuscript does not need more elegant language. It needs less language. Its strongest claims are already supported by equations and tables. State those claims early, use literal verbs, and let the evidence do the persuasive work.

---

# Author Response to the Language Audit (2026-07-14)

## How we handled this audit

We ran the edit section by section, in reading order (Abstract →
Introduction → Related Work → HMM Method → SIM Method → Results →
Discussion → Conclusion → Appendix), each section checked before
moving to the next. Before starting, we resolved three places where
this audit's recommendations conflicted with standing writing
conventions for this manuscript; those resolutions were binding for
the whole pass rather than re-litigated per section (see below).
Cross-cutting items (the terminology hit list, defensive-language
removal, the repetition audit) were applied at every section as part
of the same read-through rather than as a separate pass.

Word counts below are approximate (LaTeX macros and math mode
stripped with a regex, not a true prose word count), reported to show
direction and rough magnitude, not to the word.

Legend: **DONE** (recommendation applied as given), **ADOPTED**
(recommendation applied, with the specific form decided by resolving
a conflict below), **PARTIAL** (applied in part; the gap is
described), **DECLINED** (recommendation not applied as literally
stated, with rationale), **N/A** (recommendation did not apply to
this manuscript's content).

## Conflicts with standing conventions, resolved before starting

These three points in the audit's advice conflicted with existing,
deliberate choices for this manuscript. We resolved them once,
up front, rather than per section:

1. **Results subsections — ADOPTED as a one-time exception.** This
   manuscript's house style avoids subsection headings in Results.
   We made a deliberate exception for this JFDS submission because
   Results was approximately 4,000 words with no internal structure
   and was the single largest readability problem the audit
   identified. Results now has four functional subsections: "Single-asset
   fit and temporal tradeoff," "Multi-asset composition," "VaR
   coverage," and "Sensitivity analyses." Discussion stays
   subsection-free, tightened and reordered instead, per the house
   style.
2. **Appendix algebra — DECLINED the letter, ADOPTED the intent.**
   The audit's Appendix section recommends not narrating "every
   distribution, substitution, and grouping step" and gives an
   example that collapses a multi-line expansion into a single
   result. This manuscript's convention is to show every algebra step
   in multi-line `align` blocks with right-margin rule annotations,
   because collapsed derivations have previously drawn strong
   objections. We kept every step and every `align` block. What we
   cut was the *prose that narrated the steps a second time*
   ("we expand this in two stages," "distributing $w_i$ across the
   bracketed terms," "pulling the $\Delta t$ factors outside the
   sums") where the align block's own annotations, e.g. `(Taylor)`,
   `(distribute)`, `(plug in)`, `(group)`, already say exactly that.
   This satisfies the audit's actual complaint (redundant narration)
   without collapsing derivations.
3. **"Mechanism" — kept as the settled model name, killed
   elsewhere.** This term is deliberately part of the model's name
   (the paper's subtitle contains "a Jump-Duration Mechanism," chosen
   the same day this audit was run) and appears in the model's first
   definition and in figure/algorithm captions naming it; those uses
   were kept. Every *generic* use elsewhere ("the persistence
   mechanism," "a stability mechanism," "the mechanism is the
   rebalancing rule itself") was rewritten to something literal, per
   the audit's own jargon-reduction list.

We also did not flatten the prose into strings of short declaratives.
The audit's own example rewrites lean toward short, choppy sentences;
we treated those as a floor to cut down to, not a literal template,
and combined closely related short sentences with subordination
("which," "so that," "while") where a string of declaratives would
have read as disconnected, per this manuscript's standing
flowing-prose preference.

## Section-by-section disposition

**Abstract — DONE, target range not hit exactly.** Rewrote using the
audit's suggested order (problem, method, SPY result and tradeoff,
multi-asset variance result, one-sentence limitation, code
availability) and cut the `underpin`/`faithfully preserve`-style
language. Landed at approximately 226 words against the audit's
180–210 target; we judged every remaining sentence load-bearing and
did not cut further to hit the target exactly. The allocator
location-shift correction was reduced to the one-sentence limitation
the audit suggested, not removed outright.

**Introduction — DONE.** Split the compressed final two paragraphs
(which had become a second Methods-and-Results section) using
close variants of the audit's suggested rewrites: the contribution
paragraph now states the model and evaluation design without
reproducing the full metric and baseline lists, and the SIM/allocator/VaR
material is reduced to one sentence each. Approximately 501 words.

**Related Work — DONE, on target.** Reduced from approximately 835
to approximately 650 words (audit target: 550–650), reorganized
around the audit's three suggested comparisons (heavy tails and
volatility clustering; HMM/HSMM duration models; multi-asset
dependence and factor models) rather than a chronological survey.
Removed the flagged metaphors (`picks the latent-state route`,
`sparse intervention`, `the body of the chain keeps`, `at the cost of
copula-family selection`).

**HMM Method — DONE.** Reordered to the audit's suggested sequence
(data/return definition, state partition, emissions, transition
estimates, tail episodes, parameter selection) and moved
design-decision justification out of the same paragraph as each
definition. The Student-t scale explanation was tightened per the
audit's suggestion; the "jump-duration is not a diffusion" naming
discussion was replaced with the audit's suggested direct statement.

**SIM Method — DONE.** Cut the Gaussian-baseline discussion, removed
prose that repeated each displayed derivation line, and rewrote the
`R^2`-preserving-branch exception (the section the audit itself
called "the hardest paragraph") using close variants of the audit's
suggested direct replacements. `Composer` was standardized to
`composition method` throughout Methods.

**Results — DONE.** Added the four subsections described above and
moved roughly 800 words of universe-construction, jump-setting, and
metric-definition protocol into Methods, out of Results. Removed the
argumentative setup language (`the specific argmin is not the
defendable claim`, `Bootstrap resampling set the non-parametric
ceiling`) using the audit's own suggested direct replacements, and
removed percent-of-gap framing (`closing 28% of the gap`) in favor of
stating both raw values.

**Discussion — DONE, cut deeper than the target.** Cut from
approximately 2,704 to approximately 1,104 words against the audit's
1,600–1,900 target; every remaining sentence carried a distinct fact,
so we did not pad back toward the target range. Structured as the
audit recommended (single-asset result + caveats, multi-asset result
+ caveats, diversification-return bias + correction, open
extensions), each as its own paragraph rather than scattered mentions.
The allocator/bias-correction material (audit's "Allocator section")
is now one paragraph in Discussion, with the percentile-placement,
rejected-alternatives, and "honest percentile" material moved to the
Appendix as the audit suggested; `an honest percentile` itself was
removed, not softened.

**Conclusion — DONE.** Cut from 336 to approximately 228–236 words
(audit target: 180–230), using the audit's suggested four-part
structure (what was developed, the main tradeoff, what the SIM
correction achieved, the main limitation) and ending on the
cross-asset residual-covariance limitation rather than restating the
allocator correction.

**Appendix — DONE, per the resolved conflict above.** Cut the
narrating prose around every derivation (see conflict #2) without
collapsing any algebra. Applied the full terminology kill list within
the appendix specifically: `artifact` → `bias` throughout the
bias-correction section (S2) to match Discussion's established
`diversification-return bias` term; `anchor`/`anchoring` → literal
phrasing; `operating point` → `parameter values`/`fitted` (the
appendix was the last file using this term; it now has zero
occurrences manuscript-wide); `pipeline`/`framework` →
`construction`/`procedure`; `composer` → `composition method`
(appendix was also the last file needing this swap); generic
`mechanism` → literal (e.g. "the persistence mechanism" comparing
HSMM dwell times against the jump-duration override → "the duration
model"); `smoke test` removed (software-testing jargon, not in the
audit's own list but caught by the same discipline); `sat`/`sits`/`sitting`
→ `clustered`/`remained near`/`falls`/`being below`. The one table
caption the audit quotes almost verbatim as an example
(`Clipping is a stability mechanism...`) was rewritten to state the
observed result directly, matching the audit's own suggested rewrite
for that exact sentence. We additionally caught and fixed one
undefined implementation-jargon term the audit did not flag,
`engine`/`engine-raw` (describing the pre-correction ensemble) →
`raw`, including renaming the $W_{\mathrm{engine}}$ subscript in one
equation to $W_{\mathrm{raw}}$ (the only symbol rename in the whole
pass), and two stray uses of "jump" as a generic verb ("the
static-to-daily jump of +27.73pp") that read as confusable with the
paper's actual jump-duration mechanism, replaced with "increase."

## Recommended style rules — disposition

1. Subject and result first — **DONE**, applied throughout.
2. One job per sentence — **DONE**, applied throughout; see the
   register note above on not over-flattening.
3. Verbs over abstract nouns — **DONE** for the specific pairs in
   the audit's table; we did not run a mechanical find-replace for
   every abstract noun in the manuscript, only where it changed a
   sentence the pass otherwise touched.
4. Technical terms only when precise — **DONE**; see the terminology
   kill list disposition below.
5. No metaphors for comparisons — **DONE**, with one clarification:
   we kept literal, non-metaphorical uses of `gap` (e.g. "the
   kurtosis gap," a numeric difference between two reported values)
   and killed only the metaphorical constructions the audit's own
   examples target (`gap closing`, `sits between... anchors`,
   `draws the tradeoff`). The audit's rule 5 gives `ceiling`,
   `floor`, `anchor`, `gap closing`, `sits between`, etc. as a set,
   not a blanket ban on the word `gap`; we read it that way and it
   held up under a full-manuscript grep.
6. Report the result once — **DONE**; see the repetition audit
   disposition below.
7. Cut defensive language — **DONE**. `defensible`, `honest`,
   `auditable`, `audit trail`, and `not a data-peeked threshold` no
   longer appear in rendered prose anywhere in the manuscript
   (grepped to confirm).
8. `We` for actions, model name for results — **DONE**, applied
   throughout; this was largely already the manuscript's practice.

## Terminology kill list — disposition

Grepped the full manuscript (all `.tex` files under
`jfds-paper/sections/`) after the pass to confirm: `framework`,
`pipeline`, `workflow`, `operating point`, `composer` (as a noun for
a method), `anchor`/`anchoring`, `auditable`, `honest`, `defensible`,
and generic `mechanism` all have **zero occurrences in rendered
prose**. `artifact` has two surviving occurrences, both in
`results.tex`/`appendix.tex`, both the standard statistical idiom
"not a sample-size artifact"/"artifacts of the simulation seed,"
which the audit's own rule 4 table does not target (it targets
`surfaced an artifact`, describing the diversification-return
finding, which was fully replaced with `bias`).

Three terms were kept deliberately, as literal rather than
metaphorical usage, and we flag this explicitly since the audit's
list could be read as a blanket ban:

- `gap` — kept for literal numeric differences ("the kurtosis gap
  closed from 5.5 to 7.6," "a two-order-of-magnitude gap between
  natural residence times and the jump-duration override"). Killed
  everywhere it appeared in a metaphorical construction ("gap
  closing," "percent of the gap").
- `floor` — kept only as `idiosyncratic floor` $f$, a formally
  defined free parameter in the SIM composition method (Methods,
  Eq. for the clip rule), not a metaphor. Killed the metaphorical
  `i.i.d. floor` (audit's own example), replaced with `i.i.d.
  baseline`.
- `sample-size artifact` — kept as a standard statistical idiom
  (see above).

## Repetition audit — disposition

- **Jump tradeoff (ACF-MAE 0.059→0.052)** — **DONE**. Full result in
  Results; one clause each in Abstract and Conclusion; a callback in
  the Appendix's emission/HSMM comparison table, which reports the
  same metric for a different model comparison (HSMM vs. HMM-WJ),
  not a restatement of the same claim. Not repeated in Discussion's
  own prose (Discussion states the tradeoff without re-citing the
  exact ACF-MAE values).
- **Variance-inflation formula ($\beta_i^2\sigma_m^2$)** — **PARTIAL**.
  The full derivation appears only in Methods and Appendix S8, as
  recommended. The formula itself (not its derivation) still appears
  inline at three sites (Discussion, Results, and twice inside
  Methods' Algorithm 2 pseudocode) where it is the direct object of a
  short numerical claim; we judged the symbol shorthand clearer than
  a purely verbal callback at those sites and did not remove it.
- **Residual-fit vs. full-return tradeoff** — **DONE**. Results
  reports the numbers once; Discussion states the tradeoff without
  repeating the same numbers in near-identical language.
- **Cross-sectional dependence limitation** — **DONE**. Assumption
  stated in Methods, consequence in Discussion, derivation in the
  Appendix, per the audit's suggested split.
- **Location-shift correction** — **DONE**. Confirmed by grep: the
  "$22$ percentage points" figure now appears only in Discussion and
  the Appendix, not in the Abstract, Introduction, or Conclusion.

## Priority list — disposition

**Highest priority.** (1) Abstract rewrite — DONE, see above. (2)
Results subsections + protocol move — DONE. (3) Discussion cut by
~1/3 — DONE, cut deeper (~59%). (4) Remove metaphorical comparison
language — DONE, with the literal-`gap`/`floor` clarification above.
(5) Reduce the allocator correction to one direct limitation
paragraph in the main text — DONE; it is now a single paragraph in
Discussion, with supporting detail (rejected alternatives, percentile
placement) moved to the Appendix.

**Medium priority.** (6) Shorten Related Work history — DONE, on
target. (7) Simplify the tracker-branch exception in SIM Method —
DONE. (8) Remove result interpretation from long captions —
**PARTIAL**; captions that this pass touched directly (Table 3's
clipping caption, several Appendix figure captions) were tightened to
description-only, but we did not run a dedicated caption-by-caption
audit independent of the section-by-section pass, so some
interpretation may remain in captions the audit did not quote as
examples. (9) Compress standard algebra in the appendix —
**DECLINED the literal ask, ADOPTED the intent**; see conflict #2
above.

**Final polish.** (10) Standardize `model`/`method`/`composition
method`; reduce `framework`/`pipeline`/`composer` — DONE, confirmed
by grep (zero remaining occurrences in rendered prose). (11) Replace
argumentative words (`defensible`, `honest`, `auditable`) — DONE,
confirmed by grep. (12) Check that each paragraph begins with its
main point — DONE; this was already a standing house convention for
this manuscript (a "paragraph opener" rule predating this audit) and
was reinforced, not newly introduced, during this pass.

## Issues we found ourselves, beyond the audit's own scope

- Three soft section self-references from an earlier editing pass
  (`method_hmm.tex`'s "(validated empirically in Results)",
  `method_sim.tex`'s "Methods describes a closed-form variance
  correction" and "developed in Methods") were caught and removed;
  none of these appear in the audit's own suggested-replacement text.
- A `Value-at-Risk (VaR)` acronym-chain break: the Introduction's VaR
  paragraph was cut as part of this pass, and it had been the only
  place the acronym was ever spelled out. Fixed by moving the `(VaR)`
  definition to its new first remaining use, in Results.
- Two generic uses of "mechanism" that survived the initial
  Results/SIM Method passes (`method_sim.tex`: "a per-ticker-tuned
  jump mechanism," a figure-panel label and one prose sentence in
  `results.tex`: "the mechanism directly") were caught while
  preparing this response document and fixed (panel label now reads
  "cause," matching the paired "consequence" label on the other
  panel; the jump mechanism reference now reads "per-ticker jump
  tuning"). This is the one item in this response that was applied
  *after* the section-by-section pass nominally closed, so it is
  worth flagging for a follow-up grep sweep rather than trusting this
  disposition table alone.

## Build status

Clean 32-page build (`latexmk -pdf -bibtex`), verified after every
edit in this pass and again after the two follow-up fixes above.

## What we deliberately did not do

1. **Did not run a mechanical, manuscript-wide find-replace** for
   every abstract-noun pairing in the audit's table (rule 3) or every
   caption independent of the section pass (priority item 8); we
   applied both wherever the section-by-section read touched the
   relevant text, not as an exhaustive separate sweep.
2. **Did not collapse any `align` block** in the Appendix, per the
   resolved conflict; the audit's literal ask on this point was
   declined in favor of the standing show-every-step convention.
3. **Did not remove literal, non-metaphorical `gap`/`floor` usage**;
   we read the audit's rule 5 and terminology table as targeting
   metaphorical constructions specifically, not the bare words.

---

# Follow-up audit after the language revision — 2026-07-14

The revision is substantially easier to read. The remaining problems
are concentrated rather than manuscript-wide. The four items below
should still be addressed before submission because they either
overstate a result or describe the experimental design incorrectly.

## 1. The Abstract overstates HMM-WJ's marginal fit

In `jfds-paper/sections/abstract.tex`, the Abstract says that HMM-WJ
"retained the same distributional fit" as HMM-NJ. The reported KS and
AD pass rates are, however, 2--8 percentage points lower for HMM-WJ.
The current wording conflicts with the Results and Discussion.

Suggested change: replace "retained the same distributional fit" with
"retained high distributional fit" or state directly that marginal
fit decreased slightly while temporal fit improved.

## 2. The Discussion incorrectly says that all methods shared an innovation draw

In `jfds-paper/sections/discussion.tex`, the limitations paragraph
says that the study "reused the same per-ticker innovation draw across
methods." This is not the protocol described in
`jfds-paper/sections/method_sim.tex`. Only Naive and Hybrid received
the same JumpHMM innovation path. Gaussian SIM drew independent
Gaussian innovations, and the three residual-fit methods drew from
their separately fitted residual generators.

Suggested change: say that Naive and Hybrid used paired JumpHMM
innovations, while the remaining methods used innovations from their
respective generators.

## 3. The proposed residual extension would not restore cross-asset covariance

The final Discussion paragraph says that composing autoregressive or
block-bootstrap residuals with the single-index factor would restore
cross-asset residual covariance. If these models are still fitted and
sampled independently for each ticker, they restore per-asset temporal
dependence only. They do not create contemporaneous dependence between
assets.

Suggested change: specify a genuinely joint construction, such as a
synchronized multivariate block bootstrap, a multivariate residual
model, a residual factor model, or a copula-based dependence model.
An ordinary per-ticker AR or block-bootstrap model can be retained as
a proposal for temporal dependence, but not as the solution to
cross-asset covariance.

## 4. The allocator analysis makes a stronger causal claim than the experiment supports

The static-versus-daily-rebalance comparison shows that rebalancing
creates a large return increment in the synthetic paths. It does not,
by itself, prove that missing cross-asset residual covariance explains
the entire roughly 22-percentage-point difference between the
synthetic median and the realized 2025 return. The Appendix makes the
claim stronger still by saying that "only the temporal structure of
the residual draw differs." That statement conflicts with the paper's
own proposed explanation, which concerns cross-sectional residual
dependence.

Suggested change: describe the result as "consistent with a
diversification-return explanation" unless an ablation is added. A
stronger causal conclusion would require introducing realistic
cross-asset residual covariance while holding the marginals and
allocator fixed, then showing that the return gap shrinks. In the
Appendix, replace the claim that only temporal structure differs with
a precise statement about the omitted cross-asset dependence.

## Remaining language concentration

These are not separate technical malfunctions, but they remain the
main obstacles to the paper's desired simple and direct style:

- The first Discussion paragraph is still roughly 400 words and
  combines the main result, every baseline, a statistical caveat, and
  three model limitations. Split it into shorter claim--evidence--
  qualification paragraphs.
- The first Sensitivity Analyses paragraph is similarly overloaded.
  Separate the variance result, branch assignment, clipping stress
  test, and beta-bucket result.
- Both Conclusion paragraphs begin with long compound sentences.
  Split each opening into two or three direct sentences.
- In the Conclusion, replace "models fit directly to the residual
  center" with "models fit directly to the residual series" or
  "dedicated residual models." The current phrase is awkward and does
  not accurately describe what was fitted.

After these four substantive corrections and the concentrated
sentence/paragraph cleanup, the remaining language issues are polish
rather than major malfunctions.

---

# Author Response to the Follow-up Audit (2026-07-14, second pass)

Verified all four substantive items against the live manuscript and,
for item 2, against the SIM protocol in `method_sim.tex` before
editing. All four were real, not audit false positives.

1. **Abstract overstates marginal fit — DONE.** "retained the same
   distributional fit" -> "retained high distributional fit"
   (`abstract.tex`).
2. **Innovation-draw claim — DONE.** Confirmed against
   `method_sim.tex` (~lines 280-291): only Naive and Hybrid share a
   paired JumpHMM innovation path; Gaussian SIM draws its own i.i.d.\
   Gaussian innovations; the three residual-fit methods draw from
   their own fitted generators. Discussion's evaluation-choices
   sentence now scopes the shared-innovation claim to Naive/Hybrid
   and names the other methods' source.
3. **Residual-extension claim — DONE.** Reworded the closing
   Discussion paragraph: the fix for cross-asset covariance is now a
   genuinely joint construction (synchronized multivariate block
   bootstrap, residual factor model, or copula-based dependence
   model); an ordinary per-ticker AR or block-bootstrap residual
   model is now described as improving only each asset's own
   temporal dependence, not cross-asset dependence.
4. **Allocator causal overclaim — DONE, both sites the audit
   flagged, plus one it didn't.** Discussion's "attributing the
   difference to the diversification return rather than a
   calibration error" -> "consistent with a diversification-return
   explanation rather than a calibration error." Appendix's "only the
   temporal structure of the residual draw differs" replaced with a
   precise statement of what is held fixed (allocator, cost model,
   marginal calibration) versus what is omitted (cross-asset residual
   covariance), plus a sentence naming the ablation that would
   confirm the causal claim. Also propagated the same softening to
   the Conclusion, which restated the $22$pp figure with the same
   overclaim the audit didn't explicitly cite there; left as-is it
   would have re-contradicted the hedged Discussion/Appendix wording.

**Remaining language concentration:**

- First Discussion paragraph (~400 words) split into claim+evidence
  (the comparative tradeoff result) and qualification (the
  statistical caveat plus three per-asset caveats) — DONE.
- First Sensitivity Analyses paragraph split into four: the
  variance-ratio/KS-pass-rate cause-consequence result; branch
  assignment plus the clipping non-trigger and synthetic-tracker
  validation; the beta-bucket result; the clipping stress test —
  DONE.
- Both Conclusion paragraphs' long opening compound sentences split
  into two sentences each — DONE.
- "models fit directly to the residual center" -> "the residual-fit
  methods," matching the term already used in Results and Discussion
  — DONE.

**Build:** clean, 33pp (`latexmk -pdf`), 0 undefined refs, no
overfull boxes above 20pt.

---

# Author-requested follow-ups (2026-07-14, same session)

Two more requests came directly from the author, not from the
external audit text above:

1. **No fig/table refs in Discussion.** Discussion had five
   `(Table~\ref{tab:...})` parenthetical citations
   (`tab:model_comparison`, `tab:emission_hsmm`, `tab:aggregate`,
   `tab:var`, `tab:beta_bucket`). All five removed; the prose reads
   standalone without pointing back to a specific table. The
   `Online Appendix~\ref{sec:supp-*}` cross-references were left in
   place, consistent with the standing exception for appendix section
   refs.
2. **Full-manuscript pass for awkward phrasing / undefined jargon,**
   prompted by "under-breached"/"over-breached" in the VaR-coverage
   paragraph (results.tex), which the author flagged as making no
   sense. Read all nine section files plus the appendix in full.
   Fixed:
   - `results.tex`: "naive composition under-breached at 0.67% and
     Gaussian SIM over-breached at 1.40%" -> "naive composition's
     empirical exceedance rate fell short of nominal at 0.67%, while
     Gaussian SIM's exceeded it at 1.40%."
   - `results.tex`: a dangling appositive ("...below HMM-NJ's, the
     cost of jumps occasionally overweighting tail states") rewritten
     as two clean sentences with an explicit "because."
   - `method_sim.tex`: "fitted a fresh JumpHMM marginal via
     pseudo-price inversion" -> stated in plain language what the
     step does (convert the residual series into a synthetic price
     path by cumulative compounding, then fit). Verified against the
     actual implementation
     (`code/downstream-evaluation/scripts/01b-Fit-Residual-Marginals.jl`)
     before rewording, since the audit's own house rule requires
     verifying claims against code before stating them.
   - `method_hmm.tex`: "introduces a small, unquantified transient" ->
     "introduces a small, unquantified deviation from exact
     stationarity" (dynamical-systems jargon not standard in a
     finance paper).
   - `appendix.tex`: "has static-allocation drawdown geometry" ->
     "inherits the static allocation's drawdown pattern."

   Deliberately left alone: `idiosyncratic floor`, `market loading
   ratio`, and other terms that are formally defined once and used
   consistently thereafter (these are technical vocabulary, not
   unexplained jargon); `leptokurtic`, `Kupiec unconditional coverage`,
   and similar standard quant-finance/statistics terms appropriate for
   the JFDS readership.

**Build after these fixes:** clean, 32pp, 0 undefined refs, no
overfull boxes above 20pt.
