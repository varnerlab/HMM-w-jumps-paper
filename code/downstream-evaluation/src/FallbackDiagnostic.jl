# Audit the frozen full-return fits and isolate the effect of replacing the
# global scale in populated, nearly constant states with their empirical scale.
# This module never modifies the production models, package, or result caches.

function fallback_inventory(models, observations)
    states_out = NamedTuple[]
    for ticker in sort(collect(keys(models)))
        model,x = models[ticker],observations[ticker]
        states = JumpHMM.assign_states(model.partition,x)
        rebuilt = JumpHMM.fit_emissions(states,x,model.partition.N;ν=model.ν)
        JumpHMM.estimate_transition(states,model.partition.N)==model.transition ||
            error("Transition reconstruction differs: $ticker")
        outgoing = zeros(Int,model.partition.N)
        for k in states[1:end-1]
            outgoing[k] += 1
        end
        for k in 1:model.partition.N
            e = model.emissions[k]
            all(getfield(e,f)==getfield(rebuilt[k],f) for f in fieldnames(typeof(e))) ||
                error("Emission reconstruction differs: $ticker/$k")
            values = x[states .== k]
            empirical_scale = length(values)>1 ? std(values) : missing
            reason = e.n_obs<2 ? "sparse" : empirical_scale<1e-12 ? "near_constant" : "none"
            (reason!="none")==e.is_fallback || error("Fallback flag differs")
            if outgoing[k]==0
                all(==(1/model.partition.N),model.transition[k,:]) || error("Zero-count row is not uniform")
            end
            push!(states_out,(ticker=ticker,state=k,observations=e.n_obs,
                distinct_observations=length(unique(values)),reason=reason,
                empirical_mean=isempty(values) ? missing : mean(values),empirical_scale=empirical_scale,
                fitted_mean=e.μ,fitted_scale=e.σ,nu=e.ν,global_mean=mean(x),global_scale=std(x),
                occupancy=e.n_obs/length(x),stationary_mass=model.stationary[k],
                outgoing_count=outgoing[k],uniform_transition=outgoing[k]==0))
        end
    end
    return DataFrame(states_out)
end

function fallback_alternative(model, inventory)
    emissions = copy(model.emissions)
    for row in eachrow(inventory[inventory.reason .== "near_constant",:])
        e = emissions[row.state]
        emissions[row.state] = JumpHMM.StudentTEmission(e.μ,row.empirical_scale,e.ν,e.n_obs,e.is_fallback)
    end
    return JumpHiddenMarkovModel(model.partition,copy(model.transition),emissions,
        copy(model.stationary),model.jump,model.ν,model.rf,model.dt)
end

function fallback_mixture_variance(model)
    location = sum(model.stationary[k]*e.μ for (k,e) in enumerate(model.emissions))
    return sum(model.stationary[k]*((e.μ-location)^2+e.σ^2*e.ν/(e.ν-2))
               for (k,e) in enumerate(model.emissions))
end

function fallback_asset_summary(inventory, models)
    records = NamedTuple[]
    for ticker in sort(unique(inventory.ticker))
        selected = inventory[inventory.ticker .== ticker,:]
        affected = selected[selected.reason .!= "none",:]
        nearly_constant = selected[selected.reason .== "near_constant",:]
        before = fallback_mixture_variance(models[ticker])
        after = fallback_mixture_variance(fallback_alternative(models[ticker],selected))
        push!(records,(ticker=ticker,fallback_states=nrow(affected),
            near_constant_states=nrow(nearly_constant),
            near_constant_observations=sum(nearly_constant.observations),
            empty_states=count(==(0),selected.observations),
            singleton_states=count(==(1),selected.observations),
            uniform_transition_rows=count(selected.uniform_transition),
            fallback_stationary_mass=sum(affected.stationary_mass),
            near_constant_stationary_mass=sum(nearly_constant.stationary_mass),
            sparse_stationary_mass=sum(selected.stationary_mass[selected.reason .== "sparse"]),
            fitted_mixture_variance=before,alternative_mixture_variance=after,
            relative_mixture_variance_change=(after-before)/before))
    end
    return DataFrame(records)
end

function fallback_score(g,observed,gm,score,reference_acf)
    metrics = score(g,observed,gm)
    return merge(metrics,(ks_pass=Float64(metrics.ks_p>.05),ad_pass=Float64(metrics.ad_p>.05),
        variance_ratio_observed=metrics.var_g/var(observed),
        acf_mae25=mean(abs.(autocor(abs.(g),1:25).-reference_acf))))
end

