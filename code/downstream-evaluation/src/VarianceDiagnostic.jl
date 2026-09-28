# Recover generator denominators from the canonical training random streams.
# Keep this diagnostic separate from the frozen six-method experiment so its
# verified scores and provenance remain valid.

const VARIANCE_DIAGNOSTIC_FILES = ["scripts/15-Variance-Diagnostic.jl", "src/VarianceDiagnostic.jl"]

function variance_diagnostic_summary(paths)
    summary = combine(groupby(paths, [:ticker, :composer, :branch]),
        :beta_cal => first => :beta_cal,
        :ks_p => (p -> mean(p .> 0.05)) => :ks_pass,
        :ratio_generator => median => :ratio_generator,
        :ratio_observed => median => :ratio_observed,
        :ratio_target => median => :ratio_target,
        :reference_generator => median => :reference_generator,
        :relative_cross_term => (x -> median(abs.(x))) => :median_absolute_target_error,
        :relative_cross_term => (x -> quantile(abs.(x),0.95)) => :p95_absolute_target_error)
    sort!(summary, [:ticker, :composer])
    return summary
end

function run_variance_diagnostic(root=_ROOT)
    r, calibration, training = load_canonical_training(root)
    validate_training_provenance(training,root;require_fits=true)
    cfg = training["config"]
    universe = load(resolve_data_artifact("universe.jld2"))
    models = load(resolve_data_artifact("marginals.jld2"),"marginals")
    index = Dict(t=>i for (i,t) in enumerate(universe["tickers"]))
    G = universe["growth_rates"]
    gm = G[:,index[cfg["universe"]["market_ticker"]]]
    vm = var(gm)
    n,seed = Int(cfg["simulation"]["n_paths"]),Int(cfg["simulation"]["seed"])
    f,threshold = cfg["hybrid"]["idiosyncratic_floor"],cfg["hybrid"]["r2_preserve_threshold"]
    cached = Dict((row.ticker,row.composer,row.rep)=>row for row in eachrow(r)
                  if row.composer in ("naive","hybrid"))
    records = NamedTuple[]
    max_cache_error = 0.0
    max_identity_error = 0.0
    for (i,cal) in enumerate(eachrow(calibration))
        # All full-return paths are generated before the other methods consume
        # randomness in training_asset. Replaying this call recovers them exactly.
        models[cal.ticker].jump.ϵ == 0 || error("Expected a no-jump training model")
        draws = simulate(models[cal.ticker],length(gm);n_paths=n,seed=seed+i).paths
        observed_variance = var(G[:,index[cal.ticker]])
        for rep in 1:n
            x = Float64.(draws[rep].observations)
            vx,cross = var(x),cov(gm,x)
            isfinite(vx) && vx>0 || error("Invalid generator variance")
            naive = compose_naive(cal.alpha,cal.beta,gm,x)
            hybrid,beta_eff,flag = compose_hybrid(cal.alpha,cal.beta,cal.r2_real,gm,x,vm,vx;
                f=f,R²_threshold=threshold)
            # Recover the scale actually used by the composer from its residual.
            residual = hybrid .- cal.alpha .- beta_eff .* gm
            scale = sqrt(var(residual)/vx)
            tracker_target = cal.r2_real >= 1-1e-12 ? cal.beta^2*vm : cal.beta^2*vm/cal.r2_real
            hybrid_target = flag==R2_PRESERVE ? tracker_target : vx
            branch = string(flag)
            for (method,g,b,s,target) in (("naive",naive,cal.beta,1.0,vx+cal.beta^2*vm),
                                         ("hybrid",hybrid,beta_eff,scale,hybrid_target))
                saved = cached[(cal.ticker,method,rep)]
                vg = var(g)
                max_cache_error = max(max_cache_error,abs(vg-saved.var_g))
                vg==saved.var_g || error("Canonical path variance differs: $(cal.ticker)/$method/$rep")
                b==saved.beta_eff || error("Canonical loading differs")
                saved.flag==(method=="naive" ? "NAIVE" : branch) || error("Canonical branch differs")
                # This finite-sample identity retains the covariance omitted by
                # the variance budget. It checks every path, not just a mean.
                predicted = target+2*b*s*cross
                identity_error = abs(vg-predicted)/target
                max_identity_error = max(max_identity_error,identity_error)
                identity_error < 1e-11 || error("Variance identity failed")
                push!(records,(ticker=cal.ticker,composer=method,rep=rep,branch=branch,
                    beta_cal=cal.beta,beta_eff=b,r2_cal=cal.r2_real,scale=s,
                    variance_generator=vx,variance_observed=observed_variance,
                    variance_market=vm,covariance_market_generator=cross,
                    variance_composed=vg,variance_target=target,ks_p=saved.ks_p,
                    ratio_generator=vg/vx,ratio_observed=vg/observed_variance,
                    ratio_target=vg/target,reference_generator=target/vx,
                    relative_cross_term=2*b*s*cross/target))
            end
        end
        if i==1 || i%50==0 || i==nrow(calibration)
            println("Variance replay $i/$(nrow(calibration)) assets")
            flush(stdout)
        end
    end
    paths = DataFrame(records)
    nrow(paths)==2*n*nrow(calibration) || error("Incomplete variance replay")
    summary = variance_diagnostic_summary(paths)
    output = joinpath(root,"results","variance-diagnostic")
    mkpath(output)
    CSV.write(joinpath(output,"paired-paths.csv"),paths)
    CSV.write(joinpath(output,"ticker-summary.csv"),summary)
    metadata = Dict("schema_version"=>1,"completed_utc"=>string(now(UTC))*"Z",
        "julia_version"=>string(VERSION),"training_signature"=>training["signature"],
        "training_cache_sha256"=>training["artifact_sha256"]["results.jld2"],
        "source_sha256"=>Dict(p=>training_hash(joinpath(root,p)) for p in VARIANCE_DIAGNOSTIC_FILES),
        "artifact_sha256"=>Dict(p=>training_hash(joinpath(output,p)) for p in ("paired-paths.csv","ticker-summary.csv")),
        "paths"=>nrow(paths),"assets"=>nrow(calibration),"replications"=>n,"observations"=>length(gm),
        "seed"=>seed,"market_variance"=>vm,"annualized_market_variance"=>vm*cfg["hmm"]["dt"],
        "maximum_canonical_variance_difference"=>max_cache_error,
        "maximum_relative_variance_identity_error"=>max_identity_error,
        "smoothing_bandwidth"=>0.15,"smoothing_grid_points"=>80,
        "protocol"=>"Replay original full-return draws; observed training SPY; paired naive/hybrid; per-path generator denominators; tracker targets identified separately")
    open(joinpath(output,"metadata.toml"),"w") do io
        TOML.print(io,metadata;sorted=true)
    end
    println("Verified $(nrow(paths)) canonical composed variances; maximum difference $max_cache_error")
    return paths,summary,metadata
