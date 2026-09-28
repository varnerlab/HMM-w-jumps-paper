# R11: scope of the synthetic-tracker check

Completed 15 September 2026. R11 is resolved by matching the manuscript claim
to the experiment performed. The grid remains a restricted Gaussian check of
branch selection and parameter recovery. Both manuscript versions now disclose
its unit residual scale, observed market path, direct residual input, and
uncalibrated nominal Kolmogorov–Smirnov (KS) pass rates. Table S6's numerical
results are unchanged.

## What the original grid actually tested

Script 08 constructed 100 reference/composed pairs at each of 15 cells:
loading β in `{0.8, 1.0, 1.2}` and target R² in
`{0.80, 0.85, 0.90, 0.95, 0.99}`. Every pair used the same observed
2,766-day SPY growth-rate history. The reference was β times the market plus
a Gaussian residual with nominal variance
`β² var(market) (1 − R²) / R²`. The composer received another Gaussian
residual directly, with that same nominal variance supplied as its generator
variance. The resulting scale factor was exactly one.

No full-return hidden Markov model was fitted to a synthetic tracker, no
full-return draw was converted into a residual at a non-unit scale, and no
new market path was generated in this grid. The grid therefore does not
establish performance of the full fitted reuse pipeline across its parameter
range. Empirical evidence for the tracker branch remains limited to QQQ and
SPYG in the main experiment.

The two finite-path constructions were not identical: the composer centered
its residual, while the reference retained a random residual mean. Replay
gave a maximum absolute composed-residual mean of `7.19e-17`, versus a
cross-replication standard deviation of `0.0187123` for the reference's residual
mean. Realized residual variance divided by nominal target variance ranged
from `0.908934` to `1.090299`. The grid thus has finite-path variation despite
its unit scaling. Its loading and R² estimates are near their nominal targets,
not guaranteed to equal them on each path.

The usual two-sample KS reference compares independent samples from continuous
distributions, as described in the [official SciPy documentation](https://docs.scipy.org/doc/scipy-1.11.0/reference/generated/scipy.stats.ks_2samp.html).
The conclusion for this experiment follows from its inspected construction:
shared time-varying market observations and whole-path residual centering
do not establish that reference calibration. The manuscript now treats the
100% nominal pass rates as descriptive. This correction does not claim a
measured degree of conservatism, calibrated test size, or distributional
equivalence.

## Validation

[replay_grid.jl](replay_grid.jl) reconstructs the original seed schedule,
market path, Gaussian draws, composer calls, and scoring. All 1,500 saved
per-replication rows reproduce exactly in every column, and all 15 grouped
summaries reproduce exactly. The manuscript's displayed entries agree with
those summaries at their printed precision.

[tracker_branch.jl](../../../code/downstream-evaluation/test/tracker_branch.jl)
adds separate implementation checks at scale factors `0.25` and `2`, with
Student-t inputs, positive and negative loadings, and horizons 249 and 2,766.
The checks cover residual variance, centering, retained loading, the finite-path
covariance contribution to ordinary-least-squares recovery, invariance to a
change in generator units, the branch threshold, and zero residual variance at
R² = 1. These tests exercise the implementation beyond the original grid;
they do not constitute a new fitted-model experiment or temporal validation.

All 492 assertions passed: 474 branch assertions and 18 replay assertions.
Logs are [branch-tests.log](branch-tests.log) and [replay.log](replay.log);
[grid-checks.toml](grid-checks.toml) records numerical diagnostics.

The production composer, scoring helper, inputs, configuration, and historical
CSV/JLD2 outputs retain their pre-R11 hashes. Script 08's comments now describe
the restricted design accurately. Its parsed executable syntax is unchanged
after removing source-location metadata. The original script is preserved in
[08-Synthetic-Tracker-Eval.before.jl](08-Synthetic-Tracker-Eval.before.jl), with
the before/after hashes recorded in [verification.json](verification.json).

## Manuscript changes and PDF checks

- Results distinguish the two empirical trackers from the Gaussian branch
  check, state its direct residual input and unit scale, and qualify the KS
  interpretation: arXiv page 13 and JFDS page 24.
- Discussion restricts what the grid supports: arXiv page 14 and JFDS page 26.
- The supplementary construction explains both samples and their different
  centering: arXiv page 40 and JFDS supplement page 22.
- Table S6's caption and column header identify the restricted check and
  nominal KS pass rates: arXiv page 41 and supplement page 23.

Both standard builds completed. The final arXiv PDF has 53 pages, the JFDS
main PDF has 32, and its supplement has 41. The additional JFDS main page is
reference-list reflow from the expanded explanation. The JFDS installed PDF
copies match their builds. All 126 pages were inspected in 12 contact sheets,
with eight changed pages inspected at 120 dpi. No new clipping, overlap,
detached captions, or single-line paragraph widows/orphans were observed.
There are no undefined or duplicate references and no new overfull-box
warnings; the four previously recorded JFDS width warnings remain. Figure 4's
accepted assets remain byte-identical, with no marker changes.

## Reproduction and remaining scope

From the repository root:

```sh
julia --compiled-modules=existing --project=code/downstream-evaluation code/downstream-evaluation/test/tracker_branch.jl
julia --compiled-modules=existing --project=code/downstream-evaluation audits/2026-09-14-review/tracker-correction/replay_grid.jl
make -C arxiv-paper pdf
make -C jfds-paper all
python3 audits/2026-09-14-review/tracker-correction/render_review.py
python3 audits/2026-09-14-review/tracker-correction/verify_artifacts.py
```

R1–R11 are now resolved at their recorded scope. The audit's additional
scientific and presentation follow-ups still require triage. Full fitted
tracker-grid validation, release archive regeneration, and final package
reproduction are not claimed by this correction. Changes remain local and
uncommitted.
