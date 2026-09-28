using Test, Statistics, Random, DataFrames, CSV
include(joinpath(@__DIR__,"..","src","VaRBacktest.jl"))
include(joinpath(@__DIR__,"..","src","VaREnsemble.jl"))

@testset "Pooled finite-horizon VaR" begin
    # Pool returns after path construction; do not average per-path quantiles.
    paths = hcat(collect(-249.0:-1.0), collect(1.0:249.0))
    q = pooled_var_threshold(paths,0.99)
    @test q == -quantile(vec(paths),0.01)
    @test q != mean(var_threshold(paths[:,j],0.99) for j in axes(paths,2))
    @test pooled_var_threshold(reverse(paths;dims=2),0.99) == q
    @test pooled_var_threshold(2paths,0.99) == 2q
    @test_throws ArgumentError pooled_var_threshold(fill(NaN,249,2),0.99)
    @test_throws ArgumentError pooled_var_threshold(zeros(249,0),0.99)
    # Fixed thresholds are scored only on the independent validation matrix.
    check = hcat(fill(-1000.0,249), fill(1000.0,249))
    summary = summarize_var_calibration(Dict("hybrid"=>paths),
        Dict("hybrid"=>check),"TEST",[1,2])
    @test all(summary.validation_rate .== 0.5)
    @test all(summary.horizon .== 249)
    @test summary.threshold[end] == q
    @test all(summary.validation_mcse .== 0.5)
    altered = summarize_var_calibration(Dict("hybrid"=>paths),
        Dict("hybrid"=>-abs.(check)),"TEST",[1,2])
    @test altered.threshold == summary.threshold
    @test all(altered.validation_rate .== 1)
    seeds = [var_seed(9142026,p,s,a,r) for p in 1:2 for s in 1:6
             for a in (0,1,423) for r in (1,100,5000)]
    @test length(unique(seeds)) == length(seeds)
    for ticker in ("F","T")
        saved = IOBuffer("ticker,threshold\n$ticker,0.03\n")
        restored = CSV.read(saved,DataFrame;types=Dict(:ticker=>String))
        @test only(restored.ticker) == ticker
    end
end
