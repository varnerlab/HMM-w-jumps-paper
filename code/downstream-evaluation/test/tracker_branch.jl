using Test, Random, Statistics, LinearAlgebra, Distributions, StatsBase, HypothesisTests
include(joinpath(@__DIR__, "..", "src", "Composers.jl"))
include(joinpath(@__DIR__, "..", "src", "Metrics.jl"))

@testset "Tracker branch with non-unit scaling" begin
    rng = MersenneTwister(9152026)
    for T in (249, 2766), β in (-1.2, .8, 1.2), R² in (.8, .9, .99), scale in (.25, 2.0)
        # A nonzero market mean, random finite-path covariance, and a
        # non-Gaussian input distinguish this test from the published grid.
        gm = .3 .+ randn(rng, T)
        target = β^2 * var(gm) * (1 - R²) / R²
        raw = rand(rng, TDist(5), T)
        draw = 4 .+ sqrt(target / var(raw)) / scale .* raw
        g, β_eff, flag = compose_hybrid(.07, β, R², gm, draw, var(gm), var(draw))
        residual = g .- .07 .- β .* gm
        @test flag == R2_PRESERVE
        @test β_eff == β
        @test var(residual) ≈ target rtol=1e-12
        @test mean(residual) ≈ 0 atol=1e-13
        @test residual ≈ scale .* (draw .- mean(draw)) rtol=1e-12
        @test mean(g) ≈ .07 + β * mean(gm) atol=1e-13

        # OLS recovery includes the realized cross term; exact target recovery
        # is not guaranteed for independent draws on a finite path.
        c = cov(gm, residual)
        v = var(gm)
        α_hat, β_hat, R²_hat = sim_recovery(g, gm)
        @test β_hat ≈ β + c / v rtol=1e-12
        @test R²_hat ≈ (β * v + c)^2 / (v * (β^2 * v + target + 2β * c)) rtol=1e-12
        @test α_hat ≈ .07 - (β_hat - β) * mean(gm) atol=1e-13

        # A change in generator units cancels through the variance ratio.
        for factor in (.1, 10.0)
            rescaled, _, tag = compose_hybrid(.07, β, R², gm, factor .* draw,
                var(gm), factor^2 * var(draw))
            @test tag == R2_PRESERVE
            @test rescaled ≈ g rtol=1e-12
        end
    end
end

@testset "Tracker threshold and zero residual budget" begin
    gm = collect(range(-2., 3.; length=249))
    draw = sin.(gm)
    g, β_eff, flag = compose_hybrid(.07, 1.2, 1., gm, draw, var(gm), var(draw))
    @test flag == R2_PRESERVE
    @test β_eff == 1.2
    @test g == .07 .+ 1.2 .* gm
    @test sim_recovery(g, gm)[3] ≈ 1
    @test compose_hybrid(.07, 1.2, .8, gm, draw, var(gm), var(draw))[3] == R2_PRESERVE
    @test compose_hybrid(.07, 1.2, prevfloat(.8), gm, draw, var(gm), var(draw))[3] != R2_PRESERVE
end
