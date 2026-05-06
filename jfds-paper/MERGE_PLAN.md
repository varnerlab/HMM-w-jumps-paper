# JFDS Merge Plan

**Status:** draft for red-lining; nothing executed against `jfds-paper/sections/` until approved.
**Sources being merged:**
- `jdiq-paper/` — JDIQ-rejected paper (Alswaidan + Varner, ACM acmsmall, ~22 pp). Univariate HMM-WJ generator + multi-baseline validation framework + brief SIM extension.
- `jfds-paper/` (current state) — hybrid SIM composition paper (Varner solo, NeurIPS preprint, ~14 pp main text). Variance-corrected SIM + 6-composer benchmark + VaR backtest + sensitivity sweeps + bias-correction insert (just landed).

---

## 1. Top-level decisions (LOCKED 2026-05-06)

| Decision | Value | Rationale |
|---|---|---|
| **Authorship** | Alswaidan, Varner (Cornell CBE) — Alswaidan first, same as JDIQ | User decision. |
| **Title** | "Hybrid Hidden Markov Model for Modeling Equity Excess Growth Rate Dynamics: A Discrete-State Approach with Jump-Diffusion" — same as JDIQ | User decision. Title carries the HMM contribution; the SIM composition is implicit ("hybrid" already signals composer). |
| **Template** | NeurIPS preprint (current `jfds-paper/Paper_v1.tex`) as working template; re-template to JFDS at submission | NeurIPS preprint is closer to JFDS than ACM acmsmall and gives length flexibility while drafting. |
| **Length target** | **Hard ceiling 30 pp combined (main + SI + bib).** Main text 18–20 pp, SI 6–8 pp. | User decision. JFDS will push back at 30+. See §7 for budget. |
| **Code release** | **Single repo: `varnerlab/JumpHMM.jl`.** Paper evaluation scaffolding (6-composer harness, VaR backtest, bias-correction utility) lives in a `paper/` or `experiments/` subdirectory of JumpHMM.jl. | User decision. Flag below. |
| **Linenumbers** | Off for arXiv preprint; on for journal submission | Already controlled in `Paper_v1.tex`. |

