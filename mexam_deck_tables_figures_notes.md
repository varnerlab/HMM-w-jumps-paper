# Paper I tables and figures in the M-exam deck

Date: 2026-07-08

Scope: records which Paper I (jump-HMM / HMM-WJ) tables and figures are used in the M-exam defense
deck, the numeric caveats that matter for the defense, and the in-sample vs out-of-sample figure/table
consistency on the SIM scaling slide. Companion to `emission_reconstruction_notes.md`. Deck source:
`M-exam-presentation-preparation/` (built by `scripts/build_deck.py`; tables rendered by
`scripts/render_tables.py` to `figures/tables/<label>.png`).

## 1. Paper I tables now in the deck

All Paper I slide tables are rendered as booktabs PNGs (thesis idiom) and drop the standard-error
parentheses for on-slide legibility. This is a deck-wide convention, not a data change; the manuscript
keeps the SEs.

| Deck label | Manuscript source | Where in deck |
|---|---|---|
| tbl-p1-comparison | tab:model_comparison (results.tex) | main proof slide (Bootstrap / GARCH(1,1)-t / HMM-NJ / HMM-WJ, IS+OoS) |
| tbl-p1-sim | tab:multi_asset (supplemental.tex) | main "Scaling to 424 assets" slide |
| tbl-p1-copula | tab:copula_comparison | main copula-basket slide |
| tbl-p1-sensitivity | tab:sensitivity_results (supplemental.tex) | backup "Sensitivity to state resolution N" |
| tbl-p1-emit-hsmm | tab:emission_hsmm_s9 (supplemental.tex) | backup "Emission vs persistence: three-way isolation" |

The last two were added for the M-exam:
- **tbl-p1-sensitivity (T1):** the 12-row N-sweep (HMM-NJ and HMM-WJ over N = 30..200). Values verbatim
  from tab:sensitivity_results; SEs dropped; no bold in the source. HMM-WJ |return|-ACF error falls
  0.057 -> 0.049 as N grows; N=100 is the operating point.
- **tbl-p1-emit-hsmm (T4):** the three-way HSMM (Student-t, K=8, 18 params) vs HMM-WJ (Gaussian, 4) vs
  HMM-WJ (Student-t, 4). Values verbatim from tab:emission_hsmm_s9; SEs dropped; the manuscript's
  best-in-row bold is preserved exactly, including the two OoS rows where the bolded cell is not the
  numeric extreme (KS pass and Wasserstein-1). It isolates two axes at once: persistence (HSMM sojourn
  vs Poisson jumps) and emission (Gaussian vs Student-t).

Both live on repurposed Project I backup slides (no new slides): T1 replaced the Poisson jump-duration
zoom (redundant with the main pipeline hero), T4 replaced the grid-search backup (the grid-search
objective and contour are still shown on the main Project I slide).

## 2. SIM in-sample KS caveat (tab:multi_asset / Fig7)

The one place the deck and the manuscript disagree on a number is the SIM **in-sample** KS pass-rate
row:

- Deck (tbl-p1-sim and Fig7-Multi-Asset-SIM): IS KS mean 60.3, median 69.8.
- Manuscript (tab:multi_asset text/table and results.tex): IS KS mean 58.4, median 66.7.

Everything else agrees. This is a known reproducibility drift, fully documented in
`code/sim-experiment/SIM-KS-REPRODUCIBILITY.md`: the per-asset residual bootstrap in
`SIM-Multi-Asset-KS.jl` is not pinned to its own RNG seed, so a cache regeneration shifts only the
bootstrap-dependent IS KS row (the R^2 / beta / alpha rows and the entire OoS panel are stable). The
deck deliberately uses the current-cache numbers so its own table and Fig7 agree. The gap is ~3 pp on
a supporting cross-asset result and does not change any conclusion.

## 3. Slide "Scaling to 424 assets": IS figure only; OoS is table-only

The scaling slide shows the **in-sample** figure Fig7-Multi-Asset-SIM (fig:multi_asset): panel (a)
R^2 vs beta by GICS sector, panel (b) the KS pass-rate distribution across 424 assets. The slide's
table (tbl-p1-sim) reports **both** IS and OoS panels, but the figure only depicts IS.

The out-of-sample companion figure is **Fig7S-Multi-Asset-SIM-OoS** (fig:multi_asset_oos), a full-width
multipanel: panel (a) OoS SIM fit by sector, panel (b) OoS KS pass-rate distribution, panels (c1)-(c3)
density fan charts for NVDA, JNJ, QQQ. It is present in the manuscript
(`code/sim-experiment/figs/Fig7S-Multi-Asset-SIM-OoS.pdf`) but is **not** currently a deck asset (no
PNG under `M-exam-presentation-preparation/figures/`).

Accuracy check (OoS figure vs the slide table): they agree exactly. Fig7S reports OoS KS median 91.8%,
mean 82.1%; the tbl-p1-sim OoS row is mean 82.1, median 91.8; the manuscript matches. Unlike the IS
case in section 2, the OoS numbers are consistent across the figure, the table, and the manuscript, so
there is no reproducibility wrinkle out-of-sample.

Recommendation: if the OoS figure is wanted in the deck, the clean home is a Project I backup slide
(it is a supplemental, full-width 5-panel figure and would overcrowd the already-full scaling slide).
Converting the source PDF to PNG (via the deck's pdf_to_png helper) and adding it as a single-figure
backup mirrors the existing IS/OoS companion pattern. Alternatively it can be left out, since the
slide table already carries the OoS numbers.
