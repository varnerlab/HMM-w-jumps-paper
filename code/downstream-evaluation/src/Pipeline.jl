# =============================================================================
# Pipeline.jl
# Universe loading, fitting, and artifact I/O helpers. Delegates to
# VLQuantitativeFinancePackage for data and JumpHMM for model fitting.
# =============================================================================

"""
    load_config(path = _PATH_TO_CONFIG) → Dict

Read the experiment configuration TOML.
"""
function load_config(path::AbstractString = _PATH_TO_CONFIG)
    isfile(path) || throw(ArgumentError("config file not found: $path"))
    return TOML.parsefile(path)
end

"""
    load_universe(min_obs) → (tickers, prices)

Load the JDIQ training universe via VLQuantitativeFinancePackage and filter to
tickers whose history matches the maximum trading-day count in the dataset
(AAPL is used as the reference). The `min_obs` argument is enforced as a
lower bound on the resulting common length: if AAPL has fewer than `min_obs`
days, the function errors. Returns a sorted vector of ticker symbols and a
`(T × N)` price matrix in the same order.
"""
function load_universe(min_obs::Int)
    raw = MyTrainingMarketDataSet()["dataset"]
    max_days = raw["AAPL"] |> nrow
    max_days >= min_obs ||
        error("AAPL has $max_days days; expected at least $min_obs")
    @info "Universe scan: AAPL has $max_days trading days"

    keep = Dict{String,DataFrame}()
    for (ticker, df) in raw
        if nrow(df) == max_days
            keep[ticker] = df
        end
    end

    tickers = sort(collect(keys(keep)))
    prices  = Matrix{Float64}(undef, max_days, length(tickers))
    for (j, t) in enumerate(tickers)
        prices[:, j] = keep[t].close
    end

    @info "Universe loaded" n_assets = length(tickers) n_obs = max_days
    return tickers, prices
end

"""
    load_test_universe(min_obs) → (tickers, prices)

Load the held-out market dataset and retain tickers with the maximum common
price-history length. The returned prices are never used for fitting; they
are reserved for out-of-sample scoring.
"""
function load_test_universe(min_obs::Int)
    raw = MyTestingMarketDataSet()["dataset"]
    max_days = maximum(nrow(df) for df in values(raw))
    max_days >= min_obs ||
        error("test universe has at most $max_days days; expected at least $min_obs")

    tickers = sort([ticker for (ticker, df) in raw if nrow(df) == max_days])
    prices = Matrix{Float64}(undef, max_days, length(tickers))
    for (j, ticker) in enumerate(tickers)
        prices[:, j] = raw[ticker].close
    end

    @info "Test universe loaded" n_assets=length(tickers) n_obs=max_days
    return tickers, prices
end

"""
    resolve_data_artifact(filename) → path

Resolve a cached pipeline artifact. In this checkout the large fitted-model
artifacts may live beside the target of the tracked `universe.jld2` symlink;
that directory is searched after the local data directory.
"""
function resolve_data_artifact(filename::AbstractString)
    local_path = joinpath(_PATH_TO_DATA, filename)
    isfile(local_path) && return local_path

    anchor = joinpath(_PATH_TO_DATA, "universe.jld2")
    if ispath(anchor)
        sibling = joinpath(dirname(realpath(anchor)), filename)
        isfile(sibling) && return sibling
    end

    error("required pipeline artifact not found: $filename")
end

"""
    growth_rate_matrix(prices; rf, dt) → G

Annualized excess log growth rates from a `(T × N)` price matrix, matching
the JumpHMM convention `G_t = (1/dt) log(P_t / P_{t-1}) - rf`. Delegates to
`JumpHMM.excess_growth_rates` so the units are identical to the per-asset
HMM marginals fit downstream.
"""
function growth_rate_matrix(prices::AbstractMatrix{<:Real};
                            rf::Float64 = 0.0,
                            dt::Float64 = 1.0 / 252.0)
    return JumpHMM.excess_growth_rates(prices; rf = rf, dt = dt)
end

