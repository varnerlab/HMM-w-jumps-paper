# Jump-duration ablation for frozen multi-asset generators. Simulation remains
# serial because JumpHMM owns the RNG; independent path scoring is threaded.

using SHA

const JUMP_CASES = ("off", "market_only", "market_and_assets")
const JUMP_METHODS = ("naive", "hybrid")

"""Copy a fitted model with specified jump settings; leave its fitted arrays unchanged."""
function ablation_model(model, enabled, settings)
    jump = JumpHMM.JumpParameters(enabled ? settings["epsilon"] : 0.0,
        settings["lambda"]; p_neg=settings["p_neg"], N_tail=settings["n_tail"])
    return JumpHiddenMarkovModel(model.partition, model.transition, model.emissions,
        model.stationary, jump, model.ν, model.rf, model.dt)
end

"""Reference statistics, computed once for each observed ticker and window."""
function ablation_reference(g, lag_windows; ad_sd=KSampleADTest(g,g).σ)
    lags = 1:maximum(lag_windows)
    return (g=g, variance=var(g), sd=std(g), kurt=kurtosis(g),
        abs_acf=autocor(abs.(g), lags), raw_acf=autocor(g, 1:first(lag_windows)),
        lag_windows=lag_windows, ad_sd=ad_sd)
end

"""Reuse the AD normalization for equal sample lengths, retaining the package statistic and p-value."""
function ablation_ad_pvalue(g, ref)
    length(g)==length(ref.g) || error("AD normalization assumes equal sample lengths")
    pooled = vcat(g,ref.g)
    _,statistic = HypothesisTests.adkvals(unique(sort(pooled)),length(pooled),(g,ref.g))
    test = KSampleADTest(2,length(pooled),ref.ad_sd,statistic,true,0,pooled,
        [length(g),length(ref.g)])
    return pvalue(test)
end

"""Path diagnostics; KS/AD are descriptive non-rejection fractions, not calibrated coverage."""
function ablation_metrics(g, ref, gm, gen_var, calibration, beta_eff, flag)
    short, long = ref.lag_windows
    abs_acf = autocor(abs.(g), 1:long)
    a, b, r2 = sim_recovery(g, gm)
    w1 = wasserstein1(g, ref.g)
    vg = var(g)
    return (ks_pass=Float64(ks_pvalue(g, ref.g) > 0.05),
        ad_pass=Float64(ablation_ad_pvalue(g, ref) > 0.05),
        w1=w1, w1_standardized=w1/ref.sd,
        abs_acf_mae25=mean(abs.(abs_acf[1:short] .- ref.abs_acf[1:short])),
        abs_acf_mae60=mean(abs.(abs_acf .- ref.abs_acf)),
        raw_acf_mae25=mean(abs.(autocor(g, 1:short) .- ref.raw_acf)),
        kurtosis=kurtosis(g), kurtosis_abs_error=abs(kurtosis(g)-ref.kurt),
        variance_ratio_generator=vg/gen_var, variance_ratio_observed=vg/ref.variance,
        beta_abs_error=abs(b-calibration.beta), beta_effective_abs_error=abs(b-beta_eff),
        r2_abs_error=abs(r2-calibration.r2_real),
        clipped=Float64(flag == HYBRID_CLIPPED), tracker=Float64(flag == R2_PRESERVE),
        var99_rate=mean(ref.g .< quantile(g, 0.01)),
        var95_rate=mean(ref.g .< quantile(g, 0.05)))
end

