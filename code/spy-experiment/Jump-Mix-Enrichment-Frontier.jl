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
