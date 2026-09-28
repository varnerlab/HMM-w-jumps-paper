# Isolate the effect of subtracting a path mean versus a fitted generator mean.
# This diagnostic does not change production composition or result caches.
# Run from the repository root:
# julia --compiled-modules=existing --project=code/downstream-evaluation \
#   audits/2026-09-14-review/centering_probe.jl
using Statistics, LinearAlgebra, Random, Distributions, HypothesisTests
using JLD2, DataFrames, CSV, Printf, TOML, SHA
import JumpHMM

const REPO = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(REPO, "code/downstream-evaluation/src/Composers.jl"))
include(joinpath(REPO, "code/downstream-evaluation/src/Metrics.jl"))

function main()
    cfg = TOML.parsefile(joinpath(REPO, "code/downstream-evaluation/config.toml"))
    universe_file = joinpath(REPO, "code/downstream-evaluation/data/universe.jld2")
    calibration_file = joinpath(REPO, "code/downstream-evaluation/data/sim-calibration.jld2")
    universe = load(universe_file)
    calibration = load(calibration_file, "calibration")
    G, prices, tickers = universe["growth_rates"], universe["prices"], universe["tickers"]
    market_index = findfirst(==("SPY"), tickers)
    rows = NamedTuple[]
    diagnostics = NamedTuple[]
    n_paths = 1_000
    for (asset_number, ticker) in enumerate(("AAPL", "JNJ", "QQQ"))
        asset_index = findfirst(==(ticker), tickers)
        cal = only(eachrow(filter(row -> row.ticker == ticker, calibration)))
        model = JumpHMM.fit(JumpHMM.JumpHiddenMarkovModel, prices[:, asset_index];
            N=cfg["hmm"]["N"], ν=cfg["hmm"]["nu"], rf=cfg["hmm"]["risk_free_rate"],
            dt=cfg["hmm"]["dt"])
        @assert model.jump.ϵ == 0.0
        @assert norm(model.transition' * model.stationary - model.stationary, Inf) < 1e-8
        # With jumps off and a stationary start, this is the generator's
        # unconditional mean. It is not the general jump-process mean.
        generator_mean = dot(model.stationary, [emission.μ for emission in model.emissions])
        for T in (249, size(G, 1))
            gm = G[1:T, market_index]
            observed = G[1:T, asset_index]
            seed = 20260920 + 100 * asset_number + T
            draws = JumpHMM.simulate(model, T; n_paths, seed).paths
            for method in ("naive", "hybrid")
                centered_sums, fixed_sums = Float64[], Float64[]
                centered_ks, fixed_ks = Float64[], Float64[]
                centered_w1, fixed_w1 = Float64[], Float64[]
                centered_mean_error, fixed_mean_error = Float64[], Float64[]
                variance_error = 0.0
                beta_error = 0.0
                clipped = 0
                for path in draws
                    x = path.observations
                    if method == "naive"
                        g = compose_naive(cal.alpha, cal.beta, gm, x)
                        beta_eff, scale = cal.beta, 1.0
                    else
                        g, beta_eff, flag = compose_hybrid(cal.alpha, cal.beta, cal.r2_real,
                            gm, x, var(gm), var(x);
                            f=cfg["hybrid"]["idiosyncratic_floor"],
                            R²_threshold=cfg["hybrid"]["r2_preserve_threshold"])
                        clipped += flag == HYBRID_CLIPPED
                        residual = g .- cal.alpha .- beta_eff .* gm
                        scale = sqrt(var(residual) / var(x))
                    end
                    # Keep the actual path's scale, loading, and market fixed.
                    # Only replace the subtracted path mean by the fitted mean.
                    g_fixed = cal.alpha .+ beta_eff .* gm .+ scale .* (x .- generator_mean)
                    current_residual = g .- cal.alpha .- beta_eff .* gm
                    fixed_residual = g_fixed .- cal.alpha .- beta_eff .* gm
                    push!(centered_sums, sum(current_residual) / 252)
                    push!(fixed_sums, sum(fixed_residual) / 252)
                    variance_error = max(variance_error, abs(var(g_fixed) - var(g)))
                    beta_error = max(beta_error, abs(sim_recovery(g_fixed, gm)[2] - sim_recovery(g, gm)[2]))
                    # Full training-window fit only. Short-horizon runs use a
                    # fixed training-market prefix, not the 2025 holdout.
                    if T == size(G, 1)
                        push!(centered_ks, ks_pvalue(g, observed))
                        push!(fixed_ks, ks_pvalue(g_fixed, observed))
                        push!(centered_w1, wasserstein1(g, observed))
                        push!(fixed_w1, wasserstein1(g_fixed, observed))
                        push!(centered_mean_error, abs(mean(g) - mean(observed)))
                        push!(fixed_mean_error, abs(mean(g_fixed) - mean(observed)))
                    end
                end
                @assert maximum(abs, centered_sums) < 1e-10
                @assert variance_error < 1e-8 && beta_error < 1e-10
                push!(rows, (; ticker, T, method, n_paths, seed, generator_mean, clipped,
                    centered_terminal_residual_sd=std(centered_sums),
                    fixed_mean_terminal_residual_sd=std(fixed_sums),
                    maximum_variance_change=variance_error, maximum_beta_change=beta_error))
                @printf("%s %s T=%d: terminal residual log-return SD %.6g -> %.6f; clipped %d/%d\n",
                    ticker, method, T, std(centered_sums), std(fixed_sums), clipped, n_paths)
                if !isempty(centered_ks)
                    push!(diagnostics, (; ticker, method,
                        centered_ks_pass=100mean(centered_ks .> .05),
                        fixed_mean_ks_pass=100mean(fixed_ks .> .05),
                        centered_median_w1=median(centered_w1), fixed_mean_median_w1=median(fixed_w1),
                        centered_median_mean_error=median(centered_mean_error),
                        fixed_mean_median_mean_error=median(fixed_mean_error)))
                end
                flush(stdout)
            end
        end
    end
    CSV.write(joinpath(@__DIR__, "centering_terminal.csv"), DataFrame(rows))
    CSV.write(joinpath(@__DIR__, "centering_training.csv"), DataFrame(diagnostics))
    println("\nTraining comparison (three illustrative assets, not a universe-wide ranking):")
    show(stdout, MIME("text/plain"), DataFrame(diagnostics)); println()
    sources = [universe_file, calibration_file, @__FILE__, pathof(JumpHMM),
        joinpath(REPO, "code/downstream-evaluation/src/Composers.jl"),
        joinpath(REPO, "code/downstream-evaluation/src/Metrics.jl"),
        joinpath(REPO, "code/downstream-evaluation/config.toml"),
        joinpath(REPO, "code/downstream-evaluation/Manifest.toml")]
    metadata = Dict("julia_version" => string(VERSION), "n_paths" => n_paths,
        "scope" => "Three assets; jumps disabled; fixed observed training market; only centering differs",
        "production_changed" => false,
        "source_sha256" => Dict(relpath(p, REPO) => open(io -> bytes2hex(sha256(io)), p) for p in sources))
    open(joinpath(@__DIR__, "centering_metadata.toml"), "w") do io
        TOML.print(io, metadata; sorted=true)
    end
end

main()