function fallback_sensitivity_summary(paths)
    records = NamedTuple[]
    for method in ("uncomposed","naive","hybrid"), metric in
        (:ks_pass,:ad_pass,:w1,:variance_ratio_observed,:acf_mae25)
        fitted = sort(paths[(paths.method .== method).&(paths.treatment .== "as_fitted"),:],[:ticker,:rep])
        alternative = sort(paths[(paths.method .== method).&(paths.treatment .== "empirical_scale"),:],[:ticker,:rep])
        fitted[:,[:ticker,:rep]]==alternative[:,[:ticker,:rep]] || error("Sensitivity pairing differs")
        multiplier = metric in (:ks_pass,:ad_pass) ? 100.0 : 1.0
        differences = multiplier.*(alternative[!,metric].-fitted[!,metric])
        paired = DataFrame(rep=fitted.rep,difference=differences)
        replication_means = combine(groupby(paired,:rep),:difference=>mean=>:difference)
        push!(records,(method=method,metric=string(metric),assets=length(unique(fitted.ticker)),
            paths=nrow(fitted),as_fitted=multiplier*mean(fitted[!,metric]),
            empirical_scale=multiplier*mean(alternative[!,metric]),
            paired_difference=mean(differences),
            paired_mc_se=std(replication_means.difference)/sqrt(nrow(replication_means))))
    end
    return DataFrame(records)
end

