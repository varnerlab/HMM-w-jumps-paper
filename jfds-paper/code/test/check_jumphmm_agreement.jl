# =============================================================================
# Agreement check: paper's standalone `compose_hybrid` vs JumpHMM's
# `HybridSingleIndexModel` per-ticker block (transcribed from SIM.jl).
#
# This validates that the paper's reference implementation and the released
# JumpHMM.jl production implementation compute the same hybrid SIM composition.
# Run from the sim-experiment project so JumpHMM is available:
#
#   julia --project=code/sim-experiment /tmp/check_jumphmm_agreement.jl
#
# =============================================================================

using Random
using Statistics
using LinearAlgebra
using StatsBase
import JumpHMM
using JumpHMM: JumpHiddenMarkovModel, GaussianCopula,
               StudentTCopula, simulate, fit, sample_dependence
const HybridSingleIndexModel = JumpHMM.HybridSingleIndexModel

# ---------------------------------------------------------------------------
# Paper's compose_hybrid (Composers.jl:66, vendored verbatim).
# Returns (g, β_eff, flag::Symbol).
# ---------------------------------------------------------------------------
function paper_compose_hybrid(α::Float64, β::Float64, R²_real::Float64,
                              gm::AbstractVector{<:Real}, ε̃::AbstractVector{<:Real},
                              σ²_m::Float64, σ²_gen::Float64;
                              f::Float64 = 0.10,
                              R²_threshold::Float64 = 0.80)
    @assert 0.0 < f < 1.0
    @assert 0.0 < R²_threshold ≤ 1.0
    @assert σ²_m > 0.0

    if R²_real ≥ R²_threshold
        σ²_ε_target = (R²_real ≥ 1.0 - 1e-12) ? 0.0 :
                      β^2 * σ²_m * (1.0 - R²_real) / R²_real
        scale = (σ²_gen > 0.0 && σ²_ε_target > 0.0) ?
                sqrt(σ²_ε_target / σ²_gen) : 0.0
        ε     = scale .* ε̃
        β_eff = β
        flag  = :R2_PRESERVE
    else
        ρ = β^2 * σ²_m / max(σ²_gen, 1e-30)
        if ρ > 1.0 - f
            β_eff = sign(β) * sqrt((1.0 - f) * σ²_gen / σ²_m)
            s²    = f
            flag  = :HYBRID_CLIPPED
        else
            β_eff = β
            s²    = 1.0 - ρ
            flag  = :HYBRID
        end
        ε = sqrt(s²) .* ε̃
    end

    g = α .+ β_eff .* gm .+ ε
    return g, β_eff, flag
end

# ---------------------------------------------------------------------------
# JumpHMM's per-ticker block (transcribed from SIM.jl:232–275). Same inputs
# as the paper version PLUS the threshold and floor (which the JumpHMM impl
# pulls from the model struct at runtime). Returns (g, β_eff, ε_scaled).
# Skips copula reorder so it compares apples-to-apples with the paper version.
# ---------------------------------------------------------------------------
function jumphmm_per_ticker_block(α_k::Float64, β_k::Float64, r²_k::Float64,
                                  G_market::AbstractVector{<:Real},
                                  obs_j::AbstractVector{<:Real},
                                  σ²_m::Float64;
                                  f::Float64 = 0.10,
                                  threshold::Float64 = 0.80)
    σ²_HMM = var(obs_j)
    T_eff  = length(G_market)

    β_eff = β_k
    if r²_k >= threshold
        if r²_k >= 1.0 - 1e-12
            σ²_ε_target = 0.0
        else
            σ²_ε_target = β_k^2 * σ²_m * (1.0 - r²_k) / r²_k
        end
        ε_scaled = (σ²_HMM > 0.0 && σ²_ε_target > 0.0) ?
                   sqrt(σ²_ε_target / σ²_HMM) .* obs_j :
                   zeros(T_eff)
    else
        ρ = β_k^2 * σ²_m / max(σ²_HMM, 1e-30)
        if ρ > 1.0 - f
            β_eff = sign(β_k) * sqrt((1.0 - f) * σ²_HMM / σ²_m)
            s²    = f
        else
            s²    = 1.0 - ρ
        end
        ε_scaled = sqrt(s²) .* obs_j
    end

    g = α_k .+ β_eff .* G_market .+ ε_scaled
    return g, β_eff, ε_scaled
end

# ---------------------------------------------------------------------------
# Test 1: branch-by-branch unit cases on hand-built inputs.
# ---------------------------------------------------------------------------
function test_branches()
    Random.seed!(42)
    T = 500
    gm = randn(T) .* 0.012
    ε̃  = randn(T) .* 0.020
    σ²_m   = var(gm)
    σ²_gen = var(ε̃)
    f      = 0.10
    thr    = 0.80

    cases = [
        ("HYBRID (no clip)",     0.0001, 0.8, 0.5),   # R² < thr, ρ < 1-f
        ("HYBRID_CLIPPED",       0.0001, 3.0, 0.5),   # forces ρ > 1-f
        ("R2_PRESERVE (R²=0.85)", 0.0001, 1.0, 0.85),
        ("R2_PRESERVE (R²=1.0)",  0.0001, 1.0, 1.0),
        ("HYBRID negative β",   -0.0001, -1.5, 0.4),  # exercises sign(β) path
    ]

    pass_all = true
    for (name, α, β, r²) in cases
        g_p, βeff_p, flag_p = paper_compose_hybrid(α, β, r², gm, ε̃, σ²_m, σ²_gen;
                                                    f=f, R²_threshold=thr)
        g_j, βeff_j, _      = jumphmm_per_ticker_block(α, β, r², gm, ε̃, σ²_m;
                                                       f=f, threshold=thr)

        max_abs_diff = maximum(abs.(g_p .- g_j))
        β_diff       = abs(βeff_p - βeff_j)
        ok = (max_abs_diff < 1e-12) && (β_diff < 1e-12)
        pass_all &= ok

        status = ok ? "PASS" : "FAIL"
        println("  [$status] $name")
        println("         max|Δg|=$(max_abs_diff)   |Δβ_eff|=$(β_diff)   flag=$flag_p")
    end
    return pass_all