"""Run one seed/window block and return sufficient summaries for paired comparisons."""
function ablation_block(settings, cfg, window, seed, tickers, observed, train_index,
        marginals, calibration, output_path)
    n_paths = settings["n_paths_per_seed"]
    horizon = size(observed, 1)
    market = cfg["universe"]["market_ticker"]
    off_market = ablation_model(marginals[market], false, settings)
    on_market = ablation_model(marginals[market], true, settings)
    # One market draw per replication is shared by every ticker. Seed namespaces
    # separate the market from assets, windows, and independent simulation batches.
    offset = window == "training" ? 0 : 100_000_000
    market_seed = offset + seed + 9_000_000
    markets = (simulate(off_market, horizon; n_paths=n_paths, seed=market_seed).paths,
               simulate(on_market, horizon; n_paths=n_paths, seed=market_seed+20_000_000).paths)
    obs_index = Dict(t => i for (i,t) in enumerate(tickers))
    active_calib = filter(r -> haskey(obs_index,r.ticker), calibration)
    n_assets = nrow(active_calib)
    market_ref = ablation_reference(observed[:,obs_index[market]], settings["acf_lags"])
    market_rows = NamedTuple[]
    for enabled in 1:2, rep in 1:n_paths
        path = markets[enabled][rep]
        acf = autocor(abs.(path.observations), 1:60)
        push!(market_rows, (window=window, seed=seed, rep=rep, enabled=enabled==2,
            jump_active=any(path.jumps), forced_fraction=mean(path.jumps),
            abs_acf_mae25=mean(abs.(acf[1:25]-market_ref.abs_acf[1:25])),
            abs_acf_mae60=mean(abs.(acf-market_ref.abs_acf)),
            variance_ratio_observed=var(path.observations)/market_ref.variance))
    end
    ticker_rows = NamedTuple[]
    generator_rows = NamedTuple[]
    stratum_rows = NamedTuple[]
    metric_names = Symbol[]
    rep_totals = zeros(n_paths, 3, 2, 18)
    t0 = time()
    for (i,cal) in enumerate(eachrow(active_calib))
        ticker = cal.ticker
        ref = ablation_reference(observed[:,obs_index[ticker]], settings["acf_lags"];
            ad_sd=market_ref.ad_sd)
        asset_seed = offset + seed + train_index[ticker]
        asset_models = (ablation_model(marginals[ticker], false, settings),
                        ablation_model(marginals[ticker], true, settings))
        draws = (simulate(asset_models[1], horizon; n_paths=n_paths, seed=asset_seed).paths,
                 simulate(asset_models[2], horizon; n_paths=n_paths, seed=asset_seed+20_000_000).paths)
        rows = Vector{NamedTuple}(undef, n_paths*6)
        for enabled in 1:2
            paths = draws[enabled]
            acf_errors = [mean(abs.(autocor(abs.(p.observations),1:25)-ref.abs_acf[1:25])) for p in paths]
            push!(generator_rows, (window=window, seed=seed, ticker=ticker,
                enabled=enabled==2, n_paths=n_paths,
                jump_active_rate=mean(any(p.jumps) for p in paths),
                forced_fraction=mean(mean(p.jumps) for p in paths),
                abs_acf_mae25=mean(acf_errors)))
        end
        Threads.@threads for rep in 1:n_paths
            for case in 1:3
                market_path = markets[case==1 ? 1 : 2][rep]
                draw = draws[case==3 ? 2 : 1][rep]
                gm, x = market_path.observations, draw.observations
                vx = var(x)
                naive = compose_naive(cal.alpha,cal.beta,gm,x)
                hybrid,beta_eff,flag = compose_hybrid(cal.alpha,cal.beta,cal.r2_real,
                    gm,x,var(gm),vx; f=cfg["hybrid"]["idiosyncratic_floor"],
                    R²_threshold=cfg["hybrid"]["r2_preserve_threshold"])
                for method in 1:2
                    g = method==1 ? naive : hybrid
                    metrics = ablation_metrics(g,ref,gm,vx,cal,
                        method==1 ? cal.beta : beta_eff, method==1 ? NAIVE : flag)
                    idx = (rep-1)*6 + (case-1)*2 + method
                    rows[idx] = merge((case=case,method=method,rep=rep,
                        market_jump=any(market_path.jumps),asset_jump=any(draw.jumps)),metrics)
                end
            end
        end
        metric_names = collect(keys(rows[1]))[6:end]
        @assert length(metric_names)==size(rep_totals,4)
        for r in rows, (k,name) in enumerate(metric_names)
            value = r[name]
            isfinite(value) || error("nonfinite $name for $ticker, $window, $seed")
            rep_totals[r.rep,r.case,r.method,k] += value/n_assets
        end
        df = DataFrame(rows)
        for group in groupby(df,[:case,:method])
            case,method = group.case[1],group.method[1]
            means = NamedTuple{Tuple(metric_names)}(Tuple(mean(group[!,s]) for s in metric_names))
            push!(ticker_rows,merge((window=window,seed=seed,ticker=ticker,
                scenario=JUMP_CASES[case],method=JUMP_METHODS[method],n_paths=n_paths,
                median_variance_ratio_generator=median(group.variance_ratio_generator),
                median_variance_ratio_observed=median(group.variance_ratio_observed)),means))
        end
        # Keep jump-active results separate as mechanism diagnostics. The main
        # summaries always include all paths, including those with no episode.
        for group in groupby(df,[:case,:method,:market_jump,:asset_jump])
            means = NamedTuple{Tuple(metric_names)}(Tuple(mean(group[!,s]) for s in metric_names))
            push!(stratum_rows,merge((window=window,seed=seed,ticker=ticker,
                scenario=JUMP_CASES[group.case[1]],method=JUMP_METHODS[group.method[1]],
                market_jump=group.market_jump[1],asset_jump=group.asset_jump[1],n_paths=nrow(group)),means))
        end
        if i==1 || i%25==0 || i==n_assets
            @info "Jump ablation" window seed ticker progress="$i/$n_assets" elapsed_s=round(time()-t0)
        end
    end
    rep_rows = NamedTuple[]
    for rep in 1:n_paths, case in 1:3, method in 1:2
        metrics = NamedTuple{Tuple(metric_names)}(Tuple(rep_totals[rep,case,method,:]))
        push!(rep_rows,merge((window=window,seed=seed,rep=rep,scenario=JUMP_CASES[case],
            method=JUMP_METHODS[method],n_assets=n_assets),metrics))
    end
    result = (ticker=DataFrame(ticker_rows),replication=DataFrame(rep_rows),
        generator=DataFrame(generator_rows),market=DataFrame(market_rows),stratum=DataFrame(stratum_rows))
    jldsave(output_path; result=result, settings=settings, elapsed_seconds=time()-t0)
    return result
