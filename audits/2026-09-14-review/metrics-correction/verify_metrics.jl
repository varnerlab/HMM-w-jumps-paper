# Re-score the archived GRU paths and verify the R8 metric definitions.
# This reads the original scoring functions without training or simulating models.
using Statistics, StatsBase, Distributions, HypothesisTests, Random, LinearAlgebra
using DelimitedFiles, JLD2, SHA, TOML, Dates

const REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
const BASE = joinpath(REPO, "code", "baseline-comparison")
const NEURAL = joinpath(BASE, "neural-baseline")
const N_BOOT = 500
const PATH_DIRECTORY = isempty(ARGS) ? NEURAL : abspath(ARGS[1])
const OUTPUT_DIRECTORY = length(ARGS) < 2 ? (@__DIR__) : abspath(ARGS[2])
hashfile(path) = bytes2hex(sha256(read(path)))

function metric_module(filename, name)
    source = read(filename, String)
    first_function = findfirst("function bootstrap_acf_mae_se", source)
    next_section = findnext("# ── 4.", source, last(first_function))
    definitions = source[first(first_function):prevind(source, first(next_section))]
    mod = Module(name)
    Core.eval(mod, :(using Statistics, StatsBase, Distributions, HypothesisTests,
        Random, LinearAlgebra))
    for (key, value) in ((:_N_BOOT, N_BOOT), (:_L_ACF, 252), (:_ALPHA, 0.05),
                         (:_N_BINS, 50), (:_COV_QUANTILES, collect(0.01:0.01:0.99)))
        Core.eval(mod, :(const $key = $value))
    end
    Base.include_string(mod, definitions, filename)
    return Core.eval(mod, :compute_all_metrics)
end

