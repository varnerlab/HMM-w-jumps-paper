# Canonical training results, with resumable per-asset output and provenance.
# Generation follows run_composer_experiment's order and random streams. Only
# deterministic scoring is threaded; the AD sample-size normalization is reused.
using SHA

const TRAINING_METHODS = ["naive", "gaussian", "hybrid", "residual_jumphmm", "block_bootstrap", "garch_t"]
const TRAINING_FITS = ["marginals.jld2", "marginals-residuals.jld2", "garch-t-models.jld2"]
training_hash(path) = open(io -> bytes2hex(sha256(io)), path)

function training_provenance(root, cfg)
    paths = ["Project.toml", "Manifest.toml", "config.toml", "src/TrainingSetup.jl",
        "src/TrainingResults.jl", "src/Composers.jl", "src/Metrics.jl", "src/Pipeline.jl",
        "src/GARCHFit.jl", "scripts/03-Compose-And-Evaluate.jl",
        "data/universe.jld2", "data/sim-calibration.jld2"]
    hashes = Dict(p => training_hash(joinpath(root,p)) for p in paths)
    packages = Dict{String,Any}()
    for package in (JumpHMM, ARCHModels, HypothesisTests)
        directory = dirname(pathof(package))
        files = Dict{String,String}()
        for (parent, _, names) in walkdir(directory), name in sort(names)
            endswith(name, ".jl") || continue
            path = joinpath(parent,name)
            files[relpath(path,directory)] = training_hash(path)
        end
        packages[string(nameof(package))] = files
    end
    fits = Dict(p => training_hash(resolve_data_artifact(p)) for p in TRAINING_FITS)
    provenance = Dict{String,Any}("schema_version"=>1, "julia_version"=>string(VERSION),
        "config"=>cfg, "source_input_sha256"=>hashes, "fitted_cache_sha256"=>fits,
        "package_source_sha256"=>packages,
        "protocol"=>"Observed training SPY; native residual means; six methods; stationary no-jump HMMs; production seed schedule")
    buffer = IOBuffer()
    TOML.print(buffer, provenance; sorted=true)
    provenance["signature"] = bytes2hex(sha256(take!(buffer)))
    return provenance
end

"""Reject changed sources/inputs; published results can be read without local fitted caches."""
function validate_training_provenance(meta, root; require_fits=false)
    get(meta,"schema_version",0) == 1 || error("Legacy training results: rerun script 03")
    meta["config"] == TOML.parsefile(joinpath(root,"config.toml")) || error("Training configuration changed")
    for (p, hash) in meta["source_input_sha256"]
        training_hash(joinpath(root,p)) == hash || error("Training source/input changed: $p")
    end
    for package in (JumpHMM, ARCHModels, HypothesisTests)
        directory = dirname(pathof(package))
        for (p, hash) in meta["package_source_sha256"][string(nameof(package))]
            training_hash(joinpath(directory,p)) == hash || error("Training package source changed: $(nameof(package))/$p")
        end
    end
    for (p, hash) in meta["fitted_cache_sha256"]
        path = find_data_artifact(p)
        path === nothing && !require_fits && continue
        path !== nothing || error("Missing training fit: $p")
        training_hash(path) == hash || error("Training fitted cache changed: $p")
    end
    return true
end

"""Validate every asset/method/replication key, eligibility, setting, and numeric score."""
function validate_training_rows(r, calibration, eligible, cfg; complete=true)
    isempty(r) && error("Empty training results")
    expected = Set(String.(calibration.ticker))
    found = Set(String.(r.ticker))
    (complete ? found == expected : issubset(found,expected)) || error("Training asset set mismatch")
    Set(r.composer) == Set(TRAINING_METHODS) || error("Training results must contain all six methods")
    n_paths = cfg["simulation"]["n_paths"]
    nrow(unique(r[:,[:ticker,:composer,:rep]])) == nrow(r) || error("Duplicate training path key")
    for ticker in found
        selected = r[r.ticker .== ticker,:]
        methods = ticker in eligible ? TRAINING_METHODS : TRAINING_METHODS[1:5]
        Set(selected.composer) == Set(methods) || error("Training eligibility mismatch: $ticker")
        for method in methods
            sort(selected.rep[selected.composer .== method]) == collect(1:n_paths) ||
                error("Incomplete training replications: $ticker/$method")
        end
    end
    for (name,value) in ((:seed,cfg["simulation"]["seed"]),
        (:f,cfg["hybrid"]["idiosyncratic_floor"]),
        (:r2_threshold,cfg["hybrid"]["r2_preserve_threshold"]),(:gm_factor,1.0))
        all(==(value),r[!,name]) || error("Training setting mismatch: $name")
    end
    for name in (:beta_eff,:α_hat,:β_hat,:R²_hat,:ks_p,:ad_p,:w1,:hill_up,:kurt,:var_g)
        all(isfinite,r[!,name]) || error("Nonfinite training score: $name")
    end
    all(x -> 0 <= x <= 1,r.ks_p) && all(x -> 0 <= x <= 1,r.ad_p) || error("Invalid training p-value")
    all(>(0),r.var_g) && all(>=(0),r.w1) || error("Invalid variance or distance")
    return true