**Code-release design flag.** Putting paper scaffolding into `JumpHMM.jl/paper/` (not into the package's `src/`) keeps the modeling library clean while giving the paper a single deliverable URL. The modeling primitives (`HybridSingleIndexModel`, `sample_dependence`, etc.) stay in `src/` as the production API; the paper-specific composers (residual-JumpHMM, block-bootstrap, GARCH-t baselines) and the VaR/Kupiec utilities go in `paper/code/` as evaluation scaffolding. Bias-correction utility (`apply_bias_correction`) is a downstream-use helper — also in `paper/code/`, not in `src/`.

---

## 2. Section-by-section blueprint

Each row lists the section, its source, and what it will contain. **Bold** = new connective tissue not in either source.

### 2.1 Abstract (rewrite from scratch)

- Two-paragraph structure:
  - **¶1**: Synthesis problem, two gaps (single-asset stylized facts; multi-asset factor structure with marginal preservation), our two-stage solution.
  - **¶2**: Validation summary (KS/AD/W1/H on univariate; six-composer benchmark + VaR backtest on multi-asset), one bias-correction sentence.
- Source: brand-new prose. **Existing `jfds-paper/sections/abstract.tex` (33 lines) gets rewritten**; current JDIQ abstract dropped.
- Length: ~250 words.

### 2.2 §1 Introduction

- Source: rewrite leaning on **JDIQ intro framing** (synthetic data quality in finance, regulator/practitioner motivation) **+ hybrid intro framing** (factor composition, marginal preservation gap).
- Structure:
  - ¶1: Practitioner motivation for synthetic equity paths (regulatory backtesting, scenario analysis, ML training).
  - ¶2: Two gaps the literature leaves open. **Connective tissue**.
  - ¶3: This paper's contributions (4 bullets in prose, no actual bullets):
    1. Hybrid HMM-WJ marginal generator (Alswaidan-Varner from JDIQ).
    2. Variance-corrected SIM composition with auditable construction flag (Varner from hybrid).
    3. Multi-baseline validation framework (KS/AD/W1/H + 6-composer + VaR + Kupiec).
    4. Documented downstream-use caveat with calibrated bias correction.
  - ¶4: Roadmap.
- Length: ~2 pp.
- **Cut**: hybrid intro's "[Alswaidan-Varner companion paper]" forward-reference (now self-reference); JDIQ intro's heavy regulator framing trimmed.

### 2.3 §2 Related Work

- Source: **JDIQ `related.tex` (15 lines)** is too short; **hybrid intro paragraphs on related composition methods** also too sparse. Need a fuller treatment for JFDS.
- Structure:
  - ¶1: HMM-based financial models (Hamilton, Rydén-Teräsvirta-Asbrink, Bulla-Bulla, prior jump-HMM literature).
  - ¶2: Synthetic financial time series and quality (GANs/VAEs in finance, GARCH-family generators, block bootstrap, Booth-Fama on rebalancing).
  - ¶3: Single-Index Model lineage (Sharpe, Fama-French, residual-fit vs full-return practitioner choices).
  - ¶4: Validation frameworks for synthetic data (KS/AD/W1/H and downstream backtests).
- Length: ~1.5 pp.
- New writing required, drawing on both bibs.

### 2.4 §3 Method

Single section with two subsections, **with a transition paragraph** between them.

#### §3.1 HMM-WJ marginal generator

- Source: **JDIQ `methods.tex` lines 1–171** (everything up through tuning algorithm; the SIM extension at the end of JDIQ methods is dropped, since SIM composition is now §3.2's job).
- Subsections:
  - 3.1.1 State space and partition (Laplace quantile)
  - 3.1.2 Transition + Student-t emissions
  - 3.1.3 Poisson jump override (ε, λ, p_neg, N_tail)
  - 3.1.4 Tuning protocol (ACF/kurtosis grid search)
- Algorithm box: HMM-WJ simulator pseudocode.
- Length: ~3 pp.
- **Trim aggressively**: this is one of two methods subsections, not the whole methods section.

#### **Transition paragraph**

- ~1 paragraph (4–6 sentences). Argues that the HMM-WJ generator gives validated single-asset marginals, but multi-asset workflows need cross-asset structure too; the variance-corrected SIM composer fills that gap while preserving the marginals from §3.1.

#### §3.2 Variance-corrected SIM composition

- Source: hybrid `method.tex` (current `jfds-paper/sections/method.tex` 323 lines).
- Subsections retained as-is:
  - 3.2.1 Composition criteria
  - 3.2.2 Variance correction `s² = 1 − ρ`
  - 3.2.3 Clipping branch with idiosyncratic floor
  - 3.2.4 R²-preserving branch for high-R² ETFs
  - 3.2.5 Algorithm box
- **Light edits**: replace "[Alswaidan-Varner 2026 companion paper]" forward references with self-references to §3.1 / §4. Tighten if length is tight.
- Length: ~3 pp.

### 2.5 §4 Empirical study (single section, two subsections)

- Source: JDIQ `results.tex` (univariate) + hybrid `results.tex` (multivariate). Combined into one section per user decision.
- **Bridge paragraph at start of §4**: 1-paragraph overview of the two-stage validation (univariate marginal fidelity → multi-asset composition fidelity → downstream VaR backtest) so the reader knows the empirical arc before diving in.
- Structure:
  - **§4.1 Single-asset validation (HMM-WJ marginals)**
    - 4.1.1 Universe and protocol (SPY 2014–2024 IS, 2025 OoS).
    - 4.1.2 Baseline comparison (Bootstrap, Gaussian, Laplace, GARCH, HMM-NJ, HMM-WJ, GRU); KS / AD / W1 / Hellinger pass rates.
    - 4.1.3 Excess kurtosis, ACF-MAE.
  - **Bridge paragraph (4–6 sentences)**: validated marginals plug into a multi-asset composer; we now ask whether composition preserves them.
  - **§4.2 Multi-asset validation (variance-corrected SIM)**
    - 4.2.1 424-asset universe; paired-innovation protocol.
    - 4.2.2 Six-composer benchmark on KS / β recovery / kurtosis / Hill.
    - 4.2.3 VaR backtest (Kupiec coverage at 95% and 99%).
    - 4.2.4 Stress test, sensitivity grid, synthetic-tracker — **summary in main text, details in SI**.
- Length: 6.0 pp combined (was 7.0 pp across two sections).
- **Cuts**:
  - JDIQ multi-asset SIM extension (lines ~140–194 of JDIQ results) — superseded.
  - JDIQ parameter-sweep results in main → SI.
  - Hybrid sensitivity grid, R²-distribution, synth-tracker validation, stress-test detail → SI.

### 2.6 §5 Discussion

- Source: hybrid `discussion.tex` (current 239 lines, includes the bias-correction insert).
- **Edits required**:
  - Remove "[Alswaidan-Varner companion paper]" deferrals (`alswaidanVarner2026jdiq` citations); the cross-sectional / portfolio-VaR points become self-references to §5 or are absorbed into the relevant paragraph.
  - Add 1 paragraph on the HMM-WJ generator's residual-autocorrelation profile (since the merged paper now owns both the generator and the composer, the diversification-return discussion can connect to the generator's iid-ness more directly).
- Length: ~2 pp.

### 2.7 §6 Conclusion

- Source: rewrite. JDIQ conclusion is 1 line; hybrid has none.
- Structure:
  - ¶1: Recap two-stage contribution.
  - ¶2: Validation summary (univariate + multivariate + downstream).
  - ¶3: Future work (AR(1)/GARCH residuals + restructured copula sampling; multi-factor SIM; per-ticker jump tuning at scale; cross-asset class extension).
- Length: ~0.5 pp.

### 2.8 Endmatter

- Author contributions, code/data availability, acknowledgments, competing interests.
- **Author contributions** (proposed split, edit as needed):
  - **A.A.**: HMM-WJ marginal generator design, single-asset experiments (§4), JDIQ-side validation framework.
  - **J.D.V.**: SIM composition design, multi-asset experiments (§5), bias-correction methodology, code release.
  - **Both**: writing.
- Code release: `varnerlab/JumpHMM.jl` + `varnerlab/jfds-paper-code` (or merged into one paper repo).

### 2.9 Online Appendix (SI)

- Tightened to fit the 30 pp ceiling (was 10–14 pp; now **target 6–8 pp**).
- Mapping (consolidated where possible):
  - **S1 Empirical cross-term diagnostic** — hybrid (already in `appendix.tex`).
  - **S2 Bias correction methodology** — already drafted (outline form).
  - **S3 Validation metric definitions (KS, AD, W1, Hellinger)** — JDIQ S11. Compact (~0.5 pp).
  - **S4 HMM-WJ algorithm pseudocode + parameter sweep details** — combine JDIQ S3 + S4 + parameter-sweep figure into one appendix.
  - **S5 Multi-asset diagnostics** — combine sensitivity grid + R² distribution + synth-tracker + seed uncertainty into one consolidated appendix with figures (was 4 separate sections).
  - **S6 Stress-test details** — clipping branch validation under elevated σ_m.
  - **S7 Reproducibility / code manifest** — combined release notes for `JumpHMM.jl/paper/`.
- Length: 6–8 pp combined.

---

## 3. Figures and tables — main vs SI (TIGHTENED)

Per user decision: only critical figures/tables in main text; everything else to SI.

**Main text figures (4):**

| # | Source | What | Why critical |
|---|---|---|---|
| F1 | JDIQ Fig 4 | Single-asset baseline comparison (six baselines + GRU on KS / AD / W1 / H) | Establishes HMM-WJ as best univariate generator. |
| F2 | hybrid Fig 1 | Multi-asset preservation: KS pass rate + variance ratio vs β | Hero result for the variance-corrected SIM. |
| F3 | hybrid Fig 4 | Six-composer benchmark panel (KS pass + Hill tail) | Head-to-head against alternative composers. |
| F4 | hybrid Fig 8 | VaR backtest + Kupiec coverage | Downstream-use validation. |

**Main text tables (3):**

| # | Source | What |
|---|---|---|
| T1 | Combine JDIQ Tables 2 + 3 | Univariate IS/OoS validation summary, single compact table |
| T2 | hybrid Table 1 | Six-composer multi-asset aggregate scorecard |
| T3 | hybrid Table 5 | VaR backtest with Kupiec |

**Everything else → SI:**

- JDIQ Fig 1 (empirical motivation; intro can describe verbally without the figure), Fig 3 (model internals), Fig 5 (parameter sweep), Fig 6 (statistical validation), Fig-Copula-Comparison, Fig-Price-Trajectories, Fig 7/7S (superseded).
- hybrid Fig 2 (tails), Fig 3 (branch map), Fig 5 (sensitivity), Fig 6 (stress), Fig 7 (R² distribution), Fig 9 (synth-tracker), and the SI cross-term diagnostic figure already there.
- hybrid Tables 2 (per-branch breakdown), 3 (per-β quartile), 4 (seed-uncertainty).
- Bias-correction decomposition table (Table S2.1 from §S2 outline).

---

## 4. Bibliography merge

- JDIQ `References_v1.bib` (~48 entries) + hybrid `References_v1.bib` (~30 entries).
- Strategy: union and dedupe by DOI/title. Estimate ~60–65 unique entries.
- Renaming: JDIQ uses `acmnumeric` BibTeX keys (e.g., `rabiner_introduction_1986`); hybrid uses camelCase (e.g., `boothFama1992`). Merged paper inherits hybrid's style; rename JDIQ keys at merge time.
- New entries already added for bias-correction (markowitz1976longRun, damodaranERP, ibbotsonSBBI, loMacKinlay1990).

---

## 5. Connective-tissue plan

Three transitions need explicit prose to keep the merged paper from reading like two stapled drafts:

1. **Intro → Method**: A roadmap paragraph at the end of §1 saying "§3 builds the marginal generator; §3.2 composes it into a multi-asset structure; §4 and §5 validate each in turn; §6 documents one downstream-use caveat."
2. **§3.1 → §3.2**: A short bridge paragraph (drafted above) tying the validated marginals to the composer.
3. **§4 → §5**: A bridge paragraph framing §5 as "having validated single-asset marginals in §4, we now ask whether those marginals plug into a multi-asset SIM composer while preserving fidelity."

---

## 6. What gets cut

From JDIQ:
- Methods §172+ (SIM extension; superseded by hybrid §3.2).
- Results §140–194 (multi-asset SIM at 424 assets via residual bootstrap; superseded by hybrid §5 with the variance-corrected composer).
- Conclusion (rewritten).
- ACM acmsmall–specific frontmatter (CCS concepts, ACM Reference Format).

From hybrid:
- Forward references to "[Alswaidan-Varner companion paper]" — become self-references or are absorbed.
- Solo-author framing in intro/abstract.
- Possibly the synthetic-tracker validation if length is tight (move to SI).

---

## 7. Length budget audit (TIGHTENED for ≤30 pp ceiling)

| Section | Estimated pp |
|---|---|
| Abstract + keywords | 0.3 |
| §1 Introduction | 1.5 |
| §2 Related Work | 1.5 |
| §3 Method (3.1 HMM-WJ + bridge + 3.2 SIM composer) | 5.5 |
| §4 Empirical (4.1 + bridge + 4.2) | 6.0 |
| §5 Discussion | 2.0 |
| §6 Conclusion | 0.5 |
| Endmatter | 0.5 |
| Floats (4 figs + 3 tables) | ~3.0 |
| **Main text total** | **20.8** |
| References | 1.5 |
| SI | 6–8 |
| **Total** | **28–30** |

Sits right at the ceiling. **Risk levers** if a draft pass overshoots:
1. Trim §3.1 HMM-WJ method (port a more compact version from JDIQ; relegate algorithm box to SI).
2. Move T1 (univariate IS/OoS table) to SI; keep summary statistics in §4.1 prose only.
3. Drop F1 (single-asset baseline figure); rely on T1 + prose.
4. Tighten Discussion; the bias-correction prose is the longest part and could compress.

JFDS will push back at 30+ pp; we're aiming for ≤29 pp with a 1-pp safety margin. If on first draft we land at 32 pp, lever 1 + lever 3 closes the gap.

---

## 8. Execution sequence (after approval)

Aligned with the new combined-empirical-section structure. Each step verifiable by a successful `make pdf`.

1. **Bib merge** — produce unified `References_v1.bib`; rename JDIQ keys to camelCase; verify all citations resolve.
2. **Frontmatter** — update `Paper_v1.tex` title (JDIQ title), author block (Alswaidan first, Varner second), abstract input.
3. **§1 Introduction rewrite** — new prose; replace `sections/introduction.tex`.
4. **§2 Related Work** — new file `sections/related.tex`; add `\input` in `Paper_v1.tex`.
5. **§3.1 HMM-WJ method** — port from JDIQ `methods.tex` into `sections/method_hmm.tex`; trim aggressively.
6. **§3.1 → §3.2 bridge paragraph** — append to `sections/method_hmm.tex`.
7. **§3.2 SIM composer** — current `sections/method.tex` → rename `sections/method_sim.tex`; remove companion-paper forward-references.
8. **§4 opening + §4.1 single-asset** — port from JDIQ `results.tex` into a new combined `sections/results.tex`; trim JDIQ multi-asset SIM section.
9. **§4.1 → §4.2 bridge paragraph** — inside `sections/results.tex`.
10. **§4.2 multi-asset** — port from current hybrid `results.tex` into the same `sections/results.tex`; trim sensitivity/synth-tracker/R²-dist details to brief mentions with SI pointers.
11. **§5 Discussion** — current `sections/discussion.tex`; remove companion-paper deferrals; add residual-autocorrelation paragraph.
12. **§6 Conclusion** — new file.
13. **Endmatter** — author contributions, code/data availability pointing at `JumpHMM.jl`, acknowledgments.
14. **SI consolidation** — port JDIQ supplemental into `sections/appendix.tex` under the consolidated S3–S7 headers from §2.9.
15. **Figure/table inputs** — copy JDIQ figs into `jfds-paper/figs/`, rename `jdiq_*.pdf`; move all non-main-text figs/tables to SI; update `\includegraphics` paths and `\label{fig:...}` keys.
16. **Final lint pass** — em-dash check, citation check, undefined-ref check, page-budget check (must land ≤30 pp).

Each step a small commit. A failed step is reverted before moving on.

---

## 9. Open questions for you

1. ~~Title~~ — **resolved: same as JDIQ.**
2. ~~Author order~~ — **resolved: Alswaidan, Varner.**
3. ~~Code release~~ — **resolved: single repo `JumpHMM.jl`** with paper scaffolding in `paper/` subdir.
4. **Generic-allocator re-run for SI S2** — **still open.** Decision point: do we (a) re-run the rebalancing-decomposition on a generic allocator (e.g., minimum-variance or inverse-volatility) using the released `JumpHMM.jl/paper/code/` pipeline so the numbers are reproducible from the artifact, or (b) cite the eCornell deployment as the empirical setting? Option (a) takes ~2–4 hours of Julia work. Option (b) is faster but means SI S2 references an external course deployment as the source of the numbers.
5. ~~Length tolerance~~ — **resolved: ≤30 pp hard ceiling.**

---

## 10. Risks

| Risk | Mitigation |
|---|---|
| Two-papers-stapled feel | Three explicit bridge paragraphs (§5); unified abstract + intro; one conclusion |
| Page budget | Aggressive figure/table triage to SI; trim §3.1 hard; cut JDIQ multi-asset SIM |
| Citation key collisions | Audit during bib merge; rename JDIQ keys to hybrid's camelCase convention |
| Forward-reference debris | Grep for `companion paper`, `alswaidanVarner2026jdiq`, `[REF]` after each step |
| Figure path / numbering chaos | Rename JDIQ figs `jdiq_*.pdf`; renumber globally only at the end |

---

**Plan locked except for §9 item 4 (SI S2 generic-allocator re-run vs eCornell reference).** Awaiting either your decision on that or your go-ahead to start §8 step 1 with item 4 left as a follow-up.
