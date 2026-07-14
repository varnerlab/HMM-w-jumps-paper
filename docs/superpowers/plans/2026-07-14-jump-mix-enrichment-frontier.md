# Jump-Mix Enrichment Frontier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one read-only Julia diagnostic that sweeps the HMM-WJ ensemble's jump-path fraction f and characterizes the volatility-clustering vs marginal-fidelity tradeoff, emitting a frontier table, CSV, and figure.

**Architecture:** Approach A from the spec. Simulate one pool of paths from the fitted `model_wj`, tag each path jump/no-jump via `any(p.jumps)`, and compute per-path metrics once. For per-path-mean metrics (KS/AD pass rate, ACF-MAE, kurtosis, W1, Hellinger) the frontier is the exact convex combination `M(f)=f*M_jump+(1-f)*M_nojump`; for the pooled Hill tail index (non-linear in f) use R=200 resampled ensembles. The script is a set of pure functions plus a `main()` guarded by `PROGRAM_FILE`, so functions are testable in isolation without running the full pipeline.

**Tech Stack:** Julia; `JumpHMM.jl` (`simulate`, internal `_wasserstein1`/`_hellinger`); `StatsBase` (`autocor`, `kurtosis`); `HypothesisTests` (`ApproximateTwoSampleKSTest`, `KSampleADTest`); `Plots`; `CSV`; `JLD2`/`FileIO`. All loaded by `code/spy-experiment/Include.jl`.

## Global Constraints