end

function training_summary(results, calibration)
    r = copy(results)
    index = Dict(row.ticker=>row for row in eachrow(calibration))
    r.dα = [abs(row.α_hat-index[row.ticker].alpha) for row in eachrow(r)]
    r.dβ = [abs(row.β_hat-index[row.ticker].beta) for row in eachrow(r)]
    r.dR² = [abs(row.R²_hat-index[row.ticker].r2_real) for row in eachrow(r)]
    summary = combine(groupby(r,:composer),
        :ticker => (t->length(unique(t))) => :n_tickers, nrow => :n_paths,
        :dα => median => :alpha_error, :dβ => median => :beta_error,
        :dR² => median => :r2_error,
        :ks_p => (p->100mean(p .> .05)) => :ks_pct,
        :ad_p => (p->100mean(p .> .05)) => :ad_pct,
        :w1 => median => :w1, :kurt => median => :kurt, :hill_up => median => :hill)
    return summary[[only(findall(==(m),summary.composer)) for m in TRAINING_METHODS],:]
end

function training_scorer(gm)
    # This is the same equal-length AD computation used by the checked jump and
    # centering experiments. The expensive normalization depends only on lengths.
    sd = KSampleADTest(gm,gm).σ
    function score(g, observed, market)
        length(g) == length(observed) == length(gm) || error("AD normalization length mismatch")
        pooled = vcat(g,observed)
        _,statistic = HypothesisTests.adkvals(unique(sort(pooled)),length(pooled),(g,observed))
        test = KSampleADTest(2,length(pooled),sd,statistic,true,0,pooled,[length(g),length(observed)])
        a,b,r2 = sim_recovery(g,market)
        return (α_hat=a, β_hat=b, R²_hat=r2, ks_p=ks_pvalue(g,observed),
            ad_p=pvalue(test), w1=wasserstein1(g,observed),
            hill_up=hill_index(abs.(g)), kurt=excess_kurtosis(g), var_g=var(g))
    end
    return score
end

"""Generate one training asset in production order; parallelize deterministic scoring only."""
function training_asset(i, cal, observed, gm, full_model, residual_model, garch, cfg, score)
    seed,n = Int(cfg["simulation"]["seed"]),Int(cfg["simulation"]["n_paths"])
    f,threshold = cfg["hybrid"]["idiosyncratic_floor"],cfg["hybrid"]["r2_preserve_threshold"]
    T = length(gm)
    full = simulate(full_model,T; n_paths=n,seed=seed+i).paths
    residual = simulate(residual_model,T; n_paths=n,seed=seed+i+1_000_000).paths
    methods = haskey(garch,cal.ticker) ? TRAINING_METHODS : TRAINING_METHODS[1:5]
    draws = Matrix{Vector{Float64}}(undef,n,length(methods))
    betas = fill(cal.beta,n,length(methods))
    flags = repeat(reshape(["NAIVE","GAUSSIAN_SIM","HYBRID","RESIDUAL_JUMPHMM","BLOCK_BOOTSTRAP","GARCH_T"][1:length(methods)],1,:),n,1)
    real_residual = observed .- cal.alpha .- cal.beta .* gm
    for rep in 1:n
        x = Float64.(full[rep].observations)
        draws[rep,1] = compose_naive(cal.alpha,cal.beta,gm,x)
        draws[rep,2] = compose_gaussian_sim(cal.alpha,cal.beta,cal.sigma_eps_real,gm,Random.default_rng())
        g,b,flag = compose_hybrid(cal.alpha,cal.beta,cal.r2_real,gm,x,var(gm),var(x);
            f=f,R²_threshold=threshold)
        draws[rep,3],betas[rep,3],flags[rep,3] = g,b,string(flag)
        draws[rep,4] = compose_residual_jumphmm(cal.alpha,cal.beta,gm,Float64.(residual[rep].observations))
        rng = MersenneTwister(seed+i*1_000_000+rep*1_000+1)
        draws[rep,5] = compose_block_bootstrap(cal.alpha,cal.beta,gm,real_residual,
            Float64(cfg["bootstrap"]["mean_block_length"]),rng)
        if length(methods)==6
            draws[rep,6] = compose_garch_t(cal.alpha,cal.beta,gm,simulate_garch_residual(garch[cal.ticker],T))
        end
    end
    records = Vector{NamedTuple}(undef,n*length(methods))
    Threads.@threads for rep in 1:n
        for (j,method) in enumerate(methods)
            records[(rep-1)*length(methods)+j] = merge(
                (ticker=cal.ticker,composer=method,rep=rep,beta_eff=betas[rep,j],flag=flags[rep,j],
                 seed=seed,f=f,r2_threshold=threshold,gm_factor=1.0),score(draws[rep,j],observed,gm))
        end
    end
    return DataFrame(records)
end

