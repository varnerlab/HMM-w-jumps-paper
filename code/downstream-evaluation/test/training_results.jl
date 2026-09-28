# Check canonical generation against the unmodified production loop and reject
# incomplete, duplicate, or stale inputs before they can regenerate paper tables.
using Test
include(joinpath(@__DIR__,"..","src","TrainingSetup.jl"))

@testset "Canonical training generation and guards" begin
    cfg = load_config()
    cfg["simulation"]["n_paths"] = 2
    universe = load(resolve_data_artifact("universe.jld2"))
    calibration = load(resolve_data_artifact("sim-calibration.jld2"),"calibration")
    full = load(resolve_data_artifact("marginals.jld2"),"marginals")
    residual = load(resolve_data_artifact("marginals-residuals.jld2"),"marginals")
    garch = load_validated_garch_models(resolve_data_artifact("garch-t-models.jld2");trial_length=2766)
    index = Dict(t=>i for (i,t) in enumerate(universe["tickers"]))
    gm = universe["growth_rates"][:,index["SPY"]]
    fast = training_scorer(gm)
    # Test the complete metrics, including AD ties and shifted/heavy-tail inputs.
    rng = MersenneTwister(5)
    for (g,observed) in ((gm,gm), (round.(gm;digits=1),gm),
        (rand(rng,TDist(5),length(gm)).+0.2,universe["growth_rates"][:,index["AAPL"]]))
        a,b = fast(g,observed,gm),score_asset(g,observed,gm)
        @test keys(a)==keys(b)
        @test all(isapprox(a[k],b[k];atol=1e-12,rtol=1e-10) for k in keys(a))
    end
    @test_throws ErrorException fast(gm[1:end-1],gm,gm)

    blocks = DataFrame[]
    for ticker in ("AAPL","ALB","QQQ","F","T")
        i = only(findall(==(ticker),calibration.ticker))
        cal = calibration[i,:]
        observed = universe["growth_rates"][:,index[ticker]]
        actual = training_asset(i,cal,observed,gm,full[ticker],residual[ticker],garch,cfg,fast)
        # Replay the original serial production calculation with the same seeds,
        # including the shared default RNG used by Gaussian and GARCH draws.
        draws = simulate(full[ticker],length(gm);n_paths=2,seed=1234+i).paths
        residual_draws = simulate(residual[ticker],length(gm);n_paths=2,seed=1234+i+1_000_000).paths
        for rep in 1:2
            x = Float64.(draws[rep].observations)
            expected = Dict{String,Vector{Float64}}()
            expected["naive"] = compose_naive(cal.alpha,cal.beta,gm,x)
            expected["gaussian"] = compose_gaussian_sim(cal.alpha,cal.beta,cal.sigma_eps_real,gm,Random.default_rng())
            expected["hybrid"] = first(compose_hybrid(cal.alpha,cal.beta,cal.r2_real,gm,x,var(gm),var(x)))
            expected["residual_jumphmm"] = compose_residual_jumphmm(cal.alpha,cal.beta,gm,Float64.(residual_draws[rep].observations))
            expected["block_bootstrap"] = compose_block_bootstrap(cal.alpha,cal.beta,gm,
                observed.-cal.alpha.-cal.beta.*gm,50.0,MersenneTwister(1234+i*1_000_000+rep*1_000+1))
            if haskey(garch,ticker)
                expected["garch_t"] = compose_garch_t(cal.alpha,cal.beta,gm,simulate_garch_residual(garch[ticker],length(gm)))
            end
            for (method,g) in expected
                reference = score_asset(g,observed,gm)
                row = only(eachrow(filter(r->r.composer==method&&r.rep==rep,actual)))
                @test all(isapprox(row[k],reference[k];atol=1e-12,rtol=1e-10) for k in keys(reference))
            end
        end
        push!(blocks,actual)
    end
    r = vcat(blocks...)
    cal = filter(row->row.ticker in r.ticker,calibration)
    @test validate_training_rows(r,cal,Set(keys(garch)),cfg)
    @test_throws ErrorException validate_training_rows(r[2:end,:],cal,Set(keys(garch)),cfg)
    @test_throws ErrorException validate_training_rows(vcat(r,r[1:1,:]),cal,Set(keys(garch)),cfg)
    @test_throws ErrorException validate_training_rows(filter(row->row.composer!="garch_t",r),cal,Set(keys(garch)),cfg)
    @test_throws ErrorException validate_training_rows(r,cal,Set{String}(),cfg)
    bad = copy(r); bad.ks_p[1]=NaN
    @test_throws ErrorException validate_training_rows(bad,cal,Set(keys(garch)),cfg)
    @test_throws ErrorException validate_training_provenance(Dict(),_ROOT)
    provenance = training_provenance(_ROOT,load_config())
    @test validate_training_provenance(provenance,_ROOT;require_fits=true)
    bad_provenance = deepcopy(provenance)
    bad_provenance["source_input_sha256"]["src/Composers.jl"]="wrong"
    @test_throws ErrorException validate_training_provenance(bad_provenance,_ROOT)
    bad_provenance = deepcopy(provenance)
    bad_provenance["config"]["simulation"]["seed"]=999
    @test_throws ErrorException validate_training_provenance(bad_provenance,_ROOT)
end
