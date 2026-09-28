using Test, Statistics, Distributions
include(joinpath(@__DIR__, "..", "src", "VaRBacktest.jl"))

# Independent high-precision binomial deviance, with the equivalent normal tail.
function reference_kupiec(n, T, α)
    lr = setprecision(BigFloat, 256) do
        p = 1 - BigFloat(α)
        x = BigFloat(n) / T
        a = n == 0 ? big"0" : n * log(x / p)
        b = n == T ? big"0" : (T - n) * log((1 - x) / (1 - p))
        max(big"0", 2 * (a + b))
    end
    return 2ccdf(Normal(), sqrt(Float64(lr)))
end

@testset "Kupiec boundary likelihood" begin
    @test kupiec_pvalue(0, 100, .99) ≈ 0.156258399534847 rtol=1e-12
    @test kupiec_pvalue(0, 249, .99) ≈ 0.025273221507228 rtol=1e-11
    @test kupiec_pvalue(0, 100, .99) > .05
    @test kupiec_pvalue(0, 249, .99) < .05
    # The old rounded-count branch incorrectly returned exactly one here.
    @test 0 < kupiec_pvalue(0, 10, .99) < 1
    @test 0 < kupiec_pvalue(1, 1, .6) < 1
    for T in (1, 10, 100, 249, 2766), α in (.01, .5, .95, .99, .999)
        for n in unique((0, 1, T ÷ 2, T - 1, T))
            actual = kupiec_pvalue(n, T, α)
            @test isfinite(actual) && 0 ≤ actual ≤ 1
            @test actual ≈ reference_kupiec(n, T, α) rtol=2e-10 atol=1e-13
        end
    end
    for α in (nextfloat(0.0), eps(), prevfloat(1.0)), n in (0, 1, 99, 100)
        @test isfinite(kupiec_pvalue(n, 100, α))
    end
end

@testset "Kupiec interior and input validation" begin
    @test kupiec_pvalue(25, 100, .75) == 1
    @test kupiec_pvalue(5, 100, .95) ≈ 1 atol=1e-7
    for n in 1:248, α in (.95, .99)
        @test kupiec_pvalue(n, 249, α) ≈ reference_kupiec(n, 249, α) rtol=2e-10 atol=1e-13
    end
    for (n, T) in ((0, 0), (0, -1), (-1, 100), (101, 100))
        @test_throws ArgumentError kupiec_pvalue(n, T, .99)
    end
    for α in (NaN, Inf, -Inf, -.1, 0, 1, 1.1)
        @test_throws ArgumentError kupiec_pvalue(0, 100, α)
    end
end

@testset "Backtest propagates corrected boundary results" begin
    sample = collect(-100.0:100.0)
    no_breaches = var_backtest(sample, zeros(100), .99)
    @test no_breaches.var == var_threshold(sample, .99)
    @test no_breaches.n_breach == 0
    @test no_breaches.rate == 0
    @test no_breaches.kupiec_p ≈ reference_kupiec(0, 100, .99)
    all_breaches = var_backtest(sample, fill(-1000.0, 10), .95)
    @test all_breaches.n_breach == 10
    @test all_breaches.rate == 1
    @test all_breaches.kupiec_p ≈ reference_kupiec(10, 10, .95)
    @test_throws ArgumentError var_backtest(sample, Float64[], .99)
end
