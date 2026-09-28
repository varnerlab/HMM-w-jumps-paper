# R7: emission fallback documentation and paired sensitivity

Completed 15 September 2026. The author approved documenting the fitted
fallback policy, listing the affected assets, and measuring sensitivity before
changing any fitted model. R7 is resolved under that retained-fit policy.
The original fitted caches and canonical training scores remain unchanged.

## What the implementation does

The pinned JumpHMM implementation uses the full training series of each asset
for fallback moments. A state with fewer than two observations uses the global
mean and standard deviation. A populated state with sample standard deviation
below `1e-12` retains its state mean but uses the global standard deviation as
its Student-t scale. The scale is not the emission standard deviation. With
five degrees of freedom, the latter is the scale multiplied by `sqrt(5/3)`.
The same rules apply to residual-fit generators using their residual series.

Intervals include the lower boundary and exclude the upper boundary. A counted
transition row with no outgoing observations is uniform across all states;
the observed likelihood does not identify that row. A final-only singleton
could also produce such a row, even though all seven actual uniform rows in
these fits corresponded to empty states.

Both manuscript versions now describe these rules in Methods and the
derivation. They qualify the SPY-specific moment identities, give the full
piecewise emission rule, and add supplementary Tables S17 and S18. The
state-resolution discussion and hyperparameter range now agree with the
reported and implemented sweep through `N=200`. The unsupported assertion
that emissions at `N=350` could not be estimated was removed; no new `N=350`
performance experiment was conducted.

## Inventory

Reconstruction from training inputs matched every saved emission parameter and
transition probability in all 424 full-return and 423 residual-fit models.

| Quantity | Result |
|---|---:|
| Full-return models requiring fallback | 39 of 424 |
| Fallback states | 50 of 42,400 |
| Populated constant states | 39, with 11–119 identical observations each |
| Empty states | 7 |
| Singleton states | 4 |
| Uniform transition rows | 7 |
| Fallback stationary mass per affected asset | 0.399–4.300% |
| Maximum sparse-state stationary mass per asset | 0.0363% |
| Residual-fit models requiring fallback | 0 of 423 |

SPY required no fallback. Every affected full-return asset had one populated
constant state. Table S17 lists all 39 assets, observation counts, sparse-state
counts, fallback mass, and the analytic stationary mixture-variance change.
The complete state inventories are in
[the diagnostic output directory](../../../code/downstream-evaluation/results/fallback-diagnostic/).

## Paired sensitivity

The control replaces the global scale only in populated near-constant states
with that state's empirical scale. Zero scale represents a point mass. State
means, partitions, transitions, initial probabilities, and sparse-state
fallbacks are fixed. This is an isolated diagnostic, not a selected model.

For each of the 39 assets, the experiment replays the original 100 paths of
2,766 observations using the original calibration-row seed schedule. Both
treatments receive identical state sequences and random draws, with jumps
disabled and the same observed training SPY path. Unmodified-state returns
are identical. Each treatment is scored before composition and after the
production naive and hybrid compositions, using its own generator variance.

All nine canonical metrics and the effective loadings/branch labels for the
7,800 original composed paths match exactly. The full comparison contains
23,400 scored paths. Table S18 reports means over the fixed assets and
replications. Its paired Monte Carlo standard errors are the standard
deviation of 100 replication-level mean differences divided by `sqrt(100)`.
They describe simulation uncertainty, not uncertainty over historical markets.

| Hybrid metric, affected assets only | As fitted | Empirical scale | Paired change (MC SE) |
|---|---:|---:|---:|
| KS pass (%) | 68.64 | 78.92 | +10.28 (0.49) percentage points |
| AD pass (%) | 56.15 | 70.23 | +14.08 (0.60) percentage points |
| Wasserstein-1 distance (yr^-1) | 0.2782 | 0.2474 | −0.0308 (0.0002) |
| Variance / observed variance | 1.0775 | 1.0556 | −0.0219 (0.0001) |
| Absolute-return ACF-MAE, lags 1–25 | 0.10289 | 0.10145 | −0.00144 (0.00002) |

Hybrid KS pass rates increased for 37 assets and were unchanged for two;
asset-level changes ranged from 0 to 40 percentage points. The analytic
stationary mixture variance of the uncomposed generator fell by 0.651–6.520%.
Thus the fallback scale affects the generator's variance and composed
marginal fit. These comparisons retain the original scoring functions, whose
KS/AD pass fractions are descriptive for dependent series containing ties.
They do not validate a replacement on holdout histories or assess alternative
sparse-state estimates. The main performance comparisons retain the original
fitted policy.

## Verification and reproduction

From the repository root:

```sh
julia --compiled-modules=existing --threads=4 --project=code/downstream-evaluation code/downstream-evaluation/scripts/16-Fallback-Diagnostic.jl
python3 code/downstream-evaluation/scripts/17-Fallback-Tables.py
python3 audits/2026-09-14-review/fallback-correction/verify_numerics.py
make -C arxiv-paper pdf
make -C jfds-paper all
```

The diagnostic validates canonical provenance before running. Its metadata
records source and output hashes and links the canonical training signature.
The table formatter verifies those fingerprints before writing both papers.
The independent Python check recomputes inventory classifications, counts,
mixture variances, exact canonical-score agreement, all 15 paired summaries
and standard errors, and the printed values in both generated tables.
The largest summary discrepancy was `1.42e-14`. Six additional Julia boundary
checks covered interval endpoints, constant/singleton/empty emissions, and
observed versus zero-outgoing transition rows.

Both paper builds completed without undefined references or new overfull-box
warnings. The existing JFDS main warning and three supplement warnings remain.
The arXiv manuscript is 51 pages; Tables S17/S18 are on pages 50/51. The JFDS
main manuscript is 30 pages and its supplement is 38 pages, with the new
tables on supplement pages 35/37. Figure 4 remains on arXiv page 24 and JFDS
page 19. All pages were inspected in contact sheets, with separate 120-dpi
inspection of Methods and the new equation and tables in both formats.

- [Run log](run.log)
- [Independent numerical verification](numerical-checks.json)
- [Boundary checks](boundary-checks.log)
- [Final artifact/build/visual record](verification.json)
- [PDF page inventory and renders](pdf-qa/manifest.json)
- [Current review status](../STATUS.md)

The before snapshots preserve the working state after the accepted Figure 4
update. All changes remain local and uncommitted. Release archives await the
final review and reproduction step; the remaining review findings are tracked
separately in the status file.