"""
    fit_per_ticker_marginals(prices, tickers; cfg) → Dict{String,JumpHiddenMarkovModel}

Fit a JumpHMM marginal for each ticker. Caches the result to
`data/marginals.jld2` so subsequent calls hit the cache.
"""
function fit_per_ticker_marginals(prices::AbstractMatrix{<:Real},
                                  tickers::Vector{String};
                                  cfg::Dict)
    cache = joinpath(_PATH_TO_DATA, "marginals.jld2")
    if isfile(cache)
        @info "Loading cached marginals from $cache"
        return load(cache)["marginals"]
    end

    rf = Float64(cfg["hmm"]["risk_free_rate"])
    N  = Int(cfg["hmm"]["N"])
    ν  = Float64(cfg["hmm"]["nu"])
    dt = Float64(cfg["hmm"]["dt"])

    marginals = Dict{String,JumpHiddenMarkovModel}()
    for (j, t) in enumerate(tickers)
        @info "Fitting marginal $j / $(length(tickers)): $t"
        marginals[t] = fit(JumpHiddenMarkovModel, prices[:, j];
                           rf = rf, N = N, ν = ν, dt = dt)
    end

    @info "Caching marginals to $cache"
    jldsave(cache; marginals = marginals)
    return marginals
end

"""
    calibrate_sim(G, tickers, market_ticker) → DataFrame

OLS regression per ticker of `G[:, i]` on `G[:, market_idx]`. Returns a
DataFrame with columns `ticker, alpha, beta, r2_real, sigma_eps_real,
sigma_gen` (the last is filled in later from the HMM marginal).
"""
function calibrate_sim(G::AbstractMatrix{<:Real},
                       tickers::Vector{String},
                       market_ticker::String)
    market_idx = findfirst(==(market_ticker), tickers)
    market_idx === nothing && throw(ArgumentError("market ticker not in universe"))
    G_m   = G[:, market_idx]
    G_m̄   = mean(G_m)
    G_m_v = var(G_m)

    n = length(tickers)
    df = DataFrame(
        ticker         = String[],
        alpha          = Float64[],
        beta           = Float64[],
        r2_real        = Float64[],
        sigma_eps_real = Float64[],
    )

    for i in 1:n
        t = tickers[i]
        if t == market_ticker
            continue
        end
        G_i  = G[:, i]
        G_ī  = mean(G_i)
        β    = cov(G_i, G_m) / G_m_v
        α    = G_ī - β * G_m̄
        resid = G_i .- α .- β .* G_m
        σ_ε  = std(resid)
        SS_r = dot(resid, resid)
        SS_t = sum(abs2, G_i .- G_ī)
        r²   = SS_t > 0.0 ? 1.0 - SS_r / SS_t : 0.0
        push!(df, (t, α, β, r², σ_ε))
    end
    return df
end

