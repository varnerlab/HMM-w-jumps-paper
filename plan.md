# JDIQ Submission Plan -- Quality of Synthetic Financial Time Series

**Target:** ACM Journal of Data and Information Quality (JDIQ)
**Special Issue:** "Quality of Synthetic Data" (guest editors: Maurino, Panse, Missier)
**Status:** Deadline extended to **April 7, 2026** (~1 month remaining)

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
- [x] **Template switch: elsarticle to ACM acmsmall** -- `\documentclass[acmsmall,nonacm,screen]{acmart}` with `acmart.cls`, `ACM-Reference-Format.bst`, and all supporting files installed in `paper/`
- [x] **ACM frontmatter conversion** -- `\affiliation{}`, `\keywords{}`, `\maketitle` after `\begin{document}`; removed elsarticle `\begin{frontmatter}`, `\sep`, `\biboptions`
- [x] **Numbered sections** -- All `\section*{}` converted to `\section{}` per ACM style
- [x] **Bibliography style** -- Switched from `model1-num-names` to `ACM-Reference-Format`
- [x] **Redundant packages removed** -- `amssymb`, `amsmath`, `amsfonts`, `lineno`, `hyperref`, `url` removed (provided by acmart); manual `\newtheorem` defs removed (acmart provides its own)
- [x] **Figures/tables moved inline** -- All 7 figures, 4 tables, and 4 algorithms moved from end-of-document to their first-reference locations
- [x] **Algorithm text reduced** -- All 4 algorithm environments now use `\small` font
- [x] **Results narrative improved** -- Merged choppy single-finding paragraphs into 5 thematic subsections with varied sentence structure
- [x] **Discussion restructured** -- Absorbed "Broader implications" and "Limitations" from old conclusion; added subsections for jump mechanism interpretation, practical implications, and limitations
- [x] **Conclusion trimmed** -- Reduced from ~1.5 pages with subsections to 2 concise paragraphs (summary + future work)
- [x] **Introduction consolidated** -- Reduced from 5 paragraphs to 3: big picture, existing approaches, what we do
- [x] **Introduction cleaned** -- Removed undefined math symbols; spelled out abbreviations on first use
- [x] **Related work restructured** -- 4 subsections with clear narrative arc
- [x] **Online Appendix created** -- Moved Algorithms 1, 3, 4, Table 3, Fig 3, Fig 5 to `sections/supplemental.tex`
- [x] **Main body streamlined** -- Only Algorithm 2 (core simulation) remains in methods
- [x] **Float placement** -- All main-body floats use `[tp]`; supplemental uses `[tp]` with `\clearpage`
- [x] **Baseline comparison (Phase 3.1)** -- Code in `code/baseline-comparison/`, run complete, Table 2 updated with 6 models x 8 metrics (KS, AD, kurtosis, ACF-MAE, novelty, diversity, coverage) all with SEs. Bootstrap, Gaussian, Laplace baselines added.
- [x] **Blue hyperlinks** -- `screen` class option + `\AtEndPreamble` override for blue link/cite/url colors
- [x] **Fit-and-finish pass** -- All results/methods/discussion/conclusion converted to past tense; incomplete equation introductions fixed; short paragraphs merged; awkward phrasing cleaned up
- [x] **README.md** -- Public repo README with structure, scripts, installation, reproduction instructions, CHEME 5660 attribution
- [x] **Paper .gitignore** -- Excludes LaTeX auxiliary files
- [x] **Code fix: jump loop non-terminating** -- `K==0` case now advances `t` in both `HMM-Parameter-Sweep.jl` and `Multi-Ticker-Evaluation.jl`
- [x] **Code fix: Table4 empty-filter crash** -- `summary_stats` now has `isempty` guard returning `NaN` placeholders
- [x] **Wasserstein-1 + Hellinger added** -- Methods equations (Eq. wasserstein, Eq. hellinger), results paragraph + Table 2 rows (IS+OoS), discussion analysis of GARCH OoS collapse
- [x] **N4 KS/AD i.i.d. caveat** -- In methods pass-rate paragraph and Limitations subsection; W1/Hellinger cited as assumption-free corroboration
- [x] **Citation audit** -- All \cite{} verified against published sources; 9 bib entries corrected (wrong authors: harwood, bauer/joussen/lukas, jordon; wrong years: assefa, manganelli, berghaus; wrong metadata: hernandez, stadler, dwork); 2 irrelevant citations removed from discussion (ohara, manganelli); nguyen claim corrected
- [x] **Table 2 best-model boxes** -- \fbox{} around best parametric model value in each metric row (Bootstrap excluded from competition)
- [x] **Parameter count footnote** -- Table 2 footnote clarifying that the N x N transition matrix is a sufficient statistic computed by counting, not a fitted parameter

