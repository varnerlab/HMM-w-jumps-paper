# Compare the old and corrected Laplace estimators using the existing Table 2
# metrics. Run from any directory with:
# julia --compiled-modules=existing --project=code/baseline-comparison \
#   audits/2026-09-14-review/laplace-correction/compare_laplace.jl
using DataFrames, Distributions, HypothesisTests, JLD2, LinearAlgebra
using Statistics, StatsBase, Random, Printf, SHA, TOML, Dates

const REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
const N_PATHS = 1_000
const N_BOOT = 500
const SEED_IS = 20260914
const SEED_OOS = 20260915
const BOOT_SEED = 20260916
const METRICS = [
    (:ks_pass, :ks_se, "KS pass (%)"),
    (:ad_pass, :ad_se, "AD pass (%)"),
    (:kurt, :kurt_se, "Excess kurtosis"),
    (:acf_mae, :acf_se, "ACF-MAE"),
    (:coverage, :coverage_se, "Coverage (%)"),
    (:w1, :w1_se, "Wasserstein-1"),
    (:hellinger, :hellinger_se, "Hellinger"),
    (:novelty, :novelty_se, "Novelty"),
    (:diversity, :diversity_se, "Diversity"),
]

file_hash(path) = open(io -> bytes2hex(sha256(io)), path)

function metric_module(path, name, observations)
    source = read(path, String)
    # Load the unchanged metric definitions directly from production source.
    # Exclude top-level fitting, tuning, simulation, and cache writes.
    first_function = findfirst("function bootstrap_acf_mae_se", source)
    next_section = findnext("# ── 4.", source, last(first_function))
    metric_source = source[first(first_function):prevind(source, first(next_section))]
    mod = Module(name)
    Core.eval(mod, :(using Statistics, StatsBase, Distributions, HypothesisTests,
                           Random, LinearAlgebra))
    Core.eval(mod, :(const _N_BOOT = $N_BOOT))
    Core.eval(mod, :(const _L_ACF = 252))
    Core.eval(mod, :(const _ALPHA = 0.05))
    Core.eval(mod, :(const _N_BINS = 50))
    Core.eval(mod, :(const _COV_QUANTILES = collect(0.01:0.01:0.99)))
    Base.include_string(mod, metric_source, path)

    # Exercise the actual corrected fit and sampling expressions in each script.
    lines = split(source, '\n')
    fit_line = only(filter(line -> startswith(line, "laplace_fit ="), lines))
    generator_line = only(filter(line -> startswith(line, "laplace_gen(T)"), lines))
    Core.eval(mod, :(insample_obs = $observations))
    Base.include_string(mod, fit_line * "\n" * generator_line, path)
    return (laplace_fit=Core.eval(mod, :laplace_fit),
            laplace_gen=Core.eval(mod, :laplace_gen),
            compute_all_metrics=Core.eval(mod, :compute_all_metrics))
end

function raw_spy_observations(path, risk_free_rate)
    dataset = JLD2.load(path, "dataset")
    prices = dataset["SPY"][!, :volume_weighted_average_price]
    @assert length(prices) == nrow(dataset["AAPL"])
    # Same arithmetic and VWAP column as VLQuantitativeFinancePackage's
    # log_growth_matrix, without loading unrelated optimization dependencies.
    return [(1 / (1 / 252)) * log(prices[i] / prices[i-1]) - risk_free_rate
            for i in 2:length(prices)]
end