"""
    run_composer_experiment(cfg; kwargs...) → DataFrame

Central composition + scoring loop, parameterized so seed sweeps
(Workstream C1), sensitivity sweeps (C2), and stress evaluation (C3)
can call it with different settings without duplicating the loop body.

Keyword arguments (all optional, defaults from `cfg`):

* `seed`               — base RNG seed (default `cfg["simulation"]["seed"]`).
* `f`                  — idiosyncratic-variance floor for the hybrid composer.
* `R²_threshold`       — branch-selection threshold.
* `include_composers`  — `Set{String}` of composers to evaluate (any subset of
  `{"naive","gaussian","hybrid","residual_jumphmm","block_bootstrap","garch_t"}`).
* `gm_factor`          — multiplicative scale on the real market path (1.0 =
  real SPY; 2.0 / 3.0 trigger clipping — see `SyntheticMarket.scale_market`).
* `output_suffix`      — string appended to `results` filenames; use
  e.g. `"-seed-2345"` for seed sweeps, `""` for the default run.
* `persist`            — if `false`, return the DataFrame without writing JLD2/CSV.
"""
function run_composer_experiment(cfg::Dict;
        seed::Integer               = Int(cfg["simulation"]["seed"]),
        f::Real                     = Float64(cfg["hybrid"]["idiosyncratic_floor"]),
        R²_threshold::Real          = Float64(cfg["hybrid"]["r2_preserve_threshold"]),
        include_composers::Set      = Set(["naive","gaussian","hybrid",
                                           "residual_jumphmm","block_bootstrap","garch_t"]),
        gm_factor::Real             = 1.0,
        output_suffix::AbstractString = "",
        persist::Bool               = true)

    market_ticker = cfg["universe"]["market_ticker"]
    n_paths       = Int(cfg["simulation"]["n_paths"])
    block_length  = Float64(get(get(cfg, "bootstrap", Dict()),
                                "mean_block_length", 50))

    ud = load(joinpath(_PATH_TO_DATA, "universe.jld2"))
    md = load(joinpath(_PATH_TO_DATA, "marginals.jld2"))
    cd = load(joinpath(_PATH_TO_DATA, "sim-calibration.jld2"))

    tickers   = ud["tickers"]
    G         = ud["growth_rates"]
    marginals = md["marginals"]
    calib     = cd["calibration"]

    market_idx = findfirst(==(market_ticker), tickers)
    G_m_real   = G[:, market_idx]
    G_m        = gm_factor == 1.0 ? G_m_real : scale_market(G_m_real, gm_factor)
    σ²_m       = var(G_m)
    T_eff      = length(G_m)

    residual_cache = joinpath(_PATH_TO_DATA, "marginals-residuals.jld2")
    marginals_resid = ("residual_jumphmm" in include_composers && isfile(residual_cache)) ?
        load(residual_cache)["marginals"] : nothing

    garch_cache = joinpath(_PATH_TO_DATA, "garch-t-models.jld2")
    garch_models = ("garch_t" in include_composers && isfile(garch_cache)) ?
        load(garch_cache)["models"] : nothing

    @info "run_composer_experiment" seed=seed f=f R²_threshold=R²_threshold gm_factor=gm_factor composers=collect(include_composers) suffix=output_suffix

    Random.seed!(seed)
    rows = NamedTuple[]

    function record!(ticker, composer, rep, β_eff, flag, metrics)
        push!(rows, merge(
            (ticker = ticker, composer = composer, rep = rep,
             beta_eff = β_eff, flag = flag, seed = seed,
             f = f, r2_threshold = R²_threshold, gm_factor = gm_factor),
            metrics))
    end

    for (i, row) in enumerate(eachrow(calib))
        ticker = row.ticker
        α, β   = row.alpha, row.beta
        R²     = row.r2_real
        σ_εr   = row.sigma_eps_real

        asset_idx = findfirst(==(ticker), tickers)
        G_real    = G[:, asset_idx]  # real per-asset growth rates stay the same
                                     # under gm_factor != 1 (only g_m is scaled)
        model = marginals[ticker]
        sim_result = simulate(model, T_eff; n_paths = n_paths, seed = seed + i)

        sim_resid = marginals_resid === nothing ? nothing :
            simulate(marginals_resid[ticker], T_eff;
                     n_paths = n_paths, seed = seed + i + 1_000_000)
        real_residuals = G_real .- α .- β .* G_m_real

        for r in 1:n_paths
            ε̃    = Float64.(sim_result.paths[r].observations)
            σ²_g = var(ε̃)

            if "naive" in include_composers
                g = compose_naive(α, β, G_m, ε̃)
                record!(ticker, "naive", r, β, string(NAIVE),
                        score_asset(g, G_real, G_m))
            end
            if "gaussian" in include_composers
                g = compose_gaussian_sim(α, β, σ_εr, G_m, Random.default_rng())
                record!(ticker, "gaussian", r, β, string(GAUSSIAN_SIM),
                        score_asset(g, G_real, G_m))
            end
            if "hybrid" in include_composers
                g, β_eff, flag = compose_hybrid(α, β, R², G_m, ε̃, σ²_m, σ²_g;
                                                 f = f, R²_threshold = R²_threshold)
                record!(ticker, "hybrid", r, β_eff, string(flag),
                        score_asset(g, G_real, G_m))
            end
            if "residual_jumphmm" in include_composers && sim_resid !== nothing
                ε̃_r = Float64.(sim_resid.paths[r].observations)
                g = compose_residual_jumphmm(α, β, G_m, ε̃_r)
                record!(ticker, "residual_jumphmm", r, β, string(RESIDUAL_JUMPHMM),
                        score_asset(g, G_real, G_m))
            end
            if "block_bootstrap" in include_composers
                rng_b = MersenneTwister(seed + i * 1_000_000 + r * 1_000 + 1)
                g = compose_block_bootstrap(α, β, G_m, real_residuals, block_length, rng_b)
                record!(ticker, "block_bootstrap", r, β, string(BLOCK_BOOTSTRAP),
                        score_asset(g, G_real, G_m))
            end
            if "garch_t" in include_composers && garch_models !== nothing &&
                    haskey(garch_models, ticker)
                ε̃_g = Float64.(ARCHModels.simulate(garch_models[ticker], T_eff).data)
                g = compose_garch_t(α, β, G_m, ε̃_g)
                record!(ticker, "garch_t", r, β, string(GARCH_T),
                        score_asset(g, G_real, G_m))
            end
        end
    end

    results = DataFrame(rows)
    if persist
        jld = joinpath(_PATH_TO_DATA, "results$(output_suffix).jld2")
        csv = joinpath(_PATH_TO_DATA, "results$(output_suffix).csv")
        jldsave(jld; results = results, config = cfg, seed = seed,
                f = f, R²_threshold = R²_threshold, gm_factor = gm_factor)
        CSV.write(csv, results)
        @info "Persisted" jld=jld csv=csv rows=nrow(results)
    end
    return results
