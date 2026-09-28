# Calibrate Table 5 thresholds without opening the holdout, then score once.
# julia --compiled-modules=existing --threads=4 --project=code/downstream-evaluation \
#   code/downstream-evaluation/scripts/13-VaR-Ensemble.jl [--pilot]
using CSV, DataFrames, JLD2, LinearAlgebra, Random, SHA, Statistics, TOML
using VLQuantitativeFinancePackage
import JumpHMM
using JumpHMM: JumpHiddenMarkovModel
const _ROOT = normpath(joinpath(@__DIR__, ".."))
const _PATH_TO_DATA = joinpath(_ROOT, "data")
include(joinpath(_ROOT, "src", "Composers.jl"))
include(joinpath(_ROOT, "src", "GARCHFit.jl"))
include(joinpath(_ROOT, "src", "Pipeline.jl"))
include(joinpath(_ROOT, "src", "VaRBacktest.jl"))
include(joinpath(_ROOT, "src", "VaREnsemble.jl"))

function main()
    pilot = "--pilot" in ARGS
    output = joinpath(_ROOT, "results", pilot ? "var-ensemble-pilot" : "var-ensemble")
    mkpath(joinpath(output, "assets"))
    cfg = TOML.parsefile(joinpath(_ROOT, "config.toml"))
    settings = TOML.parsefile(joinpath(_ROOT, "var-ensemble.toml"))
    if pilot
        settings["calibration_paths"] = 1000
        settings["validation_paths"] = 200
        settings["checkpoints"] = [100, 500, 1000]
    end
    sources = [joinpath(_PATH_TO_DATA, f) for f in ("universe.jld2", "marginals.jld2",
        "marginals-residuals.jld2", "sim-calibration.jld2", "garch-t-models.jld2")]
    append!(sources, [joinpath(_ROOT, "src", f) for f in
        ("Composers.jl", "GARCHFit.jl", "Pipeline.jl", "VaRBacktest.jl", "VaREnsemble.jl")])
    append!(sources, [@__FILE__, joinpath(_ROOT,"config.toml"),
        joinpath(_ROOT,"var-ensemble.toml"), joinpath(_ROOT,"Manifest.toml")])
    for package in (JumpHMM, ARCHModels)
        for (parent, _, files) in walkdir(dirname(pathof(package))), name in sort(files)
            endswith(name, ".jl") && push!(sources, joinpath(parent, name))
        end
    end
    hashes = Dict(relpath(p, _ROOT) => open(io -> bytes2hex(sha256(io)), p) for p in sources)
    signature = bytes2hex(sha256(join([p*":"*hashes[p] for p in sort(collect(keys(hashes)))], "\n")))
    manifest = joinpath(output, "provenance.toml")
    if isfile(manifest)
        previous = TOML.parsefile(manifest)
        previous["signature"] == signature && previous["settings"] == settings ||
            error("Ensemble source/settings mismatch; use a separate output directory")
    else
        open(manifest, "w") do io
            TOML.print(io, Dict("signature"=>signature, "settings"=>settings, "hashes"=>hashes,
                "julia_version"=>string(VERSION), "threads"=>Threads.nthreads()))
        end
    end
    BLAS.set_num_threads(1)
    ud = load(joinpath(_PATH_TO_DATA,"universe.jld2"))
    calib = load(joinpath(_PATH_TO_DATA,"sim-calibration.jld2"),"calibration")
    models = load(joinpath(_PATH_TO_DATA,"marginals.jld2"),"marginals")
    residual_models = load(joinpath(_PATH_TO_DATA,"marginals-residuals.jld2"),"marginals")
    garch_models = load_validated_garch_models(joinpath(_PATH_TO_DATA,"garch-t-models.jld2");
        trial_length=settings["horizon"], seed=settings["seed"])
    index = Dict(t=>i for (i,t) in enumerate(ud["tickers"]))
    gm = ud["growth_rates"][:,index[cfg["universe"]["market_ticker"]]]
    @assert settings["horizon"] == 249
    @assert maximum(settings["checkpoints"]) == settings["calibration_paths"]
    @assert all(m.jump.ϵ == 0 for m in values(models))
    @assert all(m.jump.ϵ == 0 for m in values(residual_models))
    markets = [var_market_paths(models[cfg["universe"]["market_ticker"]], n,
        settings["horizon"], settings["batch_size"], settings["seed"], phase)
        for (phase,n) in enumerate((settings["calibration_paths"], settings["validation_paths"]))]
    ids = pilot ? findall(t -> t in ("AAPL","JNJ","QQQ","NVDA","JPM","MSFT"), calib.ticker) : collect(1:nrow(calib))
    started = time()
    count_done = Threads.Atomic{Int}(0)
    Threads.@threads :dynamic for i in ids
        cal = calib[i,:]
        path = joinpath(output,"assets",cal.ticker*".csv")
        if !isfile(path)
            history = ud["growth_rates"][:,index[cal.ticker]] .- cal.alpha .- cal.beta .* gm
            calibration = var_asset_paths(cal, i, models, residual_models, garch_models,
                history, markets[1], var(gm), cfg, settings, 1)
            validation = var_asset_paths(cal, i, models, residual_models, garch_models,
                history, markets[2], var(gm), cfg, settings, 2)
            asset_summary = summarize_var_calibration(calibration, validation, cal.ticker, settings["checkpoints"])
            @assert all(==(cal.ticker), asset_summary.ticker)
            CSV.write(path*".tmp", asset_summary)
            mv(path*".tmp", path; force=true)
        end
        done = Threads.atomic_add!(count_done, 1)+1
        if done <= 6 || done % 20 == 0 || done == length(ids)
            println("Calibrated $done/$(length(ids)): $(cal.ticker), elapsed=$(round(time()-started;digits=1))s")
            flush(stdout)
        end
    end
    asset_tables = map(ids) do i
        # Single-ticker files such as F and T must not be inferred as Boolean.
        table = CSV.read(joinpath(output,"assets",calib.ticker[i]*".csv"),DataFrame;
                         types=Dict(:ticker=>String))
        @assert all(==(calib.ticker[i]), table.ticker)
        expected_methods = haskey(garch_models,calib.ticker[i]) ? Set(VAR_METHODS) : Set(VAR_METHODS[1:5])
        @assert Set(table.composer) == expected_methods
        @assert nrow(unique(table,[:composer,:alpha_level,:calibration_paths])) ==
            nrow(table) == length(expected_methods)*2*length(settings["checkpoints"])
        table
    end
    thresholds = vcat(asset_tables...)
    CSV.write(joinpath(output,"thresholds.csv"), thresholds)
    pilot && return

    # Calibration and all convergence checkpoints are now fixed and persisted.
    # Only this scoring stage reads the 2025 histories.
    tickers_test, prices_test = load_test_universe(250)
    observed = growth_rate_matrix(prices_test; rf=0.0, dt=cfg["hmm"]["dt"]) .* cfg["hmm"]["dt"]
    @assert size(observed,1) == settings["horizon"]
    test_index = Dict(t=>i for (i,t) in enumerate(tickers_test))
    scores = NamedTuple[]
    for row in eachrow(thresholds)
        haskey(test_index,row.ticker) || continue
        r = @view observed[:,test_index[row.ticker]]
        n = count(x -> x < -row.threshold, r)
        push!(scores, merge(NamedTuple(row), (; breaches=n, observations=length(r), rate=n/length(r))))
    end
    result = DataFrame(scores)
    CSV.write(joinpath(output,"scores.csv"),result)
    common = Set(result[result.composer .== "garch_t", :ticker])
    summaries = DataFrame[]
    for population in ("available","common")
        selected = population == "common" ? filter(r -> r.ticker in common, result) : result
        summary = combine(groupby(selected,[:composer,:alpha_level,:calibration_paths]),
            :ticker=>length=>:n_tickers, :rate=>mean=>:mean_rate, :rate=>std=>:sd_rate,
            :validation_rate=>mean=>:validation_rate)
        summary.population = fill(population, nrow(summary))
        push!(summaries,summary)
    end
    CSV.write(joinpath(output,"summary.csv"),vcat(summaries...))
    open(joinpath(output,"scoring.toml"), "w") do io
        TOML.print(io, Dict("calibration_signature"=>signature,
            "thresholds_sha256"=>open(io -> bytes2hex(sha256(io)),joinpath(output,"thresholds.csv")),
            "holdout_tickers"=>tickers_test,
            "holdout_returns_sha256"=>bytes2hex(sha256(reinterpret(UInt8,vec(observed)))),
            "horizon"=>size(observed,1), "calibration_paths"=>settings["calibration_paths"]))
    end
    println("Completed pooled VaR calibration and independent validation; scored $(length(unique(result.ticker))) holdout assets.")
end
main()
