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
- [x] **Template switch: elsarticle to ACM acmsmall** -- `\documentclass[acmsmall,nonacm]{acmart}` with `acmart.cls`, `ACM-Reference-Format.bst`, and all supporting files installed in `paper/`
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
- [x] **Baseline comparison (Phase 3.1)** -- Code in `code/baseline-comparison/`, run complete, Table 2 updated with 6 models × 8 metrics (KS, AD, kurtosis, ACF-MAE, novelty, diversity, coverage) all with SEs. Bootstrap, Gaussian, Laplace baselines added.

---

## Remaining Work: arXiv Preprint + JDIQ Submission

### Step 1: Text updates for new Table 2 results (1-2 hours)

- [ ] **Update abstract** -- Add baseline comparison language; mention novelty/diversity/coverage metrics
- [ ] **Update results prose** -- Add 1-2 paragraphs interpreting the 3 baselines and the 3 new metrics in Section 4.3 ("In-sample distributional and temporal quality")
- [ ] **Update introduction contributions** -- Add "comprehensive quality evaluation against naive baselines" as a contribution
- [ ] **Update discussion** -- Reference baseline results in the "role of jump-duration mechanism" subsection
- [ ] **Reconcile numbers** -- The new Table 2 run produced slightly different numbers for GARCH/HMM (different random seed). Check that abstract/intro/discussion/conclusion cite Table 2 values, not hardcoded old numbers. Key changes: GARCH IS KS 4.6->5.5, AD 1.1->1.9, HMM-WJ IS KS 97.1->97.0

### Step 2: Float layout polish (30 min)

- [ ] Resolve two-floats-on-same-page issue in Online Appendix (manual `\clearpage` placement)
- [ ] Rule: no page should have two floats (float + text is fine)

### Step 3: Discussion practitioner guidance (1 hour)

- [ ] Add subsection: "Practical guidance for synthetic data practitioners"
  - When to use N=100 vs lower/higher
  - When SIM extension is sufficient vs multivariate HMM needed
  - Quality thresholds: what KS/AD pass rate is "good enough"?

### Step 4: arXiv preprint (1 hour)

- [ ] **Page count check** -- Currently 27 pages (main + appendix). arXiv has no page limit, so this is fine
- [ ] **Remove `nonacm` option** -- Switch to `\documentclass[acmsmall]{acmart}` for proper ACM formatting, or keep `nonacm` for arXiv preprint (no ACM copyright notice)
- [ ] **Add arXiv identifier placeholder** -- Optional: add a footnote with "Preprint. Under review."
- [ ] **Verify all refs resolve** -- Run `pdflatex` + `bibtex` + `pdflatex` × 2
- [ ] **Verify all figures render** -- Check all 7 PDFs present in `paper/sections/figs/`
- [ ] **Upload to arXiv** -- Submit `Paper_v1.tex`, all `sections/*.tex`, `References_v1.bib`, `acmart.cls`, `ACM-Reference-Format.bst`, and all figure PDFs. arXiv accepts `.tar.gz` bundles
- [ ] **Choose arXiv categories** -- Primary: `q-fin.ST` (Statistical Finance) or `stat.ML`; Cross-list: `cs.LG`, `q-fin.RM`

### Step 5: Double-anonymous preparation for JDIQ (1 hour)

- [ ] **Anonymize authors** -- Switch `nonacm` to `anonymous` in documentclass options (acmart handles the rest)
- [ ] **Anonymize data availability** -- Remove or replace GitHub URL in `endmatter.tex` with "Available upon acceptance"
- [ ] **Check self-citations** -- Ensure no "our previous work" or citations that reveal identity
- [ ] **Anonymize code references** -- If the paper mentions the GitHub repo or package names (VLQuantitativeFinancePackage), anonymize
- [ ] **Remove arXiv link** -- If arXiv preprint is posted before JDIQ submission, do NOT reference it in the JDIQ version (breaks anonymity)

### Step 6: JDIQ submission (1 hour)

- [ ] **Submit via ScholarOne** -- http://mc.manuscriptcentral.com/jdiq
- [ ] **Manuscript type** -- "Technical Paper" (up to 23 pages main body)
- [ ] **Page count compliance** -- Main body must be ≤ 23 pages; Online Appendix is separate. Current main body needs measurement (currently ~20 pages before appendix)
- [ ] **Upload supplemental** -- Online Appendix as separate PDF or bundled in same PDF
- [ ] **Cover letter** -- Highlight fit with special issue scope: synthetic data quality, domain-specific evaluation methodology, quality guarantees by design
- [ ] **Suggest reviewers** -- Optional but helpful; suggest researchers in synthetic data quality or financial time series modeling
- [ ] **Deadline** -- April 7, 2026

### Step 7: Optional strengthening (if time permits)

- [ ] **Reproducibility artifact** -- Self-contained package (data, scripts, environment files, README) for ACM artifact badge
- [ ] **Additional quality metrics** -- Wasserstein distance, MMD (standard in synthetic data literature)

---

## File Inventory

| File | Status | Notes |
|------|--------|-------|
| `paper/Paper_v1.tex` | Done | ACM acmsmall template; 27 pages incl. appendix |
| `paper/acmart.cls` | Installed | ACM document class |
| `paper/ACM-Reference-Format.bst` | Installed | ACM bibliography style |
| `paper/sections/introduction.tex` | Needs update | Reconcile numbers with new Table 2 |
| `paper/sections/related.tex` | Done | 4 subsections |
| `paper/sections/methods.tex` | Done | Fig 2 + Algorithm 2 inline |
| `paper/sections/results.tex` | Needs update | Table 2 updated; prose needs baseline interpretation |
| `paper/sections/discussion.tex` | Needs update | Reference baseline results |
| `paper/sections/conclusion.tex` | Needs update | Reconcile numbers |
| `paper/sections/endmatter.tex` | Needs anonymization | GitHub URL must be removed for JDIQ |
| `paper/sections/supplemental.tex` | Done | Online Appendix S1--S4 |
| `paper/References_v1.bib` | Done | ~45 entries |
| `code/spy-experiment/` | Done | All main experiment scripts |
| `code/baseline-comparison/` | Done | Baseline-Comparison.jl + Include.jl + Project.toml |

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