end

"""
    run_oos_composer_experiment(cfg; persist=true) → DataFrame

Evaluate all available composition methods on the frozen 2014--2024 fits
against the 249-growth-rate 2025 holdout. The market and asset paths are
generated from the training-period models; observed 2025 SPY is used only to
estimate the realized holdout factor loading used for scoring.

Alongside the holdout metrics, each synthetic path is compared with a
random contiguous training block of the same length. These matched-length
metrics separate genuine distribution shift from the lower power of KS/AD
tests on a 249-observation sample.
"""
function run_oos_composer_experiment(cfg::Dict; persist::Bool = true)
    market_ticker = cfg["universe"]["market_ticker"]
    n_paths       = Int(cfg["simulation"]["n_paths"])
    seed          = Int(cfg["simulation"]["seed"])
    f             = Float64(cfg["hybrid"]["idiosyncratic_floor"])
    R²_threshold  = Float64(cfg["hybrid"]["r2_preserve_threshold"])
    block_length  = Float64(get(get(cfg, "bootstrap", Dict()),
                                "mean_block_length", 50))
    dt            = Float64(cfg["hmm"]["dt"])

    ud = load(resolve_data_artifact("universe.jld2"))
    md = load(resolve_data_artifact("marginals.jld2"))
    cd = load(resolve_data_artifact("sim-calibration.jld2"))
    tickers_train = ud["tickers"]
    G_train       = ud["growth_rates"]
    marginals     = md["marginals"]
    calib         = cd["calibration"]

    tickers_test, prices_test = load_test_universe(250)
    G_test = growth_rate_matrix(prices_test; rf = 0.0, dt = dt)
    T_oos  = size(G_test, 1)

    test_index  = Dict(t => i for (i, t) in enumerate(tickers_test))
    train_index = Dict(t => i for (i, t) in enumerate(tickers_train))
    common = Set(intersect(tickers_test, tickers_train))
    keep_calib = filter(row -> row.ticker in common && haskey(marginals, row.ticker), calib)

    market_test_idx = get(test_index, market_ticker, 0)
    market_train_idx = get(train_index, market_ticker, 0)
    market_test_idx > 0 || error("$market_ticker absent from test universe")
    market_train_idx > 0 || error("$market_ticker absent from training universe")
    G_m_test  = G_test[:, market_test_idx]
    G_m_train = G_train[:, market_train_idx]
    σ²_m_train = var(G_m_train)

    residual_path = resolve_data_artifact("marginals-residuals.jld2")
    garch_path    = resolve_data_artifact("garch-t-models.jld2")
    marginals_resid = load(residual_path)["marginals"]
    garch_models    = load(garch_path)["models"]

    market_sim = simulate(marginals[market_ticker], T_oos;
                          n_paths = n_paths, seed = seed + 9_000_000)
    market_paths = [Float64.(p.observations) for p in market_sim.paths]

    max_start = size(G_train, 1) - T_oos + 1
    max_start > 0 || error("training window is shorter than holdout")
    block_rng = MersenneTwister(seed + 8_000_000)
    matched_starts = rand(block_rng, 1:max_start, n_paths)

    @info "OoS composer evaluation" n_tickers=nrow(keep_calib) T_oos=T_oos n_paths=n_paths
    rows = NamedTuple[]

    function record_oos!(ticker, composer, rep, β_eff, flag, g, G_real,
                         G_train_block, G_m_sim, β_oos, R²_oos)
        metrics = score_asset(g, G_real, G_m_sim)
        bt95 = var_backtest(one_day_returns(g, dt), one_day_returns(G_real, dt), 0.95)
        bt99 = var_backtest(one_day_returns(g, dt), one_day_returns(G_real, dt), 0.99)
        push!(rows, merge(
            (ticker = ticker, composer = composer, rep = rep,
             beta_eff = β_eff, flag = flag, seed = seed,
             beta_oos_real = β_oos, r2_oos_real = R²_oos,
             ks_p_is_matched = ks_pvalue(g, G_train_block),
             ad_p_is_matched = ad_pvalue(g, G_train_block),
             w1_is_matched = wasserstein1(g, G_train_block),
             var_ratio_oos = var(g) / max(var(G_real), 1e-30),
             kurt_error_oos = abs(excess_kurtosis(g) - excess_kurtosis(G_real)),
             var95_rate = bt95.rate, var95_kupiec_p = bt95.kupiec_p,
             var99_rate = bt99.rate, var99_kupiec_p = bt99.kupiec_p),
            metrics))
    end

    for (i, row) in enumerate(eachrow(keep_calib))
        ticker = row.ticker
        α, β, R², σ_εr = row.alpha, row.beta, row.r2_real, row.sigma_eps_real
        G_real = G_test[:, test_index[ticker]]
        G_train_i = G_train[:, train_index[ticker]]
        _, β_oos, R²_oos = sim_recovery(G_real, G_m_test)
        real_residuals = G_train_i .- α .- β .* G_m_train

        sim_full = simulate(marginals[ticker], T_oos;
                            n_paths = n_paths, seed = seed + i)
        sim_resid = haskey(marginals_resid, ticker) ?
            simulate(marginals_resid[ticker], T_oos;
                     n_paths = n_paths, seed = seed + i + 1_000_000) : nothing

        if i == 1 || i % 25 == 0
            @info "OoS ticker $i / $(nrow(keep_calib)): $ticker"
        end

        for rep in 1:n_paths
            G_m_sim = market_paths[rep]
            start = matched_starts[rep]
            G_train_block = @view G_train_i[start:(start + T_oos - 1)]
            ε̃ = Float64.(sim_full.paths[rep].observations)
            σ²_g = var(ε̃)

            g = compose_naive(α, β, G_m_sim, ε̃)
            record_oos!(ticker, "naive", rep, β, string(NAIVE), g,
                         G_real, G_train_block, G_m_sim, β_oos, R²_oos)

            rng_g = MersenneTwister(seed + i * 2_000_000 + rep * 2_000 + 1)
            g = compose_gaussian_sim(α, β, σ_εr, G_m_sim, rng_g)
            record_oos!(ticker, "gaussian", rep, β, string(GAUSSIAN_SIM), g,
                         G_real, G_train_block, G_m_sim, β_oos, R²_oos)

            g, β_eff, flag = compose_hybrid(α, β, R², G_m_sim, ε̃,
                                             σ²_m_train, σ²_g;
                                             f = f, R²_threshold = R²_threshold)
            record_oos!(ticker, "hybrid", rep, β_eff, string(flag), g,
                         G_real, G_train_block, G_m_sim, β_oos, R²_oos)

            if sim_resid !== nothing
                ε̃_r = Float64.(sim_resid.paths[rep].observations)
                g = compose_residual_jumphmm(α, β, G_m_sim, ε̃_r)
                record_oos!(ticker, "residual_jumphmm", rep, β,
                             string(RESIDUAL_JUMPHMM), g, G_real,
                             G_train_block, G_m_sim, β_oos, R²_oos)
            end

            rng_b = MersenneTwister(seed + i * 3_000_000 + rep * 3_000 + 1)
            g = compose_block_bootstrap(α, β, G_m_sim, real_residuals,
                                        block_length, rng_b)
            record_oos!(ticker, "block_bootstrap", rep, β,
                         string(BLOCK_BOOTSTRAP), g, G_real,
                         G_train_block, G_m_sim, β_oos, R²_oos)

            if haskey(garch_models, ticker)
                Random.seed!(seed + i * 4_000_000 + rep * 4_000 + 1)
                ε̃_g = Float64.(ARCHModels.simulate(garch_models[ticker], T_oos).data)
                g = compose_garch_t(α, β, G_m_sim, ε̃_g)
                record_oos!(ticker, "garch_t", rep, β, string(GARCH_T), g,
                             G_real, G_train_block, G_m_sim, β_oos, R²_oos)
            end
        end
    end

    results = DataFrame(rows)
    if persist
        out_jld = joinpath(_PATH_TO_DATA, "results-oos.jld2")
        out_csv = joinpath(_PATH_TO_DATA, "results-oos.csv")
        jldsave(out_jld; results=results, config=cfg, T_oos=T_oos,
                tickers=unique(results.ticker), matched_starts=matched_starts)
        CSV.write(out_csv, results)
        @info "Persisted OoS results" jld=out_jld csv=out_csv rows=nrow(results)
    end
    return results
end
