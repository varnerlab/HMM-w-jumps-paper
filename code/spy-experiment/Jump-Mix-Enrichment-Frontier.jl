# =============================================================================
# Jump-Mix-Enrichment-Frontier.jl
#
# Read-only diagnostic. Sweeps the HMM-WJ ensemble's jump-path fraction f from
# 0 (no-jump only) to 1 (jump only) and reports the stylized-fact tradeoff:
# volatility clustering (ACF-MAE of |g|) vs marginal fidelity (kurtosis, Hill
# tail index, KS/AD pass rates, W1, Hellinger). Per-path-mean metrics use the
# exact convex-combination frontier M(f)=f*M_jump+(1-f)*M_nojump; the pooled
# Hill index uses R resampled ensembles. Writes its table and CSV to
# code/spy-experiment/diagnostics/ and the cited figure to
# jfds-paper/figs/main/Fig04-Jump-Mix-Frontier.pdf.
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
const _PATH_TO_JFDS_FIG = joinpath(_ROOT, "..", "..", "jfds-paper", "figs",
                                    "main", "Fig04-Jump-Mix-Frontier.pdf")
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

# ── frontier: exact convex combination for per-path-mean metrics ─────────────
function linear_frontier(summ, f::Real, field::Symbol)
    mj = getfield(summ.jump, field)
    mn = getfield(summ.nojump, field)
    val = f * mj.mean + (1 - f) * mn.mean
    se  = sqrt((f * mj.se)^2 + ((1 - f) * mn.se)^2)
    return (val = val, se = se)
end

# ── ACF-MAE frontier: MAE of the linearly combined stratum-mean ACF curves ───
acf_mae_frontier(summ, f::Real) =
    mean(abs.(f .* summ.acf_jump .+ (1 - f) .* summ.acf_nojump .- summ.acf_obs))

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
function build_frontier_table(summ, jump_mat::Matrix{Float64}, nojump_mat::Matrix{Float64};
                              R_hill::Int = R_HILL)
    fs = sort(unique(vcat(F_GRID, F_MARK)))
    df = DataFrame(f = Float64[], acf_mae = Float64[], kurt = Float64[],
                   kurt_se = Float64[], ks_pass = Float64[], ad_pass = Float64[],
                   w1 = Float64[], hell = Float64[], hill_alpha = Float64[],
                   hill_sd = Float64[])
    for f in fs
        ku = linear_frontier(summ, f, :kurt)
        hf = hill_frontier(jump_mat, nojump_mat, f; R = R_hill)
        push!(df, (f,
                   acf_mae_frontier(summ, f),
                   ku.val, ku.se,
                   linear_frontier(summ, f, :ks_pass).val,
                   linear_frontier(summ, f, :ad_pass).val,
                   linear_frontier(summ, f, :w1).val,
                   linear_frontier(summ, f, :hell).val,
                   hf.mean, hf.sd))
    end
    return df
end

# ── outputs ──────────────────────────────────────────────────────────────────
function write_frontier_csv(df::DataFrame)
    path = joinpath(_PATH_TO_DIAG, "jump_mix_frontier.csv")
    CSV.write(path, df)
    return path
end

# The Hill index is reported as xi (the raw upper-tail estimator, = 1/alpha),
# matching the manuscript's Hill convention rather than the tail exponent alpha.
# Layout and style match Fig4-Replot-SPY.jl (the paper's model-comparison
# figure): one row of lettered panels, grey97 background, house colors
# (navy #1d3557 = HMM-WJ family, red #e63946 dashed = observed SPY).
const _COL_SIM = "#1d3557"
const _COL_OBS = "#e63946"
const _COL_INK = "#3d3d3d"

const _BASESTYLE = (bg                       = "grey97",
                    background_color_outside = "white",
                    framestyle               = :box,
                    fg_legend                = :transparent,
                    xguidefontsize           = 15,
                    yguidefontsize           = 15,
                    titlefontsize            = 15,
                    xtickfontsize            = 11,
                    ytickfontsize            = 11,
                    bottom_margin            = 12Plots.mm,
                    left_margin              = 14Plots.mm)