end

function load_variance_diagnostic(training;root=_ROOT)
    output = joinpath(root,"results","variance-diagnostic")
    file = joinpath(output,"metadata.toml")
    isfile(file) || error("Run scripts/15-Variance-Diagnostic.jl before making Figure 4")
    meta = TOML.parsefile(file)
    meta["schema_version"]==1 || error("Unsupported variance diagnostic")
    meta["training_signature"]==training["signature"] || error("Stale variance diagnostic")
    meta["training_cache_sha256"]==training["artifact_sha256"]["results.jld2"] || error("Training cache mismatch")
    for (path,hash) in meta["source_sha256"]
        training_hash(joinpath(root,path))==hash || error("Variance diagnostic source changed: $path")
    end
    for (path,hash) in meta["artifact_sha256"]
        training_hash(joinpath(output,path))==hash || error("Variance diagnostic data changed: $path")
    end
    paths = CSV.read(joinpath(output,"paired-paths.csv"),DataFrame;types=Dict(:ticker=>String))
    summary = CSV.read(joinpath(output,"ticker-summary.csv"),DataFrame;types=Dict(:ticker=>String))
    expected = variance_diagnostic_summary(paths)
    names(summary)==names(expected) && size(summary)==size(expected) || error("Variance summary schema mismatch")
    for name in names(expected)
        if eltype(expected[!,name]) <: Number
            all(isapprox.(summary[!,name],expected[!,name];atol=1e-12,rtol=1e-12)) || error("Variance summary mismatch: $name")
        else
            summary[!,name]==expected[!,name] || error("Variance summary mismatch: $name")
        end
    end
    return paths,summary,meta
end