function run_fallback_diagnostic(root=_ROOT)
    canonical,calibration,training = load_canonical_training(root)
    validate_training_provenance(training,root;require_fits=true)
    cfg = training["config"]
    universe = load(resolve_data_artifact("universe.jld2"))
    models = load(resolve_data_artifact("marginals.jld2"),"marginals")
    observations = Dict(t=>Float64.(universe["growth_rates"][:,j]) for (j,t) in enumerate(universe["tickers"]))
    inventory = fallback_inventory(models,observations)
    assets = fallback_asset_summary(inventory,models)
    affected = Set(assets.ticker[assets.near_constant_states .> 0])
    output = joinpath(root,"results","fallback-diagnostic")
    mkpath(output)
    CSV.write(joinpath(output,"state-inventory.csv"),inventory)
    CSV.write(joinpath(output,"asset-summary.csv"),assets)
    CSV.write(joinpath(output,"affected-assets.csv"),assets[assets.fallback_states .> 0,:])
    # Residual models use the same policy. Reconstruct their original pseudo-
    # prices, including rounding, rather than fitting directly to residuals.
    residual_models = load(resolve_data_artifact("marginals-residuals.jld2"),"marginals")
    gm = observations[cfg["universe"]["market_ticker"]]
    residual_observations = Dict{String,Vector{Float64}}()
    for cal in eachrow(calibration)
        residual = observations[cal.ticker].-cal.alpha.-cal.beta.*gm
        prices = ones(length(residual)+1)
        for t in eachindex(residual)
            prices[t+1]=prices[t]*exp(residual[t]*cfg["hmm"]["dt"])
        end
        residual_observations[cal.ticker] = JumpHMM.excess_growth_rates(prices;
            rf=cfg["hmm"]["risk_free_rate"],dt=cfg["hmm"]["dt"])
    end
    residual_inventory = fallback_inventory(residual_models,residual_observations)
    residual_assets = fallback_asset_summary(residual_inventory,residual_models)
    CSV.write(joinpath(output,"residual-state-inventory.csv"),residual_inventory)
    CSV.write(joinpath(output,"residual-asset-summary.csv"),residual_assets)
    println("Full-return fallback models=$(count(assets.fallback_states .> 0))/$(nrow(assets)); states=$(sum(assets.fallback_states)); near-constant=$(sum(assets.near_constant_states)); empty=$(sum(assets.empty_states)); singleton=$(sum(assets.singleton_states))")
    println("Residual fallback models=$(count(residual_assets.fallback_states .> 0))/$(nrow(residual_assets))")
    flush(stdout)

    seed,n = Int(cfg["simulation"]["seed"]),Int(cfg["simulation"]["n_paths"])
    f,threshold = cfg["hybrid"]["idiosyncratic_floor"],cfg["hybrid"]["r2_preserve_threshold"]
    score = training_scorer(gm)
    cached = Dict((r.ticker,r.composer,r.rep)=>r for r in eachrow(canonical) if r.composer in ("naive","hybrid"))
    blocks = DataFrame[]
    comparisons = NamedTuple[]
    BLAS.set_num_threads(1)
    for (i,cal) in enumerate(eachrow(calibration))
        cal.ticker in affected || continue
        x = observations[cal.ticker]
        model = models[cal.ticker]
        model.jump.ϵ==0 || error("Expected canonical no-jump model")
        selected = inventory[inventory.ticker .== cal.ticker,:]
        alternative = fallback_alternative(model,selected)
        original_paths = simulate(model,length(gm);n_paths=n,seed=seed+i).paths
        alternative_paths = simulate(alternative,length(gm);n_paths=n,seed=seed+i).paths
        # Explicitly verify pairing and that changing scales does not consume
        # a different random stream or change observations in other states.
        modified = Set(selected.state[selected.reason .== "near_constant"])
        for rep in 1:n
            old,new = original_paths[rep],alternative_paths[rep]
            old.states==new.states && old.jumps==new.jumps || error("Paired state path changed")
            untouched = [!(s in modified) for s in old.states]
            old.observations[untouched]==new.observations[untouched] || error("Unmodified emissions changed")
        end
        ref_acf = autocor(abs.(x),1:25)
        records = Vector{NamedTuple}(undef,n*6)
        Threads.@threads for rep in 1:n
            for (treatment_index,(treatment,draw)) in enumerate((("as_fitted",original_paths[rep]),("empirical_scale",alternative_paths[rep])))
                raw = draw.observations
                naive = compose_naive(cal.alpha,cal.beta,gm,raw)
                hybrid,beta_eff,flag = compose_hybrid(cal.alpha,cal.beta,cal.r2_real,gm,raw,var(gm),var(raw);f=f,R²_threshold=threshold)
                for (method_index,(method,g,b,branch)) in enumerate((("uncomposed",raw,NaN,"UNCOMPOSED"),
                    ("naive",naive,cal.beta,"NAIVE"),("hybrid",hybrid,beta_eff,string(flag))))
                    metrics = fallback_score(g,x,gm,score,ref_acf)
                    if treatment=="as_fitted" && method!="uncomposed"
                        saved = cached[(cal.ticker,method,rep)]
                        all(getproperty(metrics,k)==saved[k] for k in (:α_hat,:β_hat,:R²_hat,:ks_p,:ad_p,:w1,:hill_up,:kurt,:var_g)) ||
                            error("Canonical score replay differs: $(cal.ticker)/$method/$rep")
                        b==saved.beta_eff && branch==saved.flag || error("Canonical branch replay differs")
                    end
                    slot = (rep-1)*6+(treatment_index-1)*3+method_index
                    records[slot] = merge((ticker=cal.ticker,rep=rep,method=method,treatment=treatment,
                        beta_eff=b,branch=branch,generator_variance=var(raw)),metrics)
                end
            end
        end
        block = DataFrame(records)
        push!(blocks,block)
        println("Sensitivity $(length(blocks))/$(length(affected)): $(cal.ticker); canonical metrics match")
        flush(stdout)
    end
    paths = vcat(blocks...)
    summary = fallback_sensitivity_summary(paths)
    CSV.write(joinpath(output,"paired-paths.csv"),paths)
    CSV.write(joinpath(output,"sensitivity-summary.csv"),summary)
    validate_training_provenance(training,root;require_fits=true)
    sources = ["src/FallbackDiagnostic.jl","scripts/16-Fallback-Diagnostic.jl"]
    artifacts = ["state-inventory.csv","asset-summary.csv","affected-assets.csv","residual-state-inventory.csv",
        "residual-asset-summary.csv","paired-paths.csv","sensitivity-summary.csv"]
    metadata = Dict("schema_version"=>1,"completed_utc"=>string(now(UTC))*"Z","julia_version"=>string(VERSION),
        "training_signature"=>training["signature"],"training_cache_sha256"=>training["artifact_sha256"]["results.jld2"],
        "source_sha256"=>Dict(p=>training_hash(joinpath(root,p)) for p in sources),
        "artifact_sha256"=>Dict(p=>training_hash(joinpath(output,p)) for p in artifacts),
        "full_return_assets"=>nrow(assets),"residual_assets"=>nrow(residual_assets),
        "affected_full_return_assets"=>count(assets.fallback_states .> 0),
        "full_return_fallback_states"=>sum(assets.fallback_states),
        "near_constant_states"=>sum(assets.near_constant_states),"empty_states"=>sum(assets.empty_states),
        "singleton_states"=>sum(assets.singleton_states),"uniform_transition_rows"=>sum(assets.uniform_transition_rows),
        "affected_residual_assets"=>count(residual_assets.fallback_states .> 0),
        "sensitivity_assets"=>sort(collect(affected)),"replications"=>n,"observations"=>length(gm),
        "seed"=>seed,"paired_score_rows"=>nrow(paths),"canonical_composed_paths_replayed"=>2*n*length(affected),
        "state_and_unchanged_emission_paths_identical"=>true,"canonical_metrics_exact"=>true,
        "protocol"=>"Original training draws and observed SPY; keep sparse fallback, state paths, locations, and transitions; replace only populated near-constant global scales with empirical scales; no production changes",
        "uncertainty"=>"Paired Monte Carlo SE from 100 replication-level averages over the fixed affected asset set")
    open(joinpath(output,"metadata.toml"),"w") do io
        TOML.print(io,metadata;sorted=true)
    end
    show(summary;allrows=true,allcols=true); println()
    return inventory,assets,paths,summary,metadata
end
