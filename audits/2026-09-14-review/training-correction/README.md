# Item 5: reconcile the canonical training results with Table 3

The complete six-method training comparison was regenerated from the frozen
fits and current construction. **All 250,800 paths reproduced the historical
centered cache exactly for every stored score. Table 3 and its two supplementary
breakdowns retain every displayed value.** The stale canonical JLD2 and the
obsolete three-method CSV have been replaced by the verified run and a matching
six-row summary. Both manuscripts document the provenance and were rebuilt.

## Cause and numerical resolution

Commit `e7cef92` on 11 August 2026 introduced realized-path centering in the
naive and hybrid composers. The local `results-centered.jld2` reflected that
construction and supplied the manuscript values, but `results.jld2` retained
the older uncentered results. The advertised `results-summary.csv` was older
still: 126,900 individual path rows for only three methods. Script 04 defaulted
to the stale JLD2 and wrote only to JFDS, so the documented command could
replace correct manuscript entries with obsolete results.

The rerun retained the 423 non-market training assets, 100 paths of 2,766
observations per asset, seed 1234, observed training SPY, frozen no-jump models,
and the unchanged native centering and scaling rules. GARCH covered the same
393 accepted assets and 39,300 paths; each other method produced 42,300 paths.
No model was refit and no estimator or scientific setting changed.

| Quantity | Old canonical cache | Regenerated cache | Existing Table 3 |
|---|---:|---:|---:|
| Naive KS pass (%) | 4.4681 | 7.1418 | 7.1 |
| Hybrid KS pass (%) | 50.3735 | 73.6454 | 73.6 |
| Naive median intercept error | 0.102134 | 0.002351 | 0.002 |
| Hybrid median intercept error | 0.083051 | 0.001911 | 0.002 |
| Hybrid median Wasserstein-1 | 0.271855 | 0.249241 | 0.249 |

The four other methods matched the old canonical cache exactly. All nine
stored numeric scores for every path matched `results-centered.jld2` exactly,
including the naive and hybrid rows. Every comparable native path metric in
the September centering control also agreed. These comparisons establish the
link between current code, frozen inputs, regenerated rows, and the existing
tables. They do not reconstruct every historical file-copy operation.

The original files and table sources are preserved under `before/`; their
SHA-256 hashes are in `before-manifest.json`. Large original caches are kept
locally and ignored by Git. The original distributed cache and CSV also remain
available in commit `2d9c8e5`. The original audit and Fable responses are intact.

## Production changes

`scripts/03-Compose-And-Evaluate.jl` now invokes the canonical training runner
in `src/TrainingResults.jl`. Generation retains the original production order
and random streams. Deterministic scoring is threaded and reuses the
Anderson--Darling normalization for equal sample lengths. Both the optimized
scorer and the complete runner were checked against the original calculation.
`src/TrainingSetup.jl` loads the numerical dependencies without plotting or
package-manager activation, allowing the pinned environment to run with a
read-only Julia depot.

The runner requires all fitted caches, checks the no-jump specification and
GARCH eligibility, and checkpoints each asset. Checkpoints are reused only
with matching source, input, model, configuration, dependency, and Julia-version
fingerprints. Before installing canonical results, it checks all asset/method/
replication keys, denominators, settings, and finite scores. The final artifact
hashes detect incomplete or changed output files before table generation.

The output files have distinct roles:

- `data/results.jld2`: all 250,800 path rows, configuration, and provenance.
- `data/results.csv`: the same path rows as a convenient CSV, ignored by Git.
- `data/results-summary.csv`: six method summaries with explicit denominators.
  This replaces the old per-path CSV schema; raw rows are now in `results.csv`
  or the distributed JLD2.
- `data/results-metadata.toml`: source, input, model, dependency, and artifact
  fingerprints, run settings, and GARCH eligibility.
- `data/results-tables.toml`: table and formatter hashes linked to the run.

Script 04 validates the cache and summary before generating Table 3, Table S5
(branches), and Table S8 (loading quartiles), writing arXiv first and then
JFDS. `--check` regenerates table text in memory and requires exact agreement
with both trees. Legacy caches and the old results-file override are rejected.
The distributed path cache can generate the tables without local fitted-model
archives; an archive that is present must match its recorded fingerprint.

## Validation

The test logs and machine-readable reports record:

- 73 scoring, generation, eligibility, completeness, and provenance checks.
- 20 direct comparisons against the unchanged `run_composer_experiment` loop,
  using an isolated six-asset calibration containing both tracker assets and
  GARCH exclusions. Every output column agreed exactly.
- Full comparison of all 250,800 keys and nine numeric score columns with the
  historical centered run; the maximum absolute difference was zero.
- Agreement with all available native metrics from the centering control.
- Independent Python aggregation of the full CSV, checking all six summaries
  and every data cell of the three tables in both trees. The largest numeric
  summary difference was `1.42e-14` from floating-point CSV arithmetic.
- Exact table agreement using script 04's read-only `--check` mode.
- Four checkpoint-recovery checks: recovered rows, serialized rows, and the
  compact CSV agree exactly; a change in path count rejects existing checkpoints.

The arXiv manuscript, JFDS manuscript, and JFDS supplement built successfully.
The added Methods passage and regenerated tables were visually checked. No
undefined references or new overfull boxes appeared; the four previously
recorded JFDS width warnings remain. Final checks and PDF hashes are recorded
in `verification.json`.

## Reproduction

From the repository root, after preparing the frozen model caches:

```sh
julia --compiled-modules=existing --threads=4 --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/03-Compose-And-Evaluate.jl
julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/04-Tables.jl
julia --compiled-modules=existing --project=code/downstream-evaluation \
  code/downstream-evaluation/scripts/04-Tables.jl --check
julia --compiled-modules=existing --threads=4 --project=code/downstream-evaluation \
  code/downstream-evaluation/test/training_results.jl
python3 audits/2026-09-14-review/training-correction/verify_tables.py
```

Use `--restart` on script 03 to recompute rather than resume checkpoints.
`verify_caches.jl` uses the preserved historical archives for the before/after
comparison; `verify_pipeline.jl` exercises the original loop on isolated inputs.
`verify_resume.jl` checks recovery into a temporary output directory and refusal
of checkpoints with changed settings.

This resolves ranked item 5, corresponding to R2 in the original audit. It does
not resolve Figure 4's variance-denominator and aggregation descriptions (R4),
which remain the next correction. Holdout scores, pooled VaR results, the
centering control, fitted models, and figures were not changed by this task.