end

"""Summarize outcomes and paired Monte Carlo differences on fixed historical data."""
function summarize_ablation(blocks, directory)
    tables = Dict(name => vcat([getproperty(b,name) for b in blocks]...) for name in
        (:ticker,:replication,:generator,:market,:stratum))
    for (name,df) in tables
        CSV.write(joinpath(directory,"$(name)-metrics.csv"),df)
    end
    rep = tables[:replication]
    metrics = Symbol.(names(rep)[7:end])
    summary = combine(groupby(rep,[:window,:scenario,:method]),
        [s=>mean=>s for s in metrics]...)
    CSV.write(joinpath(directory,"summary.csv"),summary)
    contrasts = NamedTuple[]
    for window in unique(rep.window)
        part = filter(r->r.window==window,rep)
        comparisons = [("correction",c,"naive",c,"hybrid") for c in JUMP_CASES]
        append!(comparisons,[("jump_setting","off",m,c,m) for m in JUMP_METHODS for c in JUMP_CASES[2:3]])
        for (kind,base_case,base_method,new_case,new_method) in comparisons
            base = sort(filter(r->r.scenario==base_case && r.method==base_method,part),[:seed,:rep])
            changed = sort(filter(r->r.scenario==new_case && r.method==new_method,part),[:seed,:rep])
            @assert base[:,[:seed,:rep]]==changed[:,[:seed,:rep]]
            for metric in metrics
                d = changed[!,metric]-base[!,metric]
                se = std(d)/sqrt(length(d))
                push!(contrasts,(window=window,kind=kind,baseline="$base_case/$base_method",
                    changed="$new_case/$new_method",metric=String(metric),
                    mean_difference=mean(d),mc_se=se,mc_low=mean(d)-1.96se,
                    mc_high=mean(d)+1.96se,n_market_replications=length(d)))
            end
        end
    end
    CSV.write(joinpath(directory,"paired-contrasts.csv"),DataFrame(contrasts))
    return summary,tables
