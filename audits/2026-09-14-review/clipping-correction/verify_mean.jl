# Check R9 identities against the unchanged production composer and stress helper.
using Statistics, Random, Test, TOML, SHA, Dates

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const COMPOSER = joinpath(ROOT, "code/downstream-evaluation/src/Composers.jl")
const MARKET = joinpath(ROOT, "code/downstream-evaluation/src/SyntheticMarket.jl")
include(COMPOSER)
include(MARKET)

function check_means()
    records = Dict{String,Any}[]
    # These four-point paths have zero sample covariance and nonzero variances.
    # Changing the market level preserves that covariance and every variance.
    market_shape = [-1.0, 1.0, -1.0, 1.0]
    draw = [9.0, 9.0, 5.0, 5.0]
    α = 0.1
    for β in (-3.0, 0.0, 1.0, 3.0), μ in (-0.2, 0.0, 0.2), r2 in (0.2, 0.9)
        gm = market_shape .+ μ
        g, effective, flag = compose_hybrid(α, β, r2, gm, draw, var(gm), var(draw))
        original_mean = α + β * mean(gm)
        predicted_mean = α + effective * mean(gm)
        predicted_shift = (effective - β) * mean(gm)
        @test mean(g) ≈ predicted_mean atol=2e-14
        @test mean(g)-original_mean ≈ predicted_shift atol=2e-14
        fitted_beta = cov(gm,g)/var(gm)
        fitted_alpha = mean(g)-fitted_beta*mean(gm)
        @test fitted_beta ≈ effective atol=2e-14
        @test fitted_alpha ≈ α atol=2e-14
        if flag == HYBRID_CLIPPED
            @test abs(effective) < abs(β)
            @test var(g) ≈ var(draw) atol=2e-14
            @test var(g .- α .- effective .* gm) ≈ 0.1*var(draw) atol=2e-14
            if μ != 0
                @test abs(mean(g)-original_mean) > 0.1
            end
        else
            @test effective == β
            @test mean(g) ≈ original_mean atol=2e-14
        end
        # A different supplied market mean can change the training-mean target
        # even without clipping. This identity separates the two contributions.
        training_market_mean = 0.15
        training_asset_mean = α + β*training_market_mean
        shift_from_training = β*(mean(gm)-training_market_mean)+predicted_shift
        @test mean(g)-training_asset_mean ≈ shift_from_training atol=2e-14
        push!(records,Dict("beta"=>β,"market_mean"=>mean(gm),"r2"=>r2,
            "branch"=>string(flag),"effective_beta"=>effective,
            "composed_mean"=>mean(g),"calibrated_linear_mean"=>original_mean,
            "mean_shift"=>mean(g)-original_mean,"predicted_shift"=>predicted_shift,
            "identity_error"=>abs(mean(g)-predicted_mean),
            "training_mean_identity_error"=>abs(mean(g)-training_asset_mean-shift_from_training)))
    end
    # At the exact floor boundary the composer retains beta. The limiting
    # variances are passed explicitly so the branch comparison is exact.
    _, effective, flag = compose_hybrid(α,1.5,0.2,market_shape,draw,1.0,3.0;f=0.25)
    @test flag == HYBRID
    @test effective == 1.5
    stress = Dict{String,Any}[]
    gm = market_shape .+ 0.2
    for γ in (1.0,2.0,3.0)
        stressed = scale_market(gm,γ)
        @test mean(stressed) ≈ mean(gm) atol=2e-14
        @test var(stressed) ≈ γ^2*var(gm) atol=2e-14
        g,effective,flag = compose_hybrid(α,1.0,0.2,stressed,draw,var(stressed),var(draw))
        shift = mean(g)-(α+mean(gm))
        @test shift ≈ (effective-1.0)*mean(gm) atol=2e-14
        push!(stress,Dict("gamma"=>γ,"market_mean"=>mean(stressed),
            "market_variance_ratio"=>var(stressed)/var(gm),"branch"=>string(flag),
            "effective_beta"=>effective,"mean_shift"=>shift))
    end
    # Replay the original audit's random-number schedule for its quoted example.
    rng=MersenneTwister(20260915)
    T=249
    gm=randn(rng,T)
    for _ in 1:1000
        randn(rng,T) # full-return draw in the original centering probe
        randn(rng,T) # Gaussian residual comparator
    end
    gm .+= 0.2
    draw=2randn(rng,T)
    g,effective,flag=compose_hybrid(0.1,3.0,0.2,gm,draw,var(gm),var(draw))
    shift=mean(g)-(0.1+3mean(gm))
    @test flag == HYBRID_CLIPPED
    @test shift ≈ (effective-3)*mean(gm) atol=2e-14
    @test shift ≈ -0.181985112 atol=5e-10
    report=Dict("completed_utc"=>string(now(UTC))*"Z","julia_version"=>string(VERSION),
        "cases"=>records,"stress_cases"=>stress,"cases_checked"=>length(records),
        "clipped_cases"=>count(x->x["branch"]=="HYBRID_CLIPPED",records),
        "maximum_mean_identity_error"=>maximum(x["identity_error"] for x in records),
        "maximum_training_mean_identity_error"=>maximum(x["training_mean_identity_error"] for x in records),
        "exact_floor_boundary_retains_loading"=>true,
        "original_audit_example"=>Dict("mean_shift"=>shift,"predicted_shift"=>(effective-3)*mean(gm),
            "effective_beta"=>effective,"market_mean"=>mean(gm)),
        "source_sha256"=>Dict(relpath(p,ROOT)=>bytes2hex(sha256(read(p))) for p in (COMPOSER,MARKET,@__FILE__)))
    open(joinpath(@__DIR__,"mean-checks.toml"),"w") do io
        TOML.print(io,report;sorted=true)
    end
    println("Verified $(length(records)) mean cases, the exact floor boundary, three stress factors, and the original audit example.")
    println("Original audit mean shift: ",shift)
end

@testset "R9 mean identities with retained intercept" begin
    check_means()
end