---

## Hard Reviewer Assessment (2026-03-07)

### arXiv: Ready to submit

The paper is technically sound, well-structured, and self-contained. Two minor polish items:

- [x] **Consistent spelling** -- American spelling applied globally.
- [x] **KS/AD i.i.d. caveat** -- Added in methods (pass rate paragraph) and discussion (end of Limitations subsection); Wasserstein-1 and Hellinger cited as assumption-free corroborating metrics.

### JDIQ: Likely "Major Revision" Items

These are issues a hard JDIQ reviewer would likely require before acceptance, ordered by impact:

#### NEED (likely required for acceptance)

- [x] **N1. No semi-Markov comparison.** RESOLVED. Implemented HSMM baseline with K=8 Laplace quantile states, NegBin dwell times, Student-t(5) emissions. Swept K in {3,4,5,6,8}. Result: 82.0% IS KS (vs 97.6% HMM-WJ), ACF-MAE 0.059 (i.i.d. floor). Semi-Markov dwell times provide zero volatility clustering improvement because empirical dwell times are only 1.1-1.8 steps. Added to Table 2 as 7th model with full discussion. Code in `code/baseline-comparison/Semi-Markov-Baseline.jl`.

- [x] **N2. No neural baseline.** RESOLVED. Implemented 2-layer GRU autoregressive baseline (37,954 trainable parameters, Gaussian output head, window=50). Result: IS KS 0.6% (catastrophic distributional failure), ACF-MAE 0.036 (second-best, behind only GARCH). Variance collapse: simulated std 30% below observed. Added to Table 2 as 8th model. Code in `code/baseline-comparison/neural-baseline/` (Python + Julia evaluation).

- [x] **N3. Single-asset primary evaluation.** RESOLVED. Added standalone HMM-NJ/HMM-WJ evaluation for NVDA (high-beta tech), JNJ (low-beta health care), and JPM (moderate-beta financials). All three achieve IS KS >91%. Results in Online Appendix S5 (Table S5) with forward reference in main text section 4.4. Code in `code/other-ticker-experiment/`.

- [x] **N4. KS/AD test validity under temporal dependence.** Added caveat in methods and Limitations; Wasserstein-1 and Hellinger distances added as assumption-free alternatives that produce consistent model ordering.

- [x] **N5. ACF-MAE improvement framing.** RESOLVED. Added text in results (temporal fidelity paragraph) and discussion explaining that epsilon is continuously tunable: increasing it produces more jump-containing paths and lower ACF-MAE, at the cost of distributional fidelity. The grid search selected epsilon=0.0001 as the jointly optimal operating point for SPY; the 24% jump rate reflects the best achievable balance, not a structural ceiling.

- [x] **N6. Kurtosis underestimation is unexplored.** RESOLVED. Switched emission distribution from Normal to Student-t(df=5). IS kurtosis gap closed from 29% (Normal) to 2% (Student-t). Sensitivity analysis over df in {3,...,30,Inf} confirmed df=5 optimal. All paper sections updated (methods, Table 2, results prose, abstract, intro, conclusion, discussion, TikZ diagram, supplemental algorithms). Code in `code/spy-experiment/N6-Kurtosis-Exploration.jl`, `N6-df-Sensitivity.jl`, `Table2-StudentT-Emissions.jl`.

