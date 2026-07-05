# SIM KS pass-rate reproducibility note

## Summary

The Single-Index Model (SIM) **in-sample KS pass-rate** summary statistics are not
reproducible across regenerations, and as a result the manuscript is internally
inconsistent: the Table 4 (`tab:multi_asset`) text and the Figure 7
(`Fig7-Multi-Asset-SIM`) image report different numbers for the same quantity.

| IS SIM KS pass rate | Median | Mean |
|---|---|---|
| Manuscript **table/text** (`tab:multi_asset`, results/discussion/conclusion) | 66.7% | 58.4% |
| Manuscript **figure** image (`Fig7-Multi-Asset-SIM.pdf`) and current cache | **69.8%** | **60.3%** |

Everything else agrees. Re-running `Table4-Multi-Asset-Stats.jl` against the current
cache today prints:

```
--- In-sample (424 assets) ---
KS pass rate   Mean=60.27  Median=69.85  5th=2.10  95th=96.94
R²             Mean=0.298  Median=0.295  5th=0.107  95th=0.507
β              Mean=1.066  Median=1.086  5th=0.480  95th=1.657
α              Mean=-0.0328 Median=-0.0196 ...
--- Out-of-sample (417 assets) ---
KS pass rate   Mean=82.06  Median=91.80  5th=23.78  95th=99.00   (matches the manuscript)
R² / β / α     ... (match the manuscript)
```

Only the **IS KS pass-rate row** differs from the frozen manuscript numbers. The IS
`R²`, `β`, `α` rows and the entire OoS panel are identical. This is the decisive clue:
the quantities that changed are exactly the ones that depend on the residual bootstrap,
and the quantities that stayed fixed are the ones that do not.

## Root cause

Both artifacts read the same cache and compute the same summary, so on a single cache
they agree:

- `Fig7-Multi-Asset-SIM.jl:23` -> `load(".../SIM-Multi-Asset-Results.jld2")`
- `Table4-Multi-Asset-Stats.jl:55` -> `load(".../SIM-Multi-Asset-Results.jld2")`

The divergence means the cache `data/SIM-Multi-Asset-Results.jld2` was **regenerated**
(by `SIM-Multi-Asset-KS.jl`) between the time the Table-4 `.tex` numbers were written and
the time the figure PDF was rendered.

Regenerations do not reproduce the IS KS pass rates because the per-asset residual
bootstrap is not pinned to its own seed. In `SIM-Multi-Asset-KS.jl`:

```julia
# line 66: the SPY paths ARE seeded
wj_result = simulate(model_wj, T_is; n_paths = _N_PATHS, seed = 1234)
...
# line 116: the residual bootstrap draws from the GLOBAL RNG, not a pinned/local RNG
η_hat = resid_i[rand(1:T_is, T_is)]   # resample with replacement
```

`Include.jl:43` does `Random.seed!(1234)` once at load, and `simulate(...; seed=1234)` is
seeded, so a **single run is deterministic**. But the bootstrap at line 116 rides the
global RNG stream at that point, which is not re-pinned immediately before the loop. Any
change upstream of it — a `JumpHMM.jl`/Julia version bump that alters how `simulate`
consumes the RNG, a reordering, a dependency update — shifts the global stream and yields
different bootstrap draws, hence different KS pass rates on the next regeneration.

Why only IS KS moved: `R²` (lines 105-109) is computed directly from the empirical
residuals with no random draws, so it is stable; the OoS KS in the cache simply was not
regenerated out of step with its text. The bootstrap-dependent IS KS is the one fragile
quantity, and it is the one that drifted.

## Impact

- Manuscript Table 4 / Figure 7 disagree on IS SIM KS (66.7/58.4 vs 69.8/60.3).
- The qualitative conclusions are unaffected: the SIM IS median KS is ~67-70% (well below
  the 95% ceiling), high-β assets track SPY, degradation concentrates on low-R² names, and
  the copula fix restores KS > 95%. The gap is ~3 pp on a supporting cross-asset result.

## Recommended fix

1. Pin the bootstrap to a dedicated RNG in `SIM-Multi-Asset-KS.jl` (and the OoS twin
   `SIM-Multi-Asset-KS-OoS.jl`), e.g.:
   ```julia
   rng = MersenneTwister(1234)          # or Random.seed!(1234) immediately before the loop
   ...
   η_hat = resid_i[rand(rng, 1:T_is, T_is)]
   ```
   This makes the KS pass rates immune to upstream RNG-stream changes.
2. Regenerate the cache, then regenerate **both** Table 4 and Figure 7 from that one cache
   in the same session so they can never diverge again.
3. Update the Table-4 `.tex` (and the results/discussion/conclusion prose and the Fig-7
   caption) to the regenerated numbers.

## M-exam deck decision

For the M-exam slides we use the **current-cache / figure numbers** (IS KS median 69.8% /
mean 60.3%), rendering the SIM table from the current cache so the slide's table and figure
agree. This note records why the manuscript's 66.7/58.4 differs.