end

function run_jump_ablation(settings; smoke=false)
    cfg = load_config()
    settings = deepcopy(settings)
    if smoke
        settings["n_paths_per_seed"] = 20
        settings["seeds"] = [1234]
        settings["output_directory"] *= "-smoke"
    end
    directory = joinpath(_ROOT,settings["output_directory"])
    mkpath(directory)
    universe = load(resolve_data_artifact("universe.jld2"))
    marginals = load(resolve_data_artifact("marginals.jld2"))["marginals"]
    calibration = load(resolve_data_artifact("sim-calibration.jld2"))["calibration"]
    @assert all(m.jump.ϵ==0 for m in values(marginals)) "Expected cached no-jump fits"
    @assert settings["acf_lags"]==[25,60]
    if smoke
        calibration = filter(r->r.ticker in ["AAPL","JNJ","QQQ"],calibration)
    end
    train_index = Dict(t=>i for (i,t) in enumerate(universe["tickers"]))
    test_tickers,test_prices = load_test_universe(250)
    test_g = growth_rate_matrix(test_prices;rf=0.0,dt=cfg["hmm"]["dt"])
    @assert size(test_g,1)==249 "Expected the frozen 2025 holdout"
    @assert size(universe["growth_rates"],1)==2766
    # Cache validation includes code, inputs, and the experiment environment.
    # Reading external fitted-model caches is allowed; outputs stay in this repo.
    fingerprint(path) = open(io->bytes2hex(sha256(io)),path)
    settings["provenance"] = Dict(
        "julia_version"=>string(VERSION),
        "ablation_source_sha256"=>fingerprint(@__FILE__),
        "composer_source_sha256"=>fingerprint(joinpath(_PATH_TO_SRC,"Composers.jl")),
        "metrics_source_sha256"=>fingerprint(joinpath(_PATH_TO_SRC,"Metrics.jl")),
        "pipeline_source_sha256"=>fingerprint(joinpath(_PATH_TO_SRC,"Pipeline.jl")),
        "manifest_sha256"=>fingerprint(joinpath(_ROOT,"Manifest.toml")),
        "base_config_sha256"=>fingerprint(_PATH_TO_CONFIG),
        "marginals_sha256"=>fingerprint(resolve_data_artifact("marginals.jld2")),
        "universe_sha256"=>fingerprint(resolve_data_artifact("universe.jld2")),
        "calibration_sha256"=>fingerprint(resolve_data_artifact("sim-calibration.jld2")),
        "holdout_growth_sha256"=>bytes2hex(sha256(reinterpret(UInt8,vec(test_g)))),
        "holdout_tickers_sha256"=>bytes2hex(sha256(join(test_tickers,"\n"))),
        "simulator_sha256"=>fingerprint(joinpath(dirname(pathof(JumpHMM)),"Simulate.jl")))
    open(joinpath(directory,"settings.toml"),"w") do io
        TOML.print(io,settings)
    end
    blocks = NamedTuple[]
    for (window,tickers,g) in (("training",universe["tickers"],universe["growth_rates"]),
                               ("holdout_2025",test_tickers,test_g))
        for seed in settings["seeds"]
            path = joinpath(directory,"block-$(window)-$(seed).jld2")
            if isfile(path)
                saved = load(path)
                saved["settings"]==settings || error("Settings mismatch in $path")
                @info "Loading completed jump-ablation block" path
                push!(blocks,saved["result"])
            else
                push!(blocks,ablation_block(settings,cfg,window,seed,tickers,g,
                    train_index,marginals,calibration,path))
            end
        end
    end
    summary,tables = summarize_ablation(blocks,directory)
    @info "Jump ablation complete" directory
    show(stdout,MIME("text/plain"),summary[:,[:window,:scenario,:method,:ks_pass,
        :abs_acf_mae25,:abs_acf_mae60,:variance_ratio_observed]])
    println()
    return summary,tables
end