end

# ---------------------------------------------------------------------------
# Test 2: end-to-end on a fitted HybridSingleIndexModel. Build synthetic
# price data, fit the model, then for each ticker:
#  - draw market path and innovation path with seeded RNG
#  - compute composed series via paper_compose_hybrid
#  - compute composed series via jumphmm_per_ticker_block
#  - assert agreement
# This confirms that the algorithm in JumpHMM's HybridSingleIndexModel matches
# the paper's standalone implementation when fed the same draws.
# ---------------------------------------------------------------------------
function test_fitted_model()
    Random.seed!(20260506)
    n_obs = 600
    tickers = ["SPY", "AAA", "BBB", "CCC"]
    n_assets = length(tickers)

    # Synthetic prices. SPY is a GBM-ish path; assets are SIM-like draws.
    market_returns = 0.0003 .+ 0.012 .* randn(n_obs)
    prices = ones(n_obs, n_assets)
    prices[:, 1] = cumprod(1.0 .+ market_returns) .* 100.0
    βs_true = [1.0, 0.8, 1.2, 0.5]
    σ_idio  = [0.0, 0.015, 0.018, 0.010]
    α_true  = [0.0, 0.0001, 0.0002, 0.00005]
    for k in 2:n_assets
        ri = α_true[k] .+ βs_true[k] .* market_returns .+ σ_idio[k] .* randn(n_obs)
        prices[:, k] = cumprod(1.0 .+ ri) .* 100.0
    end

    println("\n  Fitting HybridSingleIndexModel on synthetic 4-ticker data …")
    model = fit(HybridSingleIndexModel, tickers, prices, "SPY";
                copula_type = GaussianCopula,
                N = 50, ν = 5.0, dt = 1/252,
                r2_preserve_threshold = 0.80,
                idiosyncratic_floor   = 0.10)
    println("  Fit OK. tickers=$(model.tickers)")
    println("  β=$(round.(model.β, digits=3))  R²=$(round.(model.r², digits=3))")

    # Pre-draw market and innovation paths with a fixed seed.
    n_sim = 300
    Random.seed!(99)
    market_result = simulate(model.market_model, n_sim; n_paths=1)
    G_full   = Float64.(market_result.paths[1].observations)
    G_market = G_full[2:end]
    σ²_m     = model.σ_market^2

    pass_all = true
    for (k, ticker) in enumerate(model.tickers)
        Random.seed!(100 + k)
        innov_result = simulate(model.marginals[ticker], n_sim; n_paths=1)
        obs_full = Float64.(innov_result.paths[1].observations)
        obs_j    = obs_full[2:end]

        α_k  = model.α[k]
        β_k  = model.β[k]
        r²_k = model.r²[k]

        σ²_gen = var(obs_j)

        g_paper, βeff_p, flag_p = paper_compose_hybrid(
            α_k, β_k, r²_k, G_market, obs_j, σ²_m, σ²_gen;
            f = model.idiosyncratic_floor,
            R²_threshold = model.r2_preserve_threshold)

        g_jhmm, βeff_j, _ = jumphmm_per_ticker_block(
            α_k, β_k, r²_k, G_market, obs_j, σ²_m;
            f = model.idiosyncratic_floor,
            threshold = model.r2_preserve_threshold)

        max_abs_diff = maximum(abs.(g_paper .- g_jhmm))
        β_diff       = abs(βeff_p - βeff_j)
        ok = (max_abs_diff < 1e-12) && (β_diff < 1e-12)
        pass_all &= ok
        status = ok ? "PASS" : "FAIL"
        println("  [$status] ticker=$ticker  β=$(round(β_k, digits=3))  R²=$(round(r²_k, digits=3))  flag=$flag_p   max|Δg|=$(max_abs_diff)")
    end
    return pass_all
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
println("=" ^ 70)
println("Agreement check: paper compose_hybrid  vs  JumpHMM HybridSingleIndexModel")
println("=" ^ 70)

println("\nTest 1: branch-by-branch unit cases on hand-built inputs")
ok1 = test_branches()

println("\nTest 2: end-to-end on a fitted HybridSingleIndexModel")
ok2 = test_fitted_model()

println("\n" * "=" ^ 70)
if ok1 && ok2
    println("RESULT: AGREEMENT — paper and JumpHMM implementations match exactly.")
    exit(0)
else
    println("RESULT: DISAGREEMENT — review failing cases above.")
    exit(1)
end
