# Fit the GARCH(1,1)-t residual benchmark and record every acceptance decision.
# Run with --refit to replace an existing or legacy model cache.
# --output-dir PATH writes an isolated run while using the canonical inputs.
using CSV, DataFrames, Dates, JLD2, Random, SHA, Statistics, TOML
import ARCHModels

const ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ROOT, "src", "GARCHFit.jl"))

function main(args)
    output = joinpath(ROOT, "data")
    refit = false
    i = 1
    while i <= length(args)
        if args[i] == "--refit"
            refit = true
        elseif args[i] == "--output-dir" && i < length(args)
            i += 1
            output = abspath(args[i])
        else
            error("Usage: 01c-Fit-GARCH.jl [--refit] [--output-dir PATH]")
        end
        i += 1
    end
    cfg = TOML.parsefile(joinpath(ROOT, "config.toml"))
    seed = Int(cfg["simulation"]["seed"])
    files = Dict("universe"=>joinpath(ROOT, "data", "universe.jld2"),
                 "calibration"=>joinpath(ROOT, "data", "sim-calibration.jld2"),
                 "config"=>joinpath(ROOT, "config.toml"),
                 "manifest"=>joinpath(ROOT, "Manifest.toml"),
                 "fitter"=>@__FILE__, "validation"=>joinpath(ROOT, "src", "GARCHFit.jl"))
    for package in (ARCHModels, ARCHModels.Optim)
        source_root = dirname(pathof(package))
        for (parent, _, names) in walkdir(source_root), name in names
            endswith(name, ".jl") || continue
            path = joinpath(parent, name)
            files[string(nameof(package), "/", relpath(path, source_root))] = path
        end
    end
    hashes = Dict(name=>open(io->bytes2hex(sha256(io)), path) for (name,path) in files)
    fingerprint = bytes2hex(sha256(join([name*":"*hashes[name] for name in sort(collect(keys(hashes)))], "\n")))
    ud = load(files["universe"])
    calib = load(files["calibration"], "calibration")
    tickers, G = ud["tickers"], ud["growth_rates"]
    index = Dict(t=>i for (i,t) in enumerate(tickers))
    gm = G[:, index[cfg["universe"]["market_ticker"]]]
    mkpath(output)
    cache_path = joinpath(output, "garch-t-models.jld2")
    if isfile(cache_path) && !refit
        cache = load(cache_path)
        get(get(cache, "metadata", Dict()), "fingerprint", "") == fingerprint ||
            error("Existing GARCH cache lacks matching source/input provenance. Rerun with --refit.")
        load_validated_garch_models(cache_path; trial_length=length(gm), seed)
        diagnostics = cache["diagnostics"]
        @info "Reused validated GARCH cache" assets=count(diagnostics.accepted)
    else
        models = Dict{String,Any}()
        rows = NamedTuple[]
        for (i, row) in enumerate(eachrow(calib))
            residual = G[:, index[row.ticker]] .- row.alpha .- row.beta .* gm
            model, record = fit_checked_garch(residual; ticker=row.ticker, seed=seed+i)
            push!(rows, record)
            model === nothing || (models[row.ticker] = model)
            if i == 1 || i % 25 == 0 || i == nrow(calib)
                @info "GARCH fitting" completed=i total=nrow(calib) accepted=length(models)
            end
        end
        diagnostics = DataFrame(rows)
        metadata = Dict("schema"=>GARCH_CACHE_SCHEMA, "fingerprint"=>fingerprint,
            "source_sha256"=>hashes, "finished_utc"=>string(now(UTC))*"Z",
            "julia_version"=>string(VERSION), "archmodels_version"=>string(Base.pkgversion(ARCHModels)),
            "optim_version"=>string(Base.pkgversion(ARCHModels.Optim)),
            "seed"=>seed, "trial_length"=>length(gm), "assets_considered"=>nrow(calib),
            "assets_accepted"=>length(models), "assets_excluded"=>nrow(calib)-length(models),
            "optimizer"=>"BFGS with forward autodiff; pinned ARCHModels defaults",
            "acceptance"=>"converged; finite coefficients/objective; omega>0; alpha,beta>=0; alpha+beta<1; nu>2; finite positive unconditional variance and trial variance")
        temporary = cache_path * ".tmp"
        jldsave(temporary; models, diagnostics, metadata)
        load_validated_garch_models(temporary; trial_length=length(gm), seed)
        mv(temporary, cache_path; force=true)
    end
    # Always write exclusions, including an empty table, to remove stale rows.
    CSV.write(joinpath(output, "garch-t-diagnostics.csv"), diagnostics)
    CSV.write(joinpath(output, "garch-t-skipped.csv"),
              select(filter(r->!r.accepted, diagnostics), :ticker, :reason))
    metadata = load(cache_path, "metadata")
    open(joinpath(output, "garch-t-metadata.toml"), "w") do io
        TOML.print(io, metadata; sorted=true)
    end
    @info "GARCH cache ready" accepted=count(diagnostics.accepted) excluded=count(.!diagnostics.accepted) output=output
end

main(ARGS)
