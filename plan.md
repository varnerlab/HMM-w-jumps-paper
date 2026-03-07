# JDIQ Submission Plan -- Quality of Synthetic Financial Time Series

**Target:** ACM Journal of Data and Information Quality (JDIQ)
**Special Issue:** "Quality of Synthetic Data" (guest editors: Maurino, Panse, Missier)
**Status:** Deadline extended to **April 7, 2026**

---

## Completed

- [x] **Numerical reconciliation** -- All pass rates consistent across abstract, intro, discussion, conclusion (using Table 2 SE-run values)
- [x] **Standard errors** -- Tables 2 and 3 now report binomial SEs for pass rates, std/sqrt(n) for kurtosis, bootstrap SE (B=500) for ACF-MAE
- [x] **Table 3 expanded** -- N in {30, 60, 90, 100, 150, 200} with full KS/AD/ACF-MAE + SEs
- [x] **State occupancy diagnostics** -- Confirmed all N <= 200 are statistically healthy (min 7 obs/state)
- [x] **OoS window updated** -- 220 days to 249 days (full calendar year 2025) everywhere
- [x] **New bib entries** -- CTGAN, TimeGAN, TableGAN, JDIQ TS synthesis survey, differential privacy, synthetic data survey refs added
- [x] **GARCH benchmark** -- Table 2 + Figure 4 fully populated with GARCH(1,1) comparison
- [x] **Abstract rewrite** -- Leads with synthetic data quality problem; KS/AD/ACF-MAE positioned as quality metrics; JDIQ framing throughout
- [x] **Introduction reframe** -- Opens with synthetic data generation challenge; 4 contributions reframed as data quality contributions
- [x] **Conclusion reframe** -- Contributions restated in data quality language; broader implications paragraph for synthetic data community added
- [x] **Results rewrite** -- Every sentence follows "we did X, we saw Y, which suggests Z (Fig/Table ref)" format
- [x] **Keywords updated** -- Synthetic Data Quality, Time Series Generation, HMM, Jump-Diffusion, Volatility Clustering, Regime-Switching, Stylized Facts, Distributional Fidelity
- [x] **Em dashes eliminated** -- All `---` and unicode em dashes removed from every section; replaced with commas, parentheses, or semicolons
- [x] **Methods grid search corrected** -- epsilon/lambda ranges and paths-per-point now match actual code (HMM-Parameter-Sweep.jl)
- [x] **Template switch: elsarticle to ACM acmsmall** -- `\documentclass[acmsmall,nonacm]{acmart}` with `acmart.cls`, `ACM-Reference-Format.bst`, and all supporting files installed in `paper/`
- [x] **ACM frontmatter conversion** -- `\affiliation{}`, `\keywords{}`, `\maketitle` after `\begin{document}`; removed elsarticle `\begin{frontmatter}`, `\sep`, `\biboptions`
- [x] **Numbered sections** -- All `\section*{}` converted to `\section{}` per ACM style
- [x] **Bibliography style** -- Switched from `model1-num-names` to `ACM-Reference-Format`
- [x] **Redundant packages removed** -- `amssymb`, `amsmath`, `amsfonts`, `lineno`, `hyperref`, `url` removed (provided by acmart); manual `\newtheorem` defs removed (acmart provides its own)
- [x] **Figures/tables moved inline** -- All 7 figures, 4 tables, and 4 algorithms moved from end-of-document to their first-reference locations in `introduction.tex`, `methods.tex`, and `results.tex`; old `figures.tex`, `tables.tex`, `notation.tex` replaced with stubs
- [x] **Algorithm text reduced** -- All 4 algorithm environments now use `\small` font
- [x] **Results narrative improved** -- Merged choppy single-finding paragraphs into 5 thematic subsections with varied sentence structure
- [x] **Discussion restructured** -- Absorbed "Broader implications" and "Limitations" from old conclusion; added subsections for jump mechanism interpretation, practical implications, and limitations
- [x] **Conclusion trimmed** -- Reduced from ~1.5 pages with subsections to 2 concise paragraphs (summary + future work)
- [x] **Introduction consolidated** -- Reduced from 5 paragraphs to 3: big picture, existing approaches, what we do
- [x] **Introduction cleaned** -- Removed undefined math symbols ($\epsilon$, $\lambda$, $N=100$); spelled out abbreviations (CDF, EM, ACF, KS, AD) on first use
- [x] **Related work restructured** -- Reduced from 15 paragraphs / 6 subsections to 7 paragraphs / 4 subsections with clear narrative arc: stylized facts + parametric models, HMMs + regime-switching, synthetic data + deep generative models, factor models + multi-asset
- [x] **Online Appendix created** -- Moved Algorithms 1, 3, 4, Table 3 (sensitivity), Fig 3 (model internals), Fig 5 (grid search) to `sections/supplemental.tex`; main text has inline references to Online Appendix S1--S4
- [x] **Main body streamlined** -- Only Algorithm 2 (core jump-diffusion simulation) remains in methods; prose summaries replace moved figures
- [x] **Table font sizes normalized** -- Replaced `\resizebox{\textwidth}{!}{}` with `\small` in Tables 1, 2, 4 for consistent text proportions
- [x] **Float placement** -- All main-body floats use `[tp]` (top or page); supplemental uses `[tp]` with `\clearpage` between sections

