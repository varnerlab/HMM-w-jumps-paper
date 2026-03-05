# JDIQ Submission Plan — Quality of Synthetic Financial Time Series

**Target:** ACM Journal of Data and Information Quality (JDIQ)
**Special Issue:** "Quality of Synthetic Data" (guest editors: Maurino, Panse, Missier)
**Status:** Deadline was March 1, 2026 — contact editors re: late acceptance

---

## Completed

- [x] **Numerical reconciliation** — All pass rates consistent across abstract, intro, discussion, conclusion (using Table 2 SE-run values)
- [x] **Standard errors** — Tables 2 and 3 now report binomial SEs for pass rates, std/sqrt(n) for kurtosis, bootstrap SE (B=500) for ACF-MAE
- [x] **Table 3 expanded** — N ∈ {30, 60, 90, 100, 150, 200} with full KS/AD/ACF-MAE + SEs
- [x] **State occupancy diagnostics** — Confirmed all N ≤ 200 are statistically healthy (min 7 obs/state)
- [x] **OoS window updated** — 220 days → 249 days (full calendar year 2025) everywhere
- [x] **New bib entries** — CTGAN, TimeGAN, TableGAN, JDIQ TS synthesis survey, differential privacy, synthetic data survey refs added
- [x] **GARCH benchmark** — Table 2 + Figure 4 fully populated with GARCH(1,1) comparison

---

## Phase 1: Reframing (text changes, no new computation)

### 1.1 Abstract rewrite
- [ ] Lead with synthetic data quality problem, not EMH
- [ ] Position KS/AD/ACF-MAE as "quality metrics for synthetic time series"
- [ ] Mention JDIQ-relevant framing: fidelity, temporal structure preservation, scalability

### 1.2 Introduction reframe
- [ ] Paragraph 1: open with synthetic data generation challenge in finance (stress testing, risk model validation, privacy-preserving data sharing)
- [ ] Keep finance context but as the *domain*, not the *contribution*
- [ ] Reframe 4 contributions as data quality contributions:
  1. Jump-duration mechanism → "structural inductive bias that preserves temporal quality (volatility clustering)"
  2. Non-iterative estimation → "scalable pipeline for high-fidelity synthetic data across 424 assets"
  3. Validation → "rigorous quality assessment using distributional (KS, AD) and temporal (ACF-MAE) metrics with standard errors"
  4. SIM extension → "multi-asset synthetic data generation preserving cross-sectional correlation structure"

### 1.3 Related work expansion
- [ ] Add new subsection: "Synthetic data quality assessment" (~1 page)
  - JDIQ TS synthesis survey (Bauer et al 2024)
  - CTGAN, TimeGAN, TableGAN — tabular/time-series generation
  - Differential privacy approaches
  - Contrast: GAN-based methods lack explicit quality guarantees; our framework has built-in quality metrics
- [ ] Reframe existing "Synthetic data generation" subsection to connect to JDIQ literature

### 1.4 Discussion reframe
- [ ] Add subsection: "Practical guidance for synthetic data practitioners"
  - When to use N=100 vs lower/higher
  - When SIM extension is sufficient vs multivariate HMM needed
  - Quality thresholds: what KS/AD pass rate is "good enough"?
- [ ] Reframe limitations around data quality degradation conditions

### 1.5 Conclusion reframe
- [ ] Restate contributions in data quality language
- [ ] Add paragraph: implications for synthetic data community (JDIQ audience)

---

## Phase 2: Template switch (formatting, no content changes)