function main()
    mkpath(OUTPUT_DIRECTORY)
    BLAS.set_num_threads(1)
    baseline = metric_module(joinpath(BASE, "Baseline-Comparison.jl"), :BaselineR8)
    neural = metric_module(joinpath(BASE, "Neural-Baseline-Evaluation.jl"), :NeuralR8)
    observations = Dict(
        "is" => Vector{Float64}(JLD2.load(joinpath(REPO,
            "code/spy-experiment/data/HMM-WJ-SPY-N-100-daily-aggregate.jld2"), "insampledataset")),
        "oos" => Vector{Float64}(JLD2.load(joinpath(REPO,
            "code/spy-experiment/data/OoS-Validation-SPY.jld2"), "g_oos")))
    paths = Dict(window => readdlm(joinpath(PATH_DIRECTORY, "gru_paths_$(window).csv"), ',', Float64)
        for window in ("is", "oos"))
    for (window, horizon) in (("is", 2766), ("oos", 249))
        @assert size(paths[window]) == (horizon, 1000)
        @assert all(isfinite, paths[window])
        @assert observations[window] == vec(readdlm(joinpath(NEURAL, "spy_$(window).csv"), ',', Float64))
    end

    # Both standalone scorers must agree on identical paths and bootstrap draws.
    tiny_obs, tiny_paths = observations["is"][1:80], paths["is"][1:80, 1:12]
    Random.seed!(20260915)
    a = Base.invokelatest(baseline, tiny_obs, tiny_paths; n_boot=20)
    Random.seed!(20260915)
    b = Base.invokelatest(neural, tiny_obs, tiny_paths; n_boot=20)
    @assert keys(a) == keys(b)
    @assert all(isapprox(a[key], b[key]; atol=1e-13, rtol=1e-13) for key in keys(a))

    # The explicit ACF uses the full-series mean and sum of squared deviations.
    z = abs.(tiny_obs) .- mean(abs.(tiny_obs))
    explicit = [sum(z[1:end-lag] .* z[1+lag:end])/sum(abs2, z) for lag in 1:79]
    @assert isapprox(explicit, autocor(abs.(tiny_obs), 1:79); atol=1e-14, rtol=1e-14)
    example = [0.4 0.0; 0.0 0.4]
    target = [0.2, 0.2]
    @assert mean(abs.(vec(mean(example; dims=2)) .- target)) == 0.0
    @assert mean(abs.(example .- target)) == 0.2
    @assert fit(Histogram, [0.0, 0.5, 1.0], range(0, 1; length=3)).weights == [1, 1]

    results = Dict{String,Any}()
    temporal_rows = NamedTuple[]
    # This is the seed and call order used by Neural-Baseline-Evaluation.jl.
    Random.seed!(1234)
    for window in ("is", "oos")
        obs, samples = observations[window], paths[window]
        @info "Re-scoring archived GRU paths" window size=size(samples)
        res = Base.invokelatest(neural, obs, samples)
        results[window] = Dict(string(k)=>v for (k,v) in pairs(res))
        for lag in (25, 60, min(252, length(obs)-1))
            reference = autocor(abs.(obs), 1:lag)
            curves = autocor(abs.(samples), 1:lag)
            ensemble_error = mean(abs.(vec(mean(curves; dims=2)) .- reference))
            per_path = vec(mean(abs.(curves .- reference); dims=1))
            @assert ensemble_error <= mean(per_path) + 1e-14
            if lag == min(252, length(obs)-1)
                @assert isapprox(ensemble_error, res.acf_mae; atol=1e-14)
            end
            push!(temporal_rows, (window=window, lags=lag, ensemble_acf_mae=ensemble_error,
                mean_path_acf_mae=mean(per_path), path_acf_mc_se=std(per_path)/sqrt(1000)))
        end
        @assert res.ks_se ≈ 100sqrt((res.ks_pass/100)*(1-res.ks_pass/100)/1000)
        @assert res.ad_se ≈ 100sqrt((res.ad_pass/100)*(1-res.ad_pass/100)/1000)
        path_kurt = [mean((samples[:,j] .- mean(samples[:,j])).^4) /
            mean((samples[:,j] .- mean(samples[:,j])).^2)^2 - 3 for j in 1:1000]
        @assert isapprox(res.kurt, mean(path_kurt); atol=1e-12)
        @assert isapprox(res.kurt_se, std(path_kurt)/sqrt(1000); atol=1e-12)
        path_w1 = [mean(abs.(sort(samples[:,j]) .- sort(obs))) for j in 1:1000]
        @assert isapprox(res.w1, mean(path_w1); atol=1e-13)
        @assert isapprox(res.w1_se, std(path_w1)/sqrt(1000); atol=1e-13)
        quantile_curves = hcat([quantile(samples[:,j], 0.01:0.01:0.99) for j in 1:1000]...)
        observed_quantiles = quantile(obs, 0.01:0.01:0.99)
        coverage_count = count(i -> quantile(quantile_curves[i,:], .05) <=
            observed_quantiles[i] <= quantile(quantile_curves[i,:], .95), 1:99)
        @assert res.coverage ≈ 100coverage_count/99
        results[window]["covered_quantile_levels"] = coverage_count
        println(window, ": ", res)
        flush(stdout)
    end
    open(joinpath(OUTPUT_DIRECTORY, "gru-metrics.csv"), "w") do io
        println(io, "window,metric,value")
        for window in ("is", "oos"), key in sort(collect(keys(results[window])))
            println(io, join((window,key,results[window][key]), ','))
        end
    end
    open(joinpath(OUTPUT_DIRECTORY, "acf-estimands.csv"), "w") do io
        println(io, join(string.(keys(first(temporal_rows))), ','))
        for row in temporal_rows
            println(io, join(values(row), ','))
        end
    end
    files = [@__FILE__, joinpath(BASE,"Baseline-Comparison.jl"),
        joinpath(BASE,"Neural-Baseline-Evaluation.jl"), joinpath(BASE,"Manifest.toml"),
        joinpath(NEURAL,"train_gru.py")]
    append!(files, [joinpath(NEURAL, f) for f in ("spy_is.csv","spy_oos.csv")])
    append!(files, [joinpath(PATH_DIRECTORY, f) for f in ("gru_paths_is.csv","gru_paths_oos.csv")])
    metadata = Dict("completed_utc"=>string(now(UTC))*"Z", "julia_version"=>string(VERSION),
        "protocol"=>"Rescore archived GRU paths; original metric definitions, seed 1234 and IS/OoS call order; no retraining",
        "bootstrap_replications"=>N_BOOT, "paths_per_window"=>1000,
        "checks"=>Dict("exported_observations_match_cached_vwap_series"=>true,
            "baseline_and_neural_scorers_agree"=>true,"acf_definition_matches_package"=>true,
            "ensemble_vs_pathwise_inequality"=>true,"maximum_histogram_endpoint_excluded"=>true,
            "kurtosis_wasserstein_pass_se_and_coverage_recomputed"=>true),
        "source_input_sha256"=>Dict(relpath(p,REPO)=>hashfile(p) for p in files),
        "package_versions"=>Dict(string(nameof(m))=>string(pkgversion(m)) for m in
            (StatsBase, HypothesisTests, Distributions, JLD2)),
        "results"=>results)
    open(joinpath(OUTPUT_DIRECTORY,"metric-metadata.toml"),"w") do io
        TOML.print(io,metadata; sorted=true)
    end
    @info "R8 metric checks passed"
end

main()
