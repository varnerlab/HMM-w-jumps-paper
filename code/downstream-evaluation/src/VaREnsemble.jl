# Table 5 estimates the uniform-day marginal of separate finite-horizon
# constructions. Columns are paths; flattening is allowed only after composition.
const VAR_METHODS = ("naive", "gaussian", "hybrid", "residual_jumphmm",
                     "block_bootstrap", "garch_t")

function pooled_var_threshold(paths::AbstractMatrix{<:Real}, alpha::Real)
    size(paths, 1) > 1 && size(paths, 2) > 0 ||
        throw(ArgumentError("expected nonempty finite-horizon paths as columns"))
    all(isfinite, paths) || throw(ArgumentError("nonfinite simulated return"))
    return var_threshold(vec(paths), alpha)
end

# Disjoint integer seed ranges for phase, source, asset, and batch/path.
var_seed(seed, phase, source, asset, draw) =
    seed + phase * 10^12 + source * 10^10 + asset * 10^6 + draw

function var_market_paths(model, n, horizon, batch_size, seed, phase)
    paths = Matrix{Float64}(undef, horizon, n)
    for first in 1:batch_size:n
        last = min(n, first + batch_size - 1)
        sim = JumpHMM.simulate(model, horizon; n_paths=last-first+1,
            seed=var_seed(seed, phase, 1, 0, first))
        for (j, path) in enumerate(sim.paths)
            paths[:, first+j-1] = path.observations
        end
    end
    return paths
end

function var_asset_paths(cal, asset, models, residual_models, garch_models,
                         residual_history, market, market_variance, cfg, settings, phase)
    horizon, n = size(market)
    seed, batch_size = settings["seed"], settings["batch_size"]
    methods = haskey(garch_models, cal.ticker) ? VAR_METHODS : VAR_METHODS[1:5]
    paths = Dict(m => Matrix{Float64}(undef, horizon, n) for m in methods)
    for first in 1:batch_size:n
        last = min(n, first+batch_size-1)
        full = JumpHMM.simulate(models[cal.ticker], horizon; n_paths=last-first+1,
            seed=var_seed(seed, phase, 2, asset, first))
        resid = JumpHMM.simulate(residual_models[cal.ticker], horizon; n_paths=last-first+1,
            seed=var_seed(seed, phase, 3, asset, first))
        for (j, rep) in enumerate(first:last)
            gm = @view market[:, rep]
            draw = full.paths[j].observations
            paths["naive"][:, rep] = compose_naive(cal.alpha, cal.beta, gm, draw)
            paths["hybrid"][:, rep] = compose_hybrid(
                cal.alpha, cal.beta, cal.r2_real, gm, draw, market_variance, var(draw);
                f=cfg["hybrid"]["idiosyncratic_floor"],
                R²_threshold=cfg["hybrid"]["r2_preserve_threshold"])[1]
            paths["residual_jumphmm"][:, rep] = compose_residual_jumphmm(
                cal.alpha, cal.beta, gm, resid.paths[j].observations)
            paths["gaussian"][:, rep] = compose_gaussian_sim(
                cal.alpha, cal.beta, cal.sigma_eps_real, gm,
                MersenneTwister(var_seed(seed, phase, 4, asset, rep)))
            paths["block_bootstrap"][:, rep] = compose_block_bootstrap(
                cal.alpha, cal.beta, gm, residual_history,
                cfg["bootstrap"]["mean_block_length"],
                MersenneTwister(var_seed(seed, phase, 5, asset, rep)))
            if haskey(paths, "garch_t")
                draw_g = simulate_garch_residual(garch_models[cal.ticker], horizon;
                    rng=MersenneTwister(var_seed(seed, phase, 6, asset, rep)))
                paths["garch_t"][:, rep] = compose_garch_t(cal.alpha, cal.beta, gm, draw_g)
            end
        end
    end
    for draws in values(paths)
        draws .*= cfg["hmm"]["dt"]
        all(isfinite, draws) || error("nonfinite ensemble for $(cal.ticker)")
    end
    return paths
end

function summarize_var_calibration(calibration_paths, validation_paths, ticker, checkpoints)
    rows = NamedTuple[]
    for method in VAR_METHODS
        haskey(calibration_paths, method) || continue
        paths, check = calibration_paths[method], validation_paths[method]
        for n in checkpoints, alpha in (0.95, 0.99)
            threshold = pooled_var_threshold(@view(paths[:, 1:n]), alpha)
            rates = vec(mean(check .< -threshold; dims=1))
            push!(rows, (; ticker, composer=method, alpha_level=alpha, calibration_paths=n,
                horizon=size(paths,1), threshold, validation_rate=mean(rates),
                validation_mcse=std(rates)/sqrt(length(rates))))
        end
    end
    return DataFrame(rows)
end
