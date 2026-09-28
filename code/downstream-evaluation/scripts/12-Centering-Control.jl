# Paired training comparison of native and equivalent residual centering.
# Reuses frozen models and the production composers; writes only its own results.
# Run from the repository root:
# julia --compiled-modules=existing --threads=4 --project=code/downstream-evaluation \
#   code/downstream-evaluation/scripts/12-Centering-Control.jl
using CSV, DataFrames, Dates, Distributions, HypothesisTests, JLD2
using LinearAlgebra, Printf, Random, SHA, Statistics, StatsBase, TOML
import JumpHMM, ARCHModels
using JumpHMM: JumpHiddenMarkovModel

const ROOT = normpath(joinpath(@__DIR__, ".."))
const DATA = joinpath(ROOT, "data")
const OUTPUT = joinpath(ROOT, "results", "centering-control")
const METHODS = ("naive", "gaussian", "hybrid", "residual_jumphmm", "block_bootstrap", "garch_t")
include(joinpath(ROOT, "src", "Composers.jl"))
include(joinpath(ROOT, "src", "Metrics.jl"))
include(joinpath(ROOT, "src", "JumpAblation.jl"))

file_hash(path) = open(io -> bytes2hex(sha256(io)), path)

function control_score(g, ref, gm, cal)
    a, b, r2 = sim_recovery(g, gm)
    return (ks_pass=Float64(ks_pvalue(g, ref.g) > 0.05),
        ad_pass=Float64(ablation_ad_pvalue(g, ref) > 0.05),
        w1=wasserstein1(g, ref.g), alpha_error=abs(a-cal.alpha),
        beta_error=abs(b-cal.beta), r2_error=abs(r2-cal.r2_real),
        variance=var(g), kurtosis=kurtosis(g))
end

function summarize(results, common)
    summaries = NamedTuple[]
    for population in ("available", "common")
        selected = population == "common" ? filter(r -> r.ticker in common, results) : results
        for method in METHODS, treatment in ("native", "centered")
            r = filter(row -> row.method == method, selected)
            k(name) = Symbol(treatment, "_", name)
            push!(summaries, (; population, method, treatment,
                assets=length(unique(r.ticker)), paths=nrow(r),
                ks_pass=100mean(r[!, k("ks_pass")]), ad_pass=100mean(r[!, k("ad_pass")]),
                w1=median(r[!, k("w1")]), alpha_error=median(r[!, k("alpha_error")]),
                beta_error=median(r.native_beta_error), r2_error=median(r.native_r2_error),
                kurtosis=median(r.native_kurtosis)))
        end
    end
    return DataFrame(summaries)
end