#### NICE (would strengthen, probably not block acceptance)

- [ ] **C1. Single OoS window.** 249 days of 2025 is one draw. A rolling-window evaluation (train on 2014-2019, test 2020; train 2014-2020, test 2021; etc.) would be more convincing. Paper already acknowledges this limitation.

- [ ] **C2. No ablation on N_tail.** Tail set size is "user-configurable" but sensitivity is never studied. Only N, epsilon, lambda are varied in Table 3.

- [ ] **C3. SIM extension results are weak.** 58.4% mean KS pass rate across 424 assets. The paper honestly attributes this to single-factor limitations, but a reviewer might question whether this warrants a full section if the conclusion is "SIM isn't expressive enough."

- [x] **C4. Missing copula discussion in related work.** Added to factor models subsection; cites Embrechts et al. (2002) and Cherubini et al. (2004).

- [x] **C5. Privacy angle.** Added paragraph in discussion (practical implications); novelty/diversity as memorization guard; cites Dwork (2006) and Stadler et al. (2022); honestly notes no formal DP guarantees.

- [x] **C6. Continuous distance metrics.** Wasserstein-1 and Hellinger distance added to methods (with equations), results (new paragraph + Table 2 rows for IS and OoS), and discussion (GARCH OoS deterioration analysis). Both metrics corroborate KS/AD ordering and expose GARCH's OoS tail collapse that binary pass rates obscured.

- [ ] **C7. Reproducibility artifact.** Self-contained package (data, scripts, environment files, README) for ACM artifact badge.

---

## Remaining Work: arXiv Preprint

### Step 1: Final polish (1-2 hours)

- [x] **Consistent spelling** -- American spelling applied globally (14 British→American fixes across 5 files)
- [x] **KS/AD i.i.d. caveat** -- Added in methods + limitations; W1/Hellinger cited as corroborating assumption-free metrics
- [x] **Verify all refs resolve** -- Run `pdflatex` + `bibtex` + `pdflatex` x 2 (all clean, no undefined refs)
- [x] **Verify all figures render** -- All 7 PDFs present in `paper/sections/figs/`; Fig2 is inline TikZ

### Step 2: arXiv upload (30 min)

- [x] **Upload to arXiv** -- Submitted 2026-03-10. Primary: `q-fin.ST`; Cross-list: `cs.LG`, `q-fin.RM`
- [x] **Choose arXiv categories** -- Primary: `q-fin.ST` (Statistical Finance); Cross-list: `cs.LG`, `q-fin.RM`
- [x] **Keep `nonacm` option** -- No ACM copyright notice for preprint

---

## Remaining Work: JDIQ Submission

### Phase 1: Address NEED items (2-3 weeks)

#### N1. Semi-Markov baseline ✅
- [x] Implemented HSMM with K={3,4,5,6,8} states, NegBin dwell times, Student-t(5) emissions
- [x] K=8 selected as best; all metrics computed with SEs
- [x] Added to Table 2 as 7th model (now 7 models x 10 metrics)
- [x] Added HSMM paragraph in results (baseline anchors) and discussion (jump mechanism subsection)

#### N2. Neural baseline ✅
- [x] Implemented 2-layer GRU autoregressive baseline in PyTorch
- [x] Run through same 10-metric evaluation pipeline (IS + OoS)
- [x] Added to Table 2 as 8th model (between GARCH and HSMM)
- [x] Added GRU paragraphs in results (baselines, temporal fidelity, OoS, tradeoffs) and discussion

#### N3. Multi-asset evaluation ✅
- [x] Run full pipeline on NVDA, JNJ, JPM (high/low/moderate beta)
- [x] Report Table S5 with KS/AD/kurtosis/ACF-MAE + SEs (IS and OoS)
- [x] Add Online Appendix S5 + forward reference in section 4.4