function run_canonical_training(cfg; root=_ROOT, output=joinpath(root,"data"), resume=true)
    mkpath(output)
    checkpoint_dir = joinpath(root,"results","training-canonical")
    mkpath(checkpoint_dir)
    provenance = training_provenance(root,cfg)
    universe = load(resolve_data_artifact("universe.jld2"))
    calibration = load(resolve_data_artifact("sim-calibration.jld2"),"calibration")
    full = load(resolve_data_artifact("marginals.jld2"),"marginals")
    residual = load(resolve_data_artifact("marginals-residuals.jld2"),"marginals")
    G,index = universe["growth_rates"],Dict(t=>i for (i,t) in enumerate(universe["tickers"]))
    gm = G[:,index[cfg["universe"]["market_ticker"]]]
    garch = load_validated_garch_models(resolve_data_artifact("garch-t-models.jld2");
        trial_length=length(gm),seed=Int(cfg["simulation"]["seed"]))
    all(t->haskey(full,t)&&haskey(residual,t),calibration.ticker) || error("Missing fitted HMM")
    all(m->m.jump.ϵ==0,values(full)) && all(m->m.jump.ϵ==0,values(residual)) || error("Canonical training expects no-jump models")
    eligible = sort(collect(keys(garch)))
    score = training_scorer(gm)
    BLAS.set_num_threads(1)
    blocks = DataFrame[]
    started = time()
    for (i,cal) in enumerate(eachrow(calibration))
        file = joinpath(checkpoint_dir,cal.ticker*".jld2")
        if resume && isfile(file)
            saved = load(file)
            saved["signature"] == provenance["signature"] || error("Stale training checkpoint: $file; use --restart")
            block = saved["results"]
            Set(block.ticker) == Set([cal.ticker]) || error("Training checkpoint ticker mismatch")
        else
            block = training_asset(i,cal,G[:,index[cal.ticker]],gm,full[cal.ticker],residual[cal.ticker],garch,cfg,score)
            temporary = file*".tmp"
            jldsave(temporary; results=block,signature=provenance["signature"])
            mv(temporary,file;force=true)
        end
        # Per-asset checks allow five methods for a GARCH exclusion; the complete
        # six-method universe is checked again before installing canonical files.
        expected_methods = cal.ticker in eligible ? TRAINING_METHODS : TRAINING_METHODS[1:5]
        nrow(block)==length(expected_methods)*cfg["simulation"]["n_paths"] || error("Incomplete checkpoint")
        Set(block.composer)==Set(expected_methods) || error("Checkpoint method mismatch")
        push!(blocks,block)
        if i==1 || i%25==0 || i==nrow(calibration)
            @printf("Training %d/%d assets; %.1f minutes\n",i,nrow(calibration),(time()-started)/60)
            flush(stdout)
        end
    end
    results = vcat(blocks...)
    validate_training_rows(results,calibration,Set(eligible),cfg)
    validate_training_provenance(provenance,root;require_fits=true)
    summary = training_summary(results,calibration)
    metadata = merge(provenance,Dict("completed_utc"=>string(now(UTC))*"Z",
        "training_observations"=>length(gm),"garch_eligible"=>eligible,
        "rows"=>nrow(results),"threads"=>Threads.nthreads()))
    cache = joinpath(output,"results.jld2")
    jldsave(cache*".tmp"; results,config=cfg,metadata)
    CSV.write(joinpath(output,"results.csv.tmp"),results)
    CSV.write(joinpath(output,"results-summary.csv.tmp"),summary)
    metadata["artifact_sha256"] = Dict("results.jld2"=>training_hash(cache*".tmp"),
        "results.csv"=>training_hash(joinpath(output,"results.csv.tmp")),
        "results-summary.csv"=>training_hash(joinpath(output,"results-summary.csv.tmp")))
    for name in ("results.jld2","results.csv","results-summary.csv")
        mv(joinpath(output,name*".tmp"),joinpath(output,name);force=true)
    end
    open(joinpath(output,"results-metadata.toml.tmp"),"w") do io
        TOML.print(io,metadata;sorted=true)
    end
    mv(joinpath(output,"results-metadata.toml.tmp"),joinpath(output,"results-metadata.toml");force=true)
    @info "Canonical training results complete" rows=nrow(results) assets=nrow(calibration) garch_assets=length(eligible)
    return results
end

function load_canonical_training(root=_ROOT)
    data = joinpath(root,"data")
    metadata_path = joinpath(data,"results-metadata.toml")
    isfile(metadata_path) || error("Unverified training cache: run scripts/03-Compose-And-Evaluate.jl")
    meta = TOML.parsefile(metadata_path)
    validate_training_provenance(meta,root)
    # The full CSV is a regenerable convenience. The JLD2 and compact summary
    # are required; every artifact present must match its recorded fingerprint.
    for (name,hash) in meta["artifact_sha256"]
        path = joinpath(data,name)
        name=="results.csv" && !isfile(path) && continue
        training_hash(path)==hash || error("Training artifact changed: $name")
    end
    saved = load(joinpath(data,"results.jld2"))
    saved["metadata"]["signature"]==meta["signature"] || error("Training cache/metadata signature mismatch")
    calibration = load(resolve_data_artifact("sim-calibration.jld2"),"calibration")
    validate_training_rows(saved["results"],calibration,Set(meta["garch_eligible"]),meta["config"])
    return saved["results"],calibration,meta
end