function main()
    mkpath(OUTPUT)
    cfg = TOML.parsefile(joinpath(ROOT, "config.toml"))
    seed = Int(cfg["simulation"]["seed"])
    n_paths = Int(cfg["simulation"]["n_paths"])
    BLAS.set_num_threads(1)
    sources = [joinpath(DATA, f) for f in ("universe.jld2", "sim-calibration.jld2",
        "marginals.jld2", "marginals-residuals.jld2", "garch-t-models.jld2")]
    append!(sources, [joinpath(ROOT, "src", f) for f in ("Composers.jl", "Metrics.jl", "JumpAblation.jl")])
    append!(sources, [@__FILE__, joinpath(ROOT, "config.toml"), joinpath(ROOT, "Manifest.toml")])
    for package in (JumpHMM, ARCHModels, HypothesisTests)
        dir = dirname(pathof(package))
        for (parent, _, files) in walkdir(dir), name in sort(files)
            endswith(name, ".jl") && push!(sources, joinpath(parent, name))
        end
    end
    hashes = Dict(relpath(p, ROOT) => file_hash(p) for p in sources)
    signature = bytes2hex(sha256(join([p * ":" * hashes[p] for p in sort(collect(keys(hashes)))], "\n")))
    universe = load(joinpath(DATA, "universe.jld2"))
    calibration = load(joinpath(DATA, "sim-calibration.jld2"), "calibration")
    marginals = load(joinpath(DATA, "marginals.jld2"), "marginals")
    residuals = load(joinpath(DATA, "marginals-residuals.jld2"), "marginals")
    garch = load(joinpath(DATA, "garch-t-models.jld2"), "models")
    tickers, G = universe["tickers"], universe["growth_rates"]
    index = Dict(t => i for (i,t) in enumerate(tickers))
    gm = G[:, index[cfg["universe"]["market_ticker"]]]
    T = length(gm)
    @assert nrow(calibration) == 423 && T == 2766
    @assert all(t -> haskey(marginals,t) && haskey(residuals,t), calibration.ticker)
    @assert all(m -> m.jump.ϵ == 0, values(marginals))
    @assert all(m -> m.jump.ϵ == 0, values(residuals))
    # Validate cached eligibility without refitting or changing the GARCH cache.
    eligibility = NamedTuple[]
    for ticker in calibration.ticker
        eligible, reason = false, "absent from frozen GARCH cache"
        if haskey(garch, ticker)
            try
                Random.seed!(seed + index[ticker])
                trial = ARCHModels.simulate(garch[ticker], T).data
                eligible = all(isfinite, trial)
                reason = eligible ? "cached model simulated successfully" : "nonfinite trial"
            catch err
                reason = sprint(showerror, err)
            end
        end
        push!(eligibility, (; ticker, eligible, reason))
    end
    common = Set(r.ticker for r in eligibility if r.eligible)
    @assert !isempty(common)
    CSV.write(joinpath(OUTPUT, "garch-eligibility.csv"), DataFrame(eligibility))
    println("Training observations=$T; paths per asset=$n_paths; all assets=$(nrow(calibration)); common assets=$(length(common))")
    println("Paired residual centering; frozen fits; observed training SPY; seed=$seed")
    flush(stdout)

    # The existing fast AD scorer reuses only the sample-size normalization.
    # Check its p-value against the package scorer before the full comparison.
    ad_sd = KSampleADTest(gm, gm).σ
    probe_rng = MersenneTwister(1234)
    for observed in (gm, G[:, index["AAPL"]], round.(gm; digits=1))
        trial = rand(probe_rng, Normal(mean(observed), std(observed)), T)
        for offset in (0.0, 0.2)
            x = trial .+ offset
            @assert isapprox(ablation_ad_pvalue(x, (g=observed, ad_sd=ad_sd)),
                ad_pvalue(x, observed); atol=1e-12, rtol=1e-10)
        end
    end
    records = NamedTuple[]
    completed = String[]
    checkpoint = joinpath(OUTPUT, "results.jld2")
    if isfile(checkpoint)
        saved = load(checkpoint)
        saved["signature"] == signature || error("Existing centering results have different source fingerprints; choose a new output directory.")
        records = NamedTuple[saved["records"]...]
        completed = saved["completed"]
        println("Resuming after $(length(completed)) completed assets.")
    end
    started = time()
    for (i, cal) in enumerate(eachrow(calibration))
        cal.ticker in completed && continue
        observed = G[:, index[cal.ticker]]
        ref = (g=observed, ad_sd=ad_sd)
        real_residual = observed .- cal.alpha .- cal.beta .* gm
        # Preserve the production pipeline's simulation order and seed choices.
        full_draws = JumpHMM.simulate(marginals[cal.ticker], T; n_paths, seed=seed+i).paths
        residual_draws = JumpHMM.simulate(residuals[cal.ticker], T; n_paths, seed=seed+i+1_000_000).paths
        available = cal.ticker in common ? METHODS : METHODS[1:5]
        generated = Matrix{Vector{Float64}}(undef, n_paths, length(available))
        effective_beta = fill(cal.beta, n_paths, length(available))
        flags = fill("", n_paths, length(available))
        for rep in 1:n_paths
            x = full_draws[rep].observations
            generated[rep,1] = compose_naive(cal.alpha, cal.beta, gm, x)
            generated[rep,2] = compose_gaussian_sim(cal.alpha, cal.beta, cal.sigma_eps_real, gm, Random.default_rng())
            g, beta_eff, flag = compose_hybrid(cal.alpha, cal.beta, cal.r2_real, gm, x, var(gm), var(x);
                f=cfg["hybrid"]["idiosyncratic_floor"], R²_threshold=cfg["hybrid"]["r2_preserve_threshold"])
            generated[rep,3] = g
            effective_beta[rep,3], flags[rep,3] = beta_eff, string(flag)
            generated[rep,4] = compose_residual_jumphmm(cal.alpha, cal.beta, gm, residual_draws[rep].observations)
            rng_b = MersenneTwister(seed + i*1_000_000 + rep*1_000 + 1)
            generated[rep,5] = compose_block_bootstrap(cal.alpha, cal.beta, gm, real_residual,
                cfg["bootstrap"]["mean_block_length"], rng_b)
            if length(available) == 6
                x_garch = Float64.(ARCHModels.simulate(garch[cal.ticker], T).data)
                @assert all(isfinite, x_garch)
                generated[rep,6] = compose_garch_t(cal.alpha, cal.beta, gm, x_garch)
            end
        end
        asset_records = Vector{NamedTuple}(undef, n_paths*length(available))
        Threads.@threads for rep in 1:n_paths
            for (j, method) in enumerate(available)
                g = generated[rep,j]
                residual_mean = mean(g .- cal.alpha .- effective_beta[rep,j] .* gm)
                # Naive/hybrid already satisfy the control; reuse their metrics
                # exactly rather than introducing roundoff from recentering.
                controlled = method in ("naive", "hybrid") ? g : g .- residual_mean
                c_residual_mean = mean(controlled .- cal.alpha .- effective_beta[rep,j] .* gm)
                @assert abs(c_residual_mean) < 1e-10
                native = control_score(g, ref, gm, cal)
                centered = controlled === g ? native : control_score(controlled, ref, gm, cal)
                @assert isapprox(native.variance, centered.variance; rtol=1e-12, atol=1e-12)
                @assert isapprox(native.beta_error, centered.beta_error; atol=1e-12)
                @assert isapprox(native.r2_error, centered.r2_error; atol=1e-12)
                @assert isapprox(native.kurtosis, centered.kurtosis; rtol=1e-10, atol=1e-10)
                asset_records[(rep-1)*length(available)+j] = (
                    ticker=cal.ticker, method=method, rep=rep, seed=seed, common=cal.ticker in common,
                    flag=flags[rep,j], beta_eff=effective_beta[rep,j], residual_mean=residual_mean,
                    centered_residual_mean=c_residual_mean,
                    native_ks_pass=native.ks_pass, centered_ks_pass=centered.ks_pass,
                    native_ad_pass=native.ad_pass, centered_ad_pass=centered.ad_pass,
                    native_w1=native.w1, centered_w1=centered.w1,
                    native_alpha_error=native.alpha_error, centered_alpha_error=centered.alpha_error,
                    native_beta_error=native.beta_error, native_r2_error=native.r2_error,
                    native_variance=native.variance, native_kurtosis=native.kurtosis)
            end
        end
        append!(records, asset_records)
        push!(completed, cal.ticker)
        if i == 1 || i % 25 == 0 || i == nrow(calibration)
            @printf("%d/%d assets, %d paired paths, %.1f elapsed minutes\n", i, nrow(calibration), length(records), (time()-started)/60)
            flush(stdout)
            temporary = checkpoint * ".tmp"
            jldsave(temporary; signature, records, completed, common=collect(common), finished=false)
            mv(temporary, checkpoint; force=true)
        end
    end
    results = DataFrame(records)
    summary = summarize(results, common)
    CSV.write(joinpath(OUTPUT, "summary.csv"), summary)
    CSV.write(joinpath(OUTPUT, "paired-paths.csv"), results)
    metadata = Dict("finished_utc"=>string(now(UTC))*"Z", "signature"=>signature,
        "seed"=>seed, "n_paths_per_asset"=>n_paths, "training_observations"=>T,
        "assets"=>nrow(calibration), "common_assets"=>length(common), "paired_paths"=>nrow(results),
        "julia_version"=>string(VERSION), "threads"=>Threads.nthreads(),
        "scope"=>"Training only; frozen caches; native versus identical paths with zero residual mean",
        "source_sha256"=>hashes,
        "checks"=>Dict("fast_ad_matches_reference"=>true, "all_control_residual_means_zero"=>true,
            "variance_beta_r2_kurtosis_unchanged"=>true, "native_full_return_methods_unchanged"=>true))
    open(joinpath(OUTPUT, "metadata.toml"), "w") do io
        TOML.print(io, metadata; sorted=true)
    end
    jldsave(checkpoint; signature, records, completed, common=collect(common), finished=true, metadata)
    println("\nCommon-asset comparison:")
    show(stdout, MIME("text/plain"), filter(r -> r.population=="common", summary)); println()
end

main()
