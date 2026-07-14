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
const ACF_LAGS        = collect(1:252)   # matches the paper's reported ACF-MAE (_L_ACF = 252)
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

# ── per-path metrics ─────────────────────────────────────────────────────────
# ACF-MAE is handled separately (via ensemble-mean |g| autocorrelation curves
# over ACF_LAGS lags), because the paper reports the MAE of the ensemble-averaged
# autocorrelation over 252 lags, which is non-linear in the mix fraction. The
# metrics below are per-path means and combine linearly in the mix fraction.
const _METRIC_FIELDS = (:ks_pass, :ad_pass, :kurt, :w1, :hell)

function path_metrics(obs::AbstractVector{<:Real}, g_is::AbstractVector{<:Real})
    ks = pvalue(ApproximateTwoSampleKSTest(g_is, obs))
    ad = pvalue(KSampleADTest(g_is, obs))
    return (ks_pass = ks > KS_ALPHA,
            ad_pass = ad > KS_ALPHA,
            kurt    = kurtosis(obs),
            w1      = JumpHMM._wasserstein1(g_is, obs),
            hell    = JumpHMM._hellinger(g_is, obs))
end

_mean_se(v) = (mean = mean(v), se = length(v) > 1 ? std(v) / sqrt(length(v)) : 0.0)

# Ensemble-mean |g| autocorrelation curve over a set of paths.
_mean_acf_curve(paths) = mean([autocor(abs.(p.observations), ACF_LAGS) for p in paths])

function stratum_summary(pool, g_is::AbstractVector{<:Real})
    jump_paths   = [p for p in pool if is_jump_path(p)]
    nojump_paths = [p for p in pool if !is_jump_path(p)]
    jm = [path_metrics(p.observations, g_is) for p in jump_paths]
    nj = [path_metrics(p.observations, g_is) for p in nojump_paths]
    jump   = (; (f => _mean_se([getfield(m, f) for m in jm]) for f in _METRIC_FIELDS)...)
    nojump = (; (f => _mean_se([getfield(m, f) for m in nj]) for f in _METRIC_FIELDS)...)
    return (jump = jump, nojump = nojump,
            acf_obs    = autocor(abs.(g_is), ACF_LAGS),
            acf_jump   = _mean_acf_curve(jump_paths),
            acf_nojump = _mean_acf_curve(nojump_paths),
            n_jump = length(jm), n_nojump = length(nj), fields = _METRIC_FIELDS)
end

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
