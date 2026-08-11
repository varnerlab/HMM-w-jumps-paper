using Test
using Random
using Statistics
using LinearAlgebra
using StatsBase
using HypothesisTests

include(joinpath(@__DIR__, "..", "src", "Composers.jl"))
include(joinpath(@__DIR__, "..", "src", "Metrics.jl"))

@testset "full-return generator centering" begin
    ε̃ = [8.0, 9.5, 11.0, 12.5, 14.0]
    ε̃ᶜ = center_generator_draw(ε̃)

    @test mean(ε̃ᶜ) ≈ 0.0 atol = 1e-14
    @test var(ε̃ᶜ) ≈ var(ε̃) rtol = 1e-14
    @test center_generator_draw(ε̃ .+ 100.0) ≈ ε̃ᶜ
    @test_throws ArgumentError center_generator_draw(Float64[])
end

@testset "naive composition does not double count generator location" begin
    α = 0.25
    β = 1.4
    gm = [-2.0, -0.5, 0.5, 1.0, 3.0]
    ε̃ = [8.0, 9.5, 11.0, 12.5, 14.0]

    g = compose_naive(α, β, gm, ε̃)
    g_shifted = compose_naive(α, β, gm, ε̃ .+ 100.0)

    @test mean(g .- α .- β .* gm) ≈ 0.0 atol = 1e-14
    @test g_shifted ≈ g
    @test_throws AssertionError compose_naive(α, β, gm[1:4], ε̃)
end

@testset "hybrid branches use a centered residual" begin
    α = 0.25
    gm = [-2.0, -0.5, 0.5, 1.0, 3.0]
    ε̃ = [8.0, 9.5, 11.0, 12.5, 14.0]
    σ²_m = var(gm)
    σ²_g = var(ε̃)

    cases = [
        (0.5, 0.30, HYBRID),
        (3.0, 0.30, HYBRID_CLIPPED),
        (0.7, 0.90, R2_PRESERVE),
    ]

    for (β, R², expected_flag) in cases
        g, β_eff, flag = compose_hybrid(α, β, R², gm, ε̃, σ²_m, σ²_g)
        g_shifted, β_eff_shifted, flag_shifted = compose_hybrid(
            α, β, R², gm, ε̃ .+ 100.0, σ²_m, σ²_g)

        @test flag == expected_flag
        @test flag_shifted == flag
        @test β_eff_shifted ≈ β_eff
        @test g_shifted ≈ g
        @test mean(g .- α .- β_eff .* gm) ≈ 0.0 atol = 1e-14
    end
end

@testset "intercept recovery under the composition assumptions" begin
    α = 0.25
    β = 0.6
    gm = [-2.0, -1.0, 0.0, 1.0, 2.0]
    # The centered pattern is orthogonal to gm, matching the derivation's
    # zero-cross-covariance assumption while retaining a large raw mean.
    ε̃ = 10.0 .+ [1.0, -2.0, 2.0, -2.0, 1.0]
    g, β_eff, _ = compose_hybrid(α, β, 0.30, gm, ε̃,
                                     var(gm), var(ε̃))
    α̂, β̂, _ = sim_recovery(g, gm)

    @test α̂ ≈ α atol = 1e-14
    @test β̂ ≈ β_eff atol = 1e-14
end