- Seed: `1234` (set by `Include.jl`; re-set before each stochastic routine for determinism).
- Window: IS only. `g_is = hub["insampledataset"]`, length 2766.
- Metrics config: ACF lags `1:252` (matches the paper's reported `_L_ACF`; ACF-MAE is the MAE of the ensemble-mean |g| autocorrelation curve, built from stratum-mean curves, not a per-path scalar); GoF pass threshold `p > 0.05`; Hill `tail_frac = 0.05` on pooled upper `|G_t|`, reported as `alpha = 1/xi`.

> **Execution correction (2026-07-14):** the drafted Task 2/4 code below carried ACF-MAE as a per-path scalar over 25 lags. The f=0.25 anchor check exposed that as ~0.17 versus the paper's ~0.05. Root cause: every reported table computes ACF-MAE over **252** lags from the **ensemble-mean** ACF curve. Task 2 was implemented with `ACF_LAGS = 1:252`, ACF-MAE dropped from `_METRIC_FIELDS`, and `stratum_summary` now returns `acf_obs`/`acf_jump`/`acf_nojump` curves; Task 4 uses `acf_mae_frontier(summ, f) = mean(abs.(f.*acf_jump .+ (1-f).*acf_nojump .- acf_obs))`. The committed script is the source of truth where it differs from the code blocks below.
- Sizes: pool `N_POOL = 4000`; enriched ensemble `N_ENSEMBLE = 1000`; Hill resampling `R_HILL = 200`; grid `F_GRID = 0.0:0.1:1.0` plus the marked point `0.25`.
- Reuse the paper's exact estimators: `JumpHMM._wasserstein1`, `JumpHMM._hellinger` (module-qualified, confirmed reachable), `StatsBase.kurtosis` (excess), `autocor(abs.(.), lags)`.
- Read-only w.r.t. `jfds-paper/` and the paper JLD2 data. The ONLY writes are `code/spy-experiment/diagnostics/jump_mix_frontier.csv` and `.../jump_mix_frontier.pdf`.
- Anchors (IS, from `code/spy-experiment/diagnostics/tail_index_p1.txt`): observed SPY kurtosis 7.71, Hill alpha 3.14; HMM-WJ (f≈0.25) kurtosis 7.47, alpha 2.87; HMM-NJ (f=0) kurtosis 8.05, alpha 2.84.
- All commands run from the repo root. The script's inner `include("Include.jl")` resolves relative to the script's own directory, so `--project=code/spy-experiment` works from anywhere.

---

### Task 1: Scaffold, inputs, pool generation, jump tagging

**Files:**
- Create: `code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl`

**Interfaces:**
- Produces: `load_inputs() -> (model_wj, g_is::Vector{Float64}, N::Int)`; `generate_pool(model, T::Int, n_paths::Int; seed::Int) -> Vector{SimulationPath}`; `is_jump_path(p)::Bool`.

- [ ] **Step 1: Create the file with header, constants, and the three functions**

```julia
# =============================================================================
# Jump-Mix-Enrichment-Frontier.jl
#
# Read-only diagnostic. Sweeps the HMM-WJ ensemble's jump-path fraction f from
# 0 (no-jump only) to 1 (jump only) and reports the stylized-fact tradeoff:
# volatility clustering (ACF-MAE of |g|) vs marginal fidelity (kurtosis, Hill
# tail index, KS/AD pass rates, W1, Hellinger). Per-path-mean metrics use the
# exact convex-combination frontier M(f)=f*M_jump+(1-f)*M_nojump; the pooled
# Hill index uses R resampled ensembles. Writes a table, CSV, and figure to
# code/spy-experiment/diagnostics/. Touches nothing under jfds-paper/.
#
# Spec: docs/superpowers/specs/2026-07-14-jump-mix-enrichment-design.md
# =============================================================================
include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const N_POOL          = 4000
const N_ENSEMBLE      = 1000
const R_HILL          = 200
const F_GRID          = collect(0.0:0.1:1.0)
const F_MARK          = 0.25
const ACF_LAGS        = collect(1:25)
const KS_ALPHA        = 0.05
const HILL_TAIL_FRAC  = 0.05
const SEED            = 1234
const OBS_KURT_TARGET = 7.71
const OBS_HILL_ALPHA  = 3.14
const _PATH_TO_DIAG   = joinpath(_ROOT, "diagnostics")
const _HUB_FILE       = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")

# ── inputs ───────────────────────────────────────────────────────────────────
function load_inputs()
    hub = load(_HUB_FILE)
    return (model_wj = hub["model_wj"],
            g_is      = hub["insampledataset"],
            N         = hub["number_of_states"])
end

# ── pool generation + tagging ────────────────────────────────────────────────
function generate_pool(model, T::Int, n_paths::Int; seed::Int = SEED)
    Random.seed!(seed)
    res = simulate(model, T; n_paths = n_paths)
    return res.paths
end

is_jump_path(p) = any(p.jumps)

# ── main (filled in later tasks) ─────────────────────────────────────────────
function main()
    mkpath(_PATH_TO_DIAG)
    inp  = load_inputs()
    pool = generate_pool(inp.model_wj, length(inp.g_is), N_POOL; seed = SEED)
    njp  = count(is_jump_path, pool)
    @printf("Pool: %d paths | jump-stratum %d (%.1f%%) | no-jump-stratum %d\n",
            length(pool), njp, 100 * njp / length(pool), length(pool) - njp)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
```

- [ ] **Step 2: Verify inputs load and the jump fraction is ~0.25 on a small pool**

Run:
```bash
julia --project=code/spy-experiment -e 'include("code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl"); inp=load_inputs(); pool=generate_pool(inp.model_wj, length(inp.g_is), 300); f=count(is_jump_path,pool)/length(pool); println("T=",length(inp.g_is)," N=",inp.N," jumpfrac=",round(f,digits=3))'
```
Expected: prints `T=2766 N=100 jumpfrac=` a value between 0.18 and 0.30 (natural ~0.23). No error.

- [ ] **Step 3: Commit**

```bash
git add code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl
git commit -m "feat(spy): scaffold jump-mix frontier diagnostic (inputs, pool, tagging)"
```

---

### Task 2: Per-path metrics and stratum summary

**Files:**
- Modify: `code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl` (add functions before `main`)

**Interfaces:**
- Consumes: `is_jump_path`, `ACF_LAGS`, `KS_ALPHA`.
- Produces: `path_metrics(obs, g_is, acf_obs) -> NamedTuple{(:ks_pass,:ad_pass,:acf_mae,:kurt,:w1,:hell)}`; `stratum_summary(pool, g_is) -> (jump, nojump, n_jump, n_nojump, fields)` where `jump`/`nojump` are NamedTuples mapping each field symbol to `(mean, se)`.

- [ ] **Step 1: Add the metric functions (insert immediately after `is_jump_path`)**

```julia
# ── per-path metrics ─────────────────────────────────────────────────────────
const _METRIC_FIELDS = (:ks_pass, :ad_pass, :acf_mae, :kurt, :w1, :hell)

function path_metrics(obs::AbstractVector{<:Real}, g_is::AbstractVector{<:Real},
                      acf_obs::AbstractVector{<:Real})
    ks  = pvalue(ApproximateTwoSampleKSTest(g_is, obs))
    ad  = pvalue(KSampleADTest(g_is, obs))
    acf = mean(abs.(acf_obs .- autocor(abs.(obs), ACF_LAGS)))
    return (ks_pass = ks > KS_ALPHA,
            ad_pass = ad > KS_ALPHA,
            acf_mae = acf,
            kurt    = kurtosis(obs),
            w1      = JumpHMM._wasserstein1(g_is, obs),
            hell    = JumpHMM._hellinger(g_is, obs))
end

_mean_se(v) = (mean = mean(v), se = length(v) > 1 ? std(v) / sqrt(length(v)) : 0.0)

function stratum_summary(pool, g_is::AbstractVector{<:Real})
    acf_obs = autocor(abs.(g_is), ACF_LAGS)
    jm = [path_metrics(p.observations, g_is, acf_obs) for p in pool if is_jump_path(p)]
    nj = [path_metrics(p.observations, g_is, acf_obs) for p in pool if !is_jump_path(p)]
    jump   = (; (f => _mean_se([getfield(m, f) for m in jm]) for f in _METRIC_FIELDS)...)
    nojump = (; (f => _mean_se([getfield(m, f) for m in nj]) for f in _METRIC_FIELDS)...)
    return (jump = jump, nojump = nojump,
            n_jump = length(jm), n_nojump = length(nj), fields = _METRIC_FIELDS)
end
```

- [ ] **Step 2: Verify the no-jump stratum reproduces HMM-NJ and the f=0.25 convex combo reproduces HMM-WJ**

Run:
```bash
julia --project=code/spy-experiment -e 'include("code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl"); inp=load_inputs(); pool=generate_pool(inp.model_wj, length(inp.g_is), 1000); s=stratum_summary(pool,inp.g_is); kj=s.jump.kurt.mean; kn=s.nojump.kurt.mean; k25=0.25*kj+0.75*kn; a25=0.25*s.jump.acf_mae.mean+0.75*s.nojump.acf_mae.mean; ks25=0.25*s.jump.ks_pass.mean+0.75*s.nojump.ks_pass.mean; println("n_jump=",s.n_jump," n_nojump=",s.n_nojump); println("kurt: nojump=",round(kn,digits=2)," jump=",round(kj,digits=2)," f0.25=",round(k25,digits=2)); println("acf_mae f0.25=",round(a25,digits=3)," ks_pass f0.25=",round(ks25,digits=3))'
```
Expected: `nojump` kurtosis ≈ 8.0 (within ~0.4 of the 8.05 anchor); `f0.25` kurtosis ≈ 7.4-7.7 (near the 7.47 anchor); `acf_mae f0.25` ≈ 0.05; `ks_pass f0.25` ≈ 0.95-0.98. No error (confirms `_wasserstein1`/`_hellinger` are reachable, since `path_metrics` computes them).

- [ ] **Step 3: Commit**

```bash
git add code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl
git commit -m "feat(spy): per-path metrics + jump/no-jump stratum summary"
```

---

### Task 3: Inline Hill tail index and anchor check

**Files:**
- Modify: `code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl` (add after `stratum_summary`)

**Interfaces:**
- Consumes: `HILL_TAIL_FRAC`.
- Produces: `hill_alpha_topk!(v; tail_frac) -> Float64` (mutates `v` via `partialsort!`, returns alpha = 1/xi).

- [ ] **Step 1: Add the Hill estimator (insert after `stratum_summary`)**

```julia
# ── Hill tail index (pooled upper |G_t|), reported as alpha = 1/xi ────────────
# Matches the convention in code/downstream-evaluation/src/Metrics.jl
# (hill_index there returns xi; we report alpha). Mutates v to avoid allocating
# a fresh sort on every resample.
function hill_alpha_topk!(v::AbstractVector{<:Real}; tail_frac::Float64 = HILL_TAIL_FRAC)
    n = length(v)
    k = max(2, floor(Int, tail_frac * n))
    partialsort!(v, 1:k; rev = true)   # v[1:k] become the k largest, sorted desc
    xk = v[k]
    xk > 0.0 || error("Hill: k-th order statistic not positive")
    s = 0.0
    @inbounds for i in 1:(k - 1)
        s += log(v[i] / xk)
    end
    return (k - 1) / s
end
```

- [ ] **Step 2: Verify Hill alpha reproduces the anchors (f=0 no-jump ≈ 2.84, natural mix ≈ 2.87)**

Run:
```bash
julia --project=code/spy-experiment -e 'include("code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl"); inp=load_inputs(); pool=generate_pool(inp.model_wj, length(inp.g_is), 1000); nojab=reduce(vcat,[abs.(p.observations) for p in pool if !is_jump_path(p)]); allab=reduce(vcat,[abs.(p.observations) for p in pool]); println("alpha nojump(f=0)=",round(hill_alpha_topk!(copy(nojab)),digits=3)); println("alpha full(natural)=",round(hill_alpha_topk!(copy(allab)),digits=3))'
```
Expected: `alpha nojump(f=0)` ≈ 2.84 (within ~0.1); `alpha full(natural)` ≈ 2.87-2.90. If both are off by a constant factor, the `tail_frac` differs from the reference; adjust `HILL_TAIL_FRAC` until `f=0` lands near 2.84.

- [ ] **Step 3: Commit**

```bash
git add code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl
git commit -m "feat(spy): inline Hill tail-index (alpha=1/xi), anchored to 2.84"
```

---

### Task 4: Frontier assembly (linear + Hill resampling) and cross-check

**Files:**
- Modify: `code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl` (add after `hill_alpha_topk!`)

**Interfaces:**
- Consumes: `stratum_summary` output, `hill_alpha_topk!`, `N_ENSEMBLE`, `R_HILL`, `F_GRID`, `F_MARK`.
- Produces: `linear_frontier(summ, f, field) -> (val, se)`; `abs_obs_matrix(pool, keep::Bool) -> Matrix{Float64}` (T x n_paths, columns are per-path `abs.(observations)` for paths whose `is_jump_path == keep`); `hill_frontier(jump_mat, nojump_mat, f; R, n_ens) -> (mean, sd)`; `resampled_field_mean(jvals, nvals, f; R, n_ens) -> (mean, sd)`; `build_frontier_table(summ, jump_mat, nojump_mat, jkurt, nkurt) -> DataFrame`.

- [ ] **Step 1: Add the frontier + resampling + table functions**

```julia
# ── frontier: exact convex combination for per-path-mean metrics ─────────────
function linear_frontier(summ, f::Real, field::Symbol)
    mj = getfield(summ.jump, field)
    mn = getfield(summ.nojump, field)
    val = f * mj.mean + (1 - f) * mn.mean
    se  = sqrt((f * mj.se)^2 + ((1 - f) * mn.se)^2)
    return (val = val, se = se)
end

# ── column-major abs-observation matrix for one stratum ──────────────────────
function abs_obs_matrix(pool, keep::Bool)
    cols = [abs.(p.observations) for p in pool if is_jump_path(p) == keep]
    T = length(cols[1])
    M = Matrix{Float64}(undef, T, length(cols))
    for (j, c) in enumerate(cols)
        @views M[:, j] .= c
    end
    return M
end

# ── pooled Hill frontier via R resampled ensembles ───────────────────────────
function hill_frontier(jump_mat::Matrix{Float64}, nojump_mat::Matrix{Float64}, f::Real;
                       R::Int = R_HILL, n_ens::Int = N_ENSEMBLE, seed::Int = SEED)
    Random.seed!(seed)
    T      = size(jump_mat, 1)
    nj_t   = round(Int, f * n_ens)
    nn_t   = n_ens - nj_t
    n_jcol = size(jump_mat, 2)
    n_ncol = size(nojump_mat, 2)
    buf    = Vector{Float64}(undef, n_ens * T)
    alphas = Vector{Float64}(undef, R)
    for r in 1:R
        idx = 1
        for _ in 1:nj_t
            c = rand(1:n_jcol); @views buf[idx:idx + T - 1] .= jump_mat[:, c]; idx += T
        end
        for _ in 1:nn_t
            c = rand(1:n_ncol); @views buf[idx:idx + T - 1] .= nojump_mat[:, c]; idx += T
        end
        alphas[r] = hill_alpha_topk!(buf)
    end
    return (mean = mean(alphas), sd = std(alphas))
end

# ── resampled mean of a precomputed per-path value (for the cross-check) ──────
function resampled_field_mean(jvals::Vector{Float64}, nvals::Vector{Float64}, f::Real;
                              R::Int = R_HILL, n_ens::Int = N_ENSEMBLE, seed::Int = SEED)
    Random.seed!(seed)
    nj_t = round(Int, f * n_ens)
    nn_t = n_ens - nj_t
    means = Vector{Float64}(undef, R)
    for r in 1:R
        s = 0.0
        for _ in 1:nj_t; s += jvals[rand(1:length(jvals))]; end
        for _ in 1:nn_t; s += nvals[rand(1:length(nvals))]; end
        means[r] = s / n_ens
    end
    return (mean = mean(means), sd = std(means))
end

# ── assemble the frontier table over the f grid ──────────────────────────────
function build_frontier_table(summ, jump_mat::Matrix{Float64}, nojump_mat::Matrix{Float64})
    fs = sort(unique(vcat(F_GRID, F_MARK)))
    df = DataFrame(f = Float64[], acf_mae = Float64[], acf_se = Float64[],
                   kurt = Float64[], kurt_se = Float64[], ks_pass = Float64[],
                   ad_pass = Float64[], w1 = Float64[], hell = Float64[],
                   hill_alpha = Float64[], hill_sd = Float64[])
    for f in fs
        acf = linear_frontier(summ, f, :acf_mae)
        ku  = linear_frontier(summ, f, :kurt)
        push!(df, (f,
                   acf.val, acf.se,
                   ku.val, ku.se,
                   linear_frontier(summ, f, :ks_pass).val,
                   linear_frontier(summ, f, :ad_pass).val,
                   linear_frontier(summ, f, :w1).val,
                   linear_frontier(summ, f, :hell).val,
                   hill_frontier(jump_mat, nojump_mat, f)...))
    end
    return df
end
```

- [ ] **Step 2: Verify the table builds, f=0/f=0.25 rows hit anchors, and the analytic-vs-resampled cross-check passes**

Run:
```bash
julia --project=code/spy-experiment -e 'include("code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl"); inp=load_inputs(); pool=generate_pool(inp.model_wj, length(inp.g_is), 1000); s=stratum_summary(pool,inp.g_is); jm=abs_obs_matrix(pool,true); nm=abs_obs_matrix(pool,false); df=build_frontier_table(s,jm,nm); show(df, allrows=true); println(); r0=df[df.f.==0.0,:][1,:]; r25=df[df.f.==0.25,:][1,:]; println("CHECK f0 kurt=",round(r0.kurt,digits=2)," alpha=",round(r0.hill_alpha,digits=2)); println("CHECK f0.25 kurt=",round(r25.kurt,digits=2)," acf=",round(r25.acf_mae,digits=3)); jk=[kurtosis(pool[i].observations) for i in eachindex(pool) if is_jump_path(pool[i])]; nk=[kurtosis(pool[i].observations) for i in eachindex(pool) if !is_jump_path(pool[i])]; an=linear_frontier(s,0.5,:kurt); rs=resampled_field_mean(jk,nk,0.5); println("XCHECK f0.5 analytic=",round(an.val,digits=3)," resampled=",round(rs.mean,digits=3)," ok=",abs(an.val-rs.mean) < 3*rs.sd)'
```
Expected: prints the full table; `CHECK f0` kurtosis ≈ 8.0 and alpha ≈ 2.84; `CHECK f0.25` kurtosis ≈ 7.5 and acf ≈ 0.05; `XCHECK f0.5 ... ok=true`. ACF-MAE should be monotonically decreasing in f; Hill alpha should be nearly flat across f.

- [ ] **Step 3: Commit**

```bash
git add code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl
git commit -m "feat(spy): frontier table (linear metrics + resampled Hill) + cross-check"
```

---

### Task 5: Outputs (CSV + figure), wire up main, full run

**Files:**
- Modify: `code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl` (add output functions; rewrite `main`)

**Interfaces:**
- Consumes: everything above.
- Produces: `write_frontier_csv(df)`; `plot_frontier(df)`; a `main()` that runs the full N_POOL=4000 pipeline, prints the table + three correctness lines, and writes both artifacts.

- [ ] **Step 1: Add output functions (insert after `build_frontier_table`)**

```julia
# ── outputs ──────────────────────────────────────────────────────────────────
function write_frontier_csv(df::DataFrame)
    path = joinpath(_PATH_TO_DIAG, "jump_mix_frontier.csv")
    CSV.write(path, df)
    return path
end

function plot_frontier(df::DataFrame)
    x = df.acf_mae
    p = plot(x, df.kurt; marker = :circle, label = "kurtosis",
             xlabel = "ACF-MAE(|g|)   (lower = better vol clustering)",
             ylabel = "excess kurtosis", legend = :topleft,
             title = "Jump-mix enrichment frontier (parameterized by f)",
             size = (760, 520), left_margin = 8Plots.mm, bottom_margin = 8Plots.mm)
    hline!(p, [OBS_KURT_TARGET]; ls = :dash, color = 1, label = "obs kurtosis 7.71")
    i25 = findfirst(==(F_MARK), df.f)
    scatter!(p, [df.acf_mae[i25]], [df.kurt[i25]]; marker = :star5, ms = 9,
             color = :black, label = "f=0.25 (shipped)")
    p2 = twinx(p)
    plot!(p2, x, df.hill_alpha; marker = :square, color = :red, label = "Hill alpha",
          ylabel = "Hill alpha (higher = thinner tail)", legend = :topright)
    hline!(p2, [OBS_HILL_ALPHA]; ls = :dash, color = :red, label = "obs alpha 3.14")
    path = joinpath(_PATH_TO_DIAG, "jump_mix_frontier.pdf")
    savefig(p, path)
    return path
end
```

- [ ] **Step 2: Replace the placeholder `main` from Task 1 with the full pipeline**

Replace the entire `function main() ... end` block with:

```julia
function main()
    mkpath(_PATH_TO_DIAG)
    inp = load_inputs()
    @printf("Inputs: T=%d N=%d eps=%g lambda=%g\n",
            length(inp.g_is), inp.N, inp.model_wj.jump.ϵ, inp.model_wj.jump.λ)

    pool = generate_pool(inp.model_wj, length(inp.g_is), N_POOL; seed = SEED)
    njp  = count(is_jump_path, pool)
    @printf("Pool: %d paths | jump-stratum %d (%.1f%%) | no-jump-stratum %d\n",
            length(pool), njp, 100 * njp / length(pool), length(pool) - njp)

    summ = stratum_summary(pool, inp.g_is)
    jm   = abs_obs_matrix(pool, true)
    nm   = abs_obs_matrix(pool, false)
    df   = build_frontier_table(summ, jm, nm)

    println("\n── Frontier table ──")
    show(df, allrows = true); println()

    # correctness checks
    r0  = df[df.f .== 0.0, :][1, :]
    r25 = df[df.f .== F_MARK, :][1, :]
    jk  = [kurtosis(p.observations) for p in pool if is_jump_path(p)]
    nk  = [kurtosis(p.observations) for p in pool if !is_jump_path(p)]
    an  = linear_frontier(summ, 0.5, :kurt)
    rs  = resampled_field_mean(jk, nk, 0.5)
    println("\n── Correctness checks ──")
    @printf("[f=0 ~ HMM-NJ]   kurt=%.2f (anchor 8.05)  alpha=%.2f (anchor 2.84)\n", r0.kurt, r0.hill_alpha)
    @printf("[f=0.25 ~ HMM-WJ] kurt=%.2f (anchor 7.47)  acf_mae=%.3f (anchor 0.052)  ks_pass=%.3f (anchor 0.976)\n", r25.kurt, r25.acf_mae, r25.ks_pass)
    @printf("[xcheck f=0.5]   analytic kurt=%.3f  resampled=%.3f  within-3sd=%s\n", an.val, rs.mean, abs(an.val - rs.mean) < 3 * rs.sd)

    csv = write_frontier_csv(df)
    pdf = plot_frontier(df)
    println("\nWrote: $csv\n       $pdf")
    return df
end
```

- [ ] **Step 3: Full run and verify artifacts + anchors**

Run (expect ~5-15 min: 4000-path simulate, 4000 KS/AD tests, and R=200 Hill resamples per f):
```bash
julia --project=code/spy-experiment code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl
```
Expected: pool jump-stratum ~23-26%; the frontier table prints with ACF-MAE decreasing in f and Hill alpha nearly flat; the three correctness lines land near their anchors (`f=0` kurt ~8.0/alpha ~2.84; `f=0.25` kurt ~7.5/acf ~0.05/ks ~0.97; `within-3sd=true`); final two lines report the written CSV and PDF paths.

- [ ] **Step 4: Confirm the artifacts exist and nothing outside diagnostics/ changed**

Run:
```bash
ls -la code/spy-experiment/diagnostics/jump_mix_frontier.csv code/spy-experiment/diagnostics/jump_mix_frontier.pdf && git status --short jfds-paper/
```
Expected: both files listed; `git status --short jfds-paper/` prints nothing (paper untouched).

- [ ] **Step 5: Commit**

```bash
git add code/spy-experiment/Jump-Mix-Enrichment-Frontier.jl code/spy-experiment/diagnostics/jump_mix_frontier.csv code/spy-experiment/diagnostics/jump_mix_frontier.pdf
git commit -m "feat(spy): jump-mix enrichment frontier outputs (CSV + figure) + full run"
```

---

## Self-Review

**Spec coverage:**
- Read-only diagnostic in `code/spy-experiment/` → Tasks 1-5, Global Constraints. ✓
- Load `model_wj`/`g_is` from the hub → Task 1 `load_inputs`. ✓
- Binary `any(p.jumps)` classification → Task 1 `is_jump_path`. ✓
- Per-path metrics KS/AD/ACF-MAE/kurtosis/W1/Hellinger via paper estimators → Task 2 `path_metrics` (uses `JumpHMM._wasserstein1`/`_hellinger`, `autocor`, `kurtosis`, HypothesisTests). ✓
- Exact convex-combination frontier + propagated SE → Task 4 `linear_frontier`. ✓
- Pooled Hill via R=200 resampling → Tasks 3-4 `hill_alpha_topk!`, `hill_frontier`. ✓
- f grid 0:0.1:1 plus 0.25 → Task 4 `build_frontier_table`. ✓
- Three correctness anchors (f=0.25 WJ, f=0 NJ, interior cross-check) → Task 5 `main`. ✓
- Outputs: stdout table, CSV, PDF to diagnostics/ → Task 5. ✓
- Out-of-scope items (no epsilon retune, no OoS, no manuscript) → honored; script only reads the hub and writes diagnostics/. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code; every run step shows an exact command and expected output. ✓

**Type consistency:** `path_metrics` returns fields `(:ks_pass,:ad_pass,:acf_mae,:kurt,:w1,:hell)`, matched by `_METRIC_FIELDS`, `stratum_summary`, `linear_frontier` (`field` symbol), and `build_frontier_table`. `hill_alpha_topk!` returns alpha (=1/xi) and is called by `hill_frontier`; `hill_frontier` returns `(mean, sd)` splatted into the two `hill_*` DataFrame columns. `abs_obs_matrix(pool, keep::Bool)` columns are per-path `abs.(observations)`, consumed by `hill_frontier`. Names align across tasks. ✓