function main()
    started = string(now(UTC)) * "Z"
    BLAS.set_num_threads(1)
    baseline_script = joinpath(REPO, "code/baseline-comparison/Baseline-Comparison.jl")
    student_script = joinpath(REPO, "code/spy-experiment/Table2-StudentT-Emissions.jl")
    train_cache = joinpath(REPO, "code/spy-experiment/data/HMM-WJ-SPY-N-100-daily-aggregate.jld2")
    test_cache = joinpath(REPO, "code/spy-experiment/data/OoS-Validation-SPY.jld2")
    package_src = dirname(Base.find_package("VLQuantitativeFinancePackage"))
    raw_train = joinpath(package_src, "data/SP500-Daily-OHLC-1-3-2014-to-12-31-2024.jld2")
    raw_test = joinpath(package_src, "data/SP500-Daily-OHLC-1-2-2025-to-12-31-2025.jld2")
    obs_is = Vector{Float64}(JLD2.load(train_cache, "insampledataset"))
    obs_oos = Vector{Float64}(JLD2.load(test_cache, "g_oos"))
    @assert obs_is == raw_spy_observations(raw_train, 0.043)
    @assert obs_oos == raw_spy_observations(raw_test, 0.0421)
    @assert length(obs_is) == 2766 && length(obs_oos) == 249

    baseline = metric_module(baseline_script, :BaselineMetrics, obs_is)
    student = metric_module(student_script, :StudentTMetrics, obs_is)
    old_fit = Laplace(mean(obs_is), mean(abs.(obs_is .- mean(obs_is))))
    new_fit = baseline.laplace_fit
    @assert params(new_fit) == params(student.laplace_fit)
    @assert location(new_fit) == median(obs_is)
    @assert scale(new_fit) == mean(abs.(obs_is .- median(obs_is)))
    @assert sum(logpdf.(new_fit, obs_is)) > sum(logpdf.(old_fit, obs_is))
    for mod in (baseline, student)
        Random.seed!(1234)
        actual = Base.invokelatest(mod.laplace_gen, 100)
        Random.seed!(1234)
        @assert actual == rand(new_fit, 100)
    end

    # Check that the two production metric implementations agree on a common
    # input before using the baseline version for the full paired comparison.
    small_obs = obs_is[1:80]
    small_paths = rand(MersenneTwister(42), new_fit, 80, 12)
    Random.seed!(BOOT_SEED)
    a = Base.invokelatest(baseline.compute_all_metrics, small_obs, small_paths)
    Random.seed!(BOOT_SEED)
    b = Base.invokelatest(student.compute_all_metrics, small_obs, small_paths)
    @assert keys(a) == keys(b)
    @assert all(isapprox(a[k], b[k]; atol=1e-12, rtol=1e-12) for k in keys(a))

    println("Julia ", VERSION, "; Distributions ", pkgversion(Distributions))
    println("Training: ", length(obs_is), "; holdout: ", length(obs_oos))
    println("Both cached observation vectors exactly match raw VWAP-derived observations.")
    println("Old fit: ", old_fit, "; corrected MLE: ", new_fit)
    println("Training log-likelihood gain: ", sum(logpdf.(new_fit, obs_is)) - sum(logpdf.(old_fit, obs_is)))
    println("Both production fit/sampling expressions and metric implementations passed checks.")
    println("Paired uniforms; ", N_PATHS, " paths per fit/window; ", N_BOOT, " bootstrap replicates.")
    flush(stdout)

    results = Dict{String,Any}()
    for (window, obs, seed) in (("IS", obs_is, SEED_IS), ("OoS", obs_oos, SEED_OOS))
        uniforms = rand(MersenneTwister(seed), length(obs), N_PATHS)
        by_fit = Dict{String,Any}()
        for (label, distribution) in (("old", old_fit), ("mle", new_fit))
            println("Scoring ", window, " ", label, " at ", now())
            flush(stdout)
            paths = quantile.(distribution, uniforms)
            # Identical bootstrap resamples pair the uncertainty calculations.
            Random.seed!(BOOT_SEED + (window == "OoS"))
            metrics = Base.invokelatest(baseline.compute_all_metrics, obs, paths)
            @assert all(isfinite, values(metrics))
            by_fit[label] = metrics
            for (key, se_key, title) in METRICS
                @printf("  %-18s %.9f (SE %.9f)\n", title, metrics[key], metrics[se_key])
            end
            flush(stdout)
        end
        results[window] = by_fit
    end

    metadata = Dict(
        "started_utc" => started, "finished_utc" => string(now(UTC)) * "Z",
        "julia_version" => string(VERSION), "threads" => Threads.nthreads(),
        "blas_threads" => BLAS.get_num_threads(), "n_paths" => N_PATHS, "n_boot" => N_BOOT,
        "is_seed" => SEED_IS, "oos_seed" => SEED_OOS, "bootstrap_seed" => BOOT_SEED,
        "is_observations" => length(obs_is), "oos_observations" => length(obs_oos),
        "is_observed_kurtosis" => kurtosis(obs_is), "oos_observed_kurtosis" => kurtosis(obs_oos),
        "old_location" => location(old_fit), "old_scale" => scale(old_fit),
        "mle_location" => location(new_fit), "mle_scale" => scale(new_fit),
        "sampler" => "Matched uniforms transformed with each fitted Laplace quantile function",
        "metrics" => "Unchanged production Table 2 metrics, including existing Hellinger convention",
        "checks" => Dict("raw_data_matches_caches" => true, "both_production_fits_checked" => true,
                         "both_production_samplers_checked" => true, "metric_implementations_agree" => true,
                         "mle_improves_training_likelihood" => true),
        "package_versions" => Dict(string(nameof(m)) => string(pkgversion(m))
                                   for m in (DataFrames, Distributions, HypothesisTests, JLD2, StatsBase)),
        "source_sha256" => Dict(relpath(p, REPO) => file_hash(p)
                                for p in (baseline_script, student_script, train_cache, test_cache,
                                          raw_train, raw_test, joinpath(package_src, "Base.jl"),
                                          joinpath(REPO, "code/baseline-comparison/Manifest.toml"), @__FILE__)),
    )
    open(joinpath(@__DIR__, "metadata.toml"), "w") do io
        TOML.print(io, metadata; sorted=true)
    end
    jldsave(joinpath(@__DIR__, "results.jld2"); results, metadata)
    open(joinpath(@__DIR__, "comparison.csv"), "w") do io
        println(io, "window,metric,old,old_se,mle,mle_se,change")
        for window in ("IS", "OoS"), (key, se_key, _) in METRICS
            old, mle = results[window]["old"], results[window]["mle"]
            println(io, join((window, key, old[key], old[se_key], mle[key], mle[se_key], mle[key] - old[key]), ','))
        end
    end
    println("Saved paired results, all metrics, and provenance under ", @__DIR__)
end

main()