#### N4. KS/AD test validity discussion ✅
- [x] Added caveat in methods (pass rate paragraph) and Limitations subsection
- [x] W1 and Hellinger added as assumption-free corroborating metrics (block-bootstrap not needed given continuous metrics are now present)

#### N5. Temper volatility-clustering claims ✅
- [x] Review abstract, intro, conclusion for overstatement
- [x] Reframe: "partially reproduces" throughout abstract, intro, results, discussion, conclusion

#### N6. Kurtosis exploration ✅
- [x] Tested non-equal-probability bins (3x finer tail resolution) -- modest improvement
- [x] Tested Student-t emissions (df=3,4,5,6,7,8,10,15,30,Inf) -- df=5 optimal
- [x] Switched entire model emission from Normal to Student-t(df=5) permanently
- [x] Regenerated Table 2 with Student-t emissions (Table2-StudentT-Emissions.jl)
- [x] Updated all paper sections: methods, results, abstract, intro, conclusion, discussion, TikZ, supplemental

### Phase 2: Double-anonymous preparation (1 hour)

- [ ] **Anonymize authors** -- Switch `nonacm` to `anonymous` in documentclass options
- [ ] **Anonymize data availability** -- Remove GitHub URL; replace with "Available upon acceptance"
- [ ] **Check self-citations** -- No "our previous work" or identity-revealing citations
- [ ] **Anonymize code references** -- Remove VLQuantitativeFinancePackage name
- [ ] **Remove arXiv link** -- Do NOT reference preprint in JDIQ version

### Phase 3: JDIQ submission (1 hour)

- [ ] **Submit via ScholarOne** -- http://mc.manuscriptcentral.com/jdiq
- [ ] **Manuscript type** -- "Technical Paper" (up to 23 pages main body)
- [ ] **Page count compliance** -- Main body must be <= 23 pages
- [ ] **Cover letter** -- Highlight fit with special issue scope
- [ ] **Deadline** -- April 7, 2026

### Phase 4: Nice-to-have (if time permits)

- [ ] **C1.** Rolling OoS evaluation
- [ ] **C2.** N_tail sensitivity ablation
- [x] **C4.** Copula discussion in related work (factor models subsection; Embrechts et al. 2002, Cherubini et al. 2004)
- [x] **C5.** Privacy paragraph in discussion (practical implications; novelty/diversity as memorization guard; cites Dwork 2006, Stadler et al. 2022)
- [x] **C6.** Wasserstein-1 and Hellinger added to Table 2 (IS + OoS rows), methods, results, discussion
- [ ] **C7.** ACM reproducibility artifact

---

## File Inventory

| File | Status | Notes |
|------|--------|-------|
| `paper/Paper_v1.tex` | Ready | ACM acmsmall template; 28 pages incl. appendix |
| `paper/acmart.cls` | Installed | ACM document class |
| `paper/ACM-Reference-Format.bst` | Installed | ACM bibliography style |
| `paper/sections/introduction.tex` | Done | 3 paragraphs, JDIQ framing |
| `paper/sections/related.tex` | Done | 4 subsections |
| `paper/sections/methods.tex` | Done | Fig 2 + Algorithm 2 inline |
| `paper/sections/results.tex` | Done | Table 2 (6 models x 7 metrics), past tense, structured |
| `paper/sections/discussion.tex` | Done | 3 subsections: mechanism, implications, limitations |
| `paper/sections/conclusion.tex` | Done | 2 paragraphs |
| `paper/sections/endmatter.tex` | Needs anonymization for JDIQ | GitHub URL present |
| `paper/sections/supplemental.tex` | Done | Online Appendix S1--S4 |
| `paper/References_v1.bib` | Done | ~45 entries |
| `code/spy-experiment/` | Done | All main experiment scripts |
| `code/baseline-comparison/` | Done | Full 6-model benchmark |
| `code/sim-experiment/` | Done | Multi-asset SIM extension |
| `README.md` | Done | Public repo README |

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
| Template | acmsmall | ACM acmsmall |
| Review | Single-blind | Double-anonymous |
