# Mechanism checks for the experiment, independent of the expensive universe run.
include(joinpath(@__DIR__,"..","Include.jl"))
include(joinpath(_PATH_TO_SRC,"JumpAblation.jl"))
using Test

@testset "Frozen models and jump switches" begin
    settings = TOML.parsefile(joinpath(_ROOT,"jump-ablation.toml"))
    original = load(resolve_data_artifact("marginals.jld2"))["marginals"]["SPY"]
    off = ablation_model(original,false,settings)
    on = ablation_model(original,true,settings)
    @test original.jump.ϵ == 0.0
    @test on.jump.ϵ == 1e-4
    @test on.jump.λ == 90.0
    @test on.transition === original.transition
    @test on.emissions === original.emissions
    @test on.stationary === original.stationary
    a = simulate(original,249;n_paths=3,seed=1234)
    b = simulate(off,249;n_paths=3,seed=1234)
    @test all(a.paths[i].observations==b.paths[i].observations for i in 1:3)
    @test all(!any(p.jumps) for p in b.paths)
    forced_settings = merge(settings,Dict("epsilon"=>1.0))
    forced = simulate(ablation_model(original,true,forced_settings),249;n_paths=2,seed=12)
    @test all(!p.jumps[1] && all(p.jumps[2:end]) for p in forced.paths)
end

@testset "AD normalization reuse agrees with the reference implementation" begin
    rng = MersenneTwister(8)
    for n in (20,249,2766), discrete in (false,true)
        a = discrete ? Float64.(rand(rng,-3:3,n)) : randn(rng,n)
        b = discrete ? Float64.(rand(rng,-3:3,n)) : randn(rng,n) .+ 0.1
        ref = (g=b,ad_sd=KSampleADTest(b,b).σ)
        @test ablation_ad_pvalue(a,ref) ≈ ad_pvalue(a,b) atol=1e-12
    end
end

@testset "Composition accounting with paired draws" begin
    gm = [-2.0,-1.0,0.0,1.0,2.0]
    x = [1.0,-2.0,2.0,-2.0,1.0]
    @test cov(gm,x) == 0.0
    naive = compose_naive(0.1,0.5,gm,x)
    hybrid,beta,flag = compose_hybrid(0.1,0.5,0.2,gm,x,var(gm),var(x))
    @test var(naive) ≈ var(x)+0.5^2*var(gm)
    @test var(hybrid) ≈ var(x)
    @test sim_recovery(hybrid,gm)[2] ≈ 0.5
    @test mean(hybrid) ≈ 0.1
    @test flag == HYBRID
    # Nonzero sample cross-covariance must remain in the realized variance.
    y = x + 0.2gm
    g,b,f = compose_hybrid(0.1,0.5,0.2,gm,y,var(gm),var(y))
    scale = sqrt(1-0.5^2*var(gm)/var(y))
    @test var(g) ≈ var(y)+2*0.5*scale*cov(gm,y)
    clipped,b,f = compose_hybrid(0.1,3.0,0.2,gm,x,var(gm),var(x))
    @test f == HYBRID_CLIPPED
    @test var(clipped) ≈ var(x)
    tracker,b,f = compose_hybrid(0.1,0.5,0.9,gm,x,var(gm),var(x))
    @test f == R2_PRESERVE
    @test sim_recovery(tracker,gm)[3] ≈ 0.9
end

@testset "Temporal metric target and lag windows" begin
    rng = MersenneTwister(4)
    g = randn(rng,249)
    gm = randn(rng,249)
    a,b,r2 = sim_recovery(g,gm)
    ref = ablation_reference(g,[25,60])
    m = ablation_metrics(g,ref,gm,var(g),(beta=b,r2_real=r2),b,NAIVE)
    @test m.abs_acf_mae25 == 0
    @test m.abs_acf_mae60 == 0
    @test m.raw_acf_mae25 == 0
    @test m.w1 == 0
    @test m.variance_ratio_observed == 1
end