### 2.1 elsarticle → ACM acmsmall
- [ ] Install ACM LaTeX template (acmart class, acmsmall format)
- [ ] Convert frontmatter (title, authors, abstract, keywords → ACM CCS concepts)
- [ ] Convert bibliography style to ACM format (biblatex or natbib with ACM style)
- [ ] Add ACM copyright/DOI placeholder boilerplate
- [ ] Convert `\section*{}` → `\section{}` (ACM requires numbered sections)
- [ ] Move figures/tables inline (ACM doesn't use end-of-document floats)
- [ ] Verify page count ≤ 23 (excl. references)

### 2.2 Double-anonymous preparation
- [ ] Remove author names and affiliations from submitted PDF
- [ ] Remove GitHub URL from data availability statement (or anonymize)
- [ ] Check for self-citations that reveal identity
- [ ] Ensure no "our previous work" or similar revealing language

---

## Phase 3: Strengthening (new computation)

### 3.1 Baseline comparison
- [ ] Add naive bootstrap baseline: resample g_is with replacement, compute KS/AD/ACF-MAE
- [ ] Add parametric Gaussian baseline: simulate from N(μ, σ²) fitted to g_is
- [ ] Add parametric Laplace baseline: simulate from Laplace(μ, b) fitted to g_is
- [ ] These baselines show that the quality improvement is non-trivial
- [ ] Add results to Table 2 (or new Table 2b)

### 3.2 Quality metric completeness
- [ ] Consider adding: Wasserstein distance, maximum mean discrepancy (MMD)
- [ ] Consider adding: coverage metric (what fraction of observed quantiles are within simulated envelope?)
- [ ] These are standard in the synthetic data quality literature (cited in JDIQ survey)

### 3.3 Reproducibility artifact
- [ ] Create a self-contained reproducibility package
- [ ] Include: data, scripts, environment files, README with instructions
- [ ] JDIQ values reproducibility highly — this strengthens the submission

---

## Phase 4: Pre-submission checklist

- [ ] Contact special issue editors (Maurino, Panse, Missier) re: late submission
- [ ] If SI closed, submit as regular JDIQ research paper
- [ ] Verify all `\ref{}` targets resolve
- [ ] Verify all figures present in `paper/sections/figs/`
- [ ] Run `Build.sh` and check for LaTeX errors
- [ ] Proofread for grammar/typos
- [ ] Verify page count ≤ 23
- [ ] Prepare cover letter highlighting fit with JDIQ scope

---

## File Inventory

| File | Status | Notes |
|------|--------|-------|
| `paper/Paper_v1.tex` | Needs template switch | Currently elsarticle |
| `paper/sections/introduction.tex` | Needs reframe | Phase 1.2 |
| `paper/sections/related.tex` | Needs expansion | Phase 1.3 — add synthetic data quality subsection |
| `paper/sections/methods.tex` | Minor updates | OoS days fixed; mostly fine for JDIQ |
| `paper/sections/results.tex` | OK | Content is good; framing is already empirical |
| `paper/sections/discussion.tex` | Needs reframe | Phase 1.4 |
| `paper/sections/conclusion.tex` | Needs reframe | Phase 1.5 |
| `paper/sections/tables.tex` | Done | Tables 1-4 complete with SEs |
| `paper/sections/figures.tex` | OK | 7 figures all present |
| `paper/References_v1.bib` | Done | ~45 entries including synthetic data refs |
| `code/spy-experiment/Table2-SEs.jl` | Done | Computes Table 2 with SEs |
| `code/spy-experiment/Table3-Sensitivity-ACF-MAE.jl` | Done | Computes Table 3 with SEs |
| `code/spy-experiment/Table3-Diagnostics.jl` | Done | State occupancy health check |

---

## Key Differences: Finance Journal vs JDIQ

| Dimension | Finance Journal (JFE) | JDIQ |
|---|---|---|
| Opening hook | EMH vs empirical complexity | Synthetic data quality challenge |
| Contribution framing | "Better financial model" | "High-fidelity synthetic data with quality guarantees" |
| Validation language | "Pass rates" | "Quality metrics" / "fidelity assessment" |
| Related work emphasis | GARCH, stochastic vol, HMMs | + GANs, synthetic data surveys, quality frameworks |
| Key selling point | ARCH effect reproduction | Domain-specific quality evaluation methodology |
| Audience assumption | Knows CAPM, Black-Scholes | Knows data quality dimensions, synthetic data |
| Template | elsarticle | ACM acmsmall |
| Review | Single-blind | Double-anonymous |