function plot_frontier(df::DataFrame;
                       outpath::AbstractString = _PATH_TO_JFDS_FIG)
    x   = df.acf_mae
    xi  = 1.0 ./ df.hill_alpha
    oxi = 1.0 / OBS_HILL_ALPHA
    i25 = findfirst(==(F_MARK), df.f)
    i0  = findfirst(==(0.0), df.f)
    i1  = findfirst(==(1.0), df.f)
    xl  = (minimum(x) - 0.0012, maximum(x) + 0.0014)

    pa = plot(; legend = :topleft, legendfontsize = 10, _BASESTYLE...)
    plot!(pa, x, df.kurt; marker = :circle, ms = 8, msw = 0, c = _COL_SIM,
          lw = 3.5, label = "Jump-mix frontier")
    hline!(pa, [OBS_KURT_TARGET]; lw = 3.5, ls = :dash, c = _COL_OBS,
           label = "SPY Observed")
    scatter!(pa, [x[i25]], [df.kurt[i25]]; marker = :star5, ms = 16,
             mc = :black, msw = 0, label = "f = 0.25 (HMM-WJ)")
    annotate!(pa, [
        (x[i0] + 0.0006, df.kurt[i0] + 0.13, text("f = 0 (HMM-NJ)", 12, _COL_INK, :right)),
        (x[i1] + 0.0006, df.kurt[i1], text("f = 1 (all-jump)", 12, _COL_INK, :left)),
    ])
    xlabel!(pa, "ACF-MAE of |Gₜ| (252 lags)")
    ylabel!(pa, "Excess Kurtosis")
    xlims!(pa, xl); ylims!(pa, (6.45, 8.20)); yticks!(pa, 6.5:0.5:8.0)
    title!(pa, "(a) Distribution Body")

    pb = plot(; legend = false, _BASESTYLE...)
    plot!(pb, x, xi; marker = :circle, ms = 8, msw = 0, c = _COL_SIM, lw = 3.5)
    hline!(pb, [oxi]; lw = 3.5, ls = :dash, c = _COL_OBS)
    scatter!(pb, [x[i25]], [xi[i25]]; marker = :star5, ms = 16, mc = :black, msw = 0)
    xlabel!(pb, "ACF-MAE of |Gₜ| (252 lags)")
    ylabel!(pb, "Hill Upper-Tail Index ξ")
    xlims!(pb, xl); ylims!(pb, (0.300, 0.365)); yticks!(pb, 0.30:0.02:0.36)
    title!(pb, "(b) Extreme Upper Tail")

    p = plot(pa, pb; layout = (1, 2), size = (1200, 560), dpi = 150,
             right_margin = 6Plots.mm)
    savefig(p, outpath)
    return outpath
end

# Rebuild the figure from the saved CSV without rerunning the sweep:
#   julia --project=. -e 'include("Jump-Mix-Enrichment-Frontier.jl"); replot_from_csv()'
function replot_from_csv(; csvpath::AbstractString = joinpath(_PATH_TO_DIAG, "jump_mix_frontier.csv"),
                         outpath::AbstractString = _PATH_TO_JFDS_FIG)
    return plot_frontier(CSV.read(csvpath, DataFrame); outpath = outpath)
end

# ── main ─────────────────────────────────────────────────────────────────────
function main()
    mkpath(_PATH_TO_DIAG)
    mkpath(dirname(_PATH_TO_JFDS_FIG))
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

    r0  = df[df.f .== 0.0, :][1, :]
    r25 = df[df.f .== F_MARK, :][1, :]
    jk  = [kurtosis(p.observations) for p in pool if is_jump_path(p)]
    nk  = [kurtosis(p.observations) for p in pool if !is_jump_path(p)]
    an  = linear_frontier(summ, 0.5, :kurt)
    rs  = resampled_field_mean(jk, nk, 0.5)
    println("\n── Correctness checks ──")
    @printf("[f=0 ~ HMM-NJ]    kurt=%.2f (anchor 8.05)  alpha=%.2f (anchor 2.84)  acf=%.4f\n",
            r0.kurt, r0.hill_alpha, r0.acf_mae)
    @printf("[f=0.25 ~ HMM-WJ] kurt=%.2f (anchor 7.47)  acf=%.4f (anchor 0.052)  ks=%.3f (anchor 0.976)\n",
            r25.kurt, r25.acf_mae, r25.ks_pass)
    @printf("[xcheck f=0.5]    analytic kurt=%.3f  resampled=%.3f  within-3sd=%s\n",
            an.val, rs.mean, abs(an.val - rs.mean) < 3 * rs.sd)

    csv = write_frontier_csv(df)
    pdf = plot_frontier(df)
    println("\nWrote: $csv\n       $pdf")
    return df
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