---

## Phase 1: Remaining text changes (no new computation)

### 1.1 Discussion practitioner guidance
- [ ] Add subsection: "Practical guidance for synthetic data practitioners"
  - When to use N=100 vs lower/higher
  - When SIM extension is sufficient vs multivariate HMM needed
  - Quality thresholds: what KS/AD pass rate is "good enough"?

### 1.2 Float layout polish
- [ ] Resolve two-floats-on-same-page issue (Table 3 + Fig 5 in Online Appendix cohabiting page 15)
- [ ] Rule: no page should have two floats (float + text is fine)

---

## Phase 2: Double-anonymous preparation

- [ ] Remove author names and affiliations from submitted PDF (switch `nonacm` to `anonymous`)
- [ ] Remove GitHub URL from data availability statement (or anonymize)
- [ ] Check for self-citations that reveal identity
- [ ] Ensure no "our previous work" or similar revealing language

---

## Phase 3: Strengthening (new computation)

### 3.1 Baseline comparison
- [x] Code implemented in `code/baseline-comparison/` (self-contained with own Include.jl, Project.toml)
- [ ] Run `Baseline-Comparison.jl` to generate numbers
- [ ] Add 3 baseline columns to Table 2: Bootstrap, Gaussian, Laplace
- [ ] Add 3 new metric rows to Table 2: Novelty, Diversity, Coverage (%)
- [ ] Add 1-2 sentences in Results interpreting the baselines

**Baselines:**
- Bootstrap: resample g_is with replacement (same marginal, no temporal structure)
- Gaussian: i.i.d. N(μ, σ²) fitted to g_is (wrong tails, no temporal structure)
- Laplace: i.i.d. Laplace(μ, b) fitted to g_is (better tails, no temporal structure)

**New metrics (all with SEs):**
- Novelty: mean(1 - |cor(sim_path, obs_path)|); confirms non-memorization
- Diversity: mean pairwise correlation distance among synthetic paths; confirms no mode collapse
- Coverage: fraction of 99 empirical quantiles within [5th, 95th] synthetic envelope

### 3.2 Quality metric completeness
- [ ] Consider adding: Wasserstein distance, maximum mean discrepancy (MMD)
- [ ] Consider adding: coverage metric (what fraction of observed quantiles are within simulated envelope?)
- [ ] These are standard in the synthetic data quality literature (cited in JDIQ survey)

### 3.3 Reproducibility artifact
- [ ] Create a self-contained reproducibility package
- [ ] Include: data, scripts, environment files, README with instructions
- [ ] JDIQ values reproducibility highly; this strengthens the submission

---

## Phase 4: Pre-submission checklist

- [ ] Verify all `\ref{}` targets resolve
- [ ] Verify all figures present in `paper/sections/figs/`
- [ ] Run `Build.sh` and check for LaTeX errors
- [ ] Proofread for grammar/typos
- [ ] Verify page count <= 23 (main body) + Online Appendix
- [ ] Prepare cover letter highlighting fit with JDIQ scope

---

## File Inventory

| File | Status | Notes |
|------|--------|-------|
| `paper/Paper_v1.tex` | Done | ACM acmsmall template; compiles cleanly (28 pages incl. appendix) |
| `paper/acmart.cls` | Installed | ACM document class from CTAN |
| `paper/ACM-Reference-Format.bst` | Installed | ACM bibliography style |
| `paper/sections/introduction.tex` | Done | 3 paragraphs + Fig 1 inline |
| `paper/sections/related.tex` | Done | 4 subsections with clear narrative arc |
| `paper/sections/methods.tex` | Done | Fig 2 + Algorithm 2 inline; Algorithms 1,3,4 and Fig 3 moved to supplement |
| `paper/sections/results.tex` | Done | Tables 1,2,4 + Figs 4,6,7 inline; Table 3 and Fig 5 moved to supplement |
| `paper/sections/discussion.tex` | Done | 3 subsections: jump mechanism, practical implications, limitations |
| `paper/sections/conclusion.tex` | Done | 2 paragraphs: summary + future work |
| `paper/sections/endmatter.tex` | Done | Conflict, contributions, data availability |
| `paper/sections/supplemental.tex` | Done | Online Appendix S1--S4: Fig 3, Fig 5, Table 3, Algorithms 1/3/4 |
| `paper/sections/figures.tex` | Stub | Content moved inline |
| `paper/sections/tables.tex` | Stub | Content moved inline |
| `paper/sections/notation.tex` | Stub | Algorithms moved to methods.tex |
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
| Template | ~~elsarticle~~ acmsmall | ACM acmsmall |
| Review | Single-blind | Double-anonymous |
