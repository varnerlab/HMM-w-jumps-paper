# =============================================================================
# Copula-Comparison.jl
#
# Compares four dependence models for multi-asset synthetic data generation
# using JumpHMM.jl's PortfolioModel:
#   1. SingleIndexModel — linear factor (current paper approach)
#   2. GaussianCopula   — no tail dependence
#   3. StudentTCopula   — symmetric tail dependence
#   4. VineCopula       — heterogeneous per-pair dependence (C-vine)
#
# Portfolio: SPY (market), NVDA (high-beta tech), JNJ (low-beta health),
#            JPM (moderate-beta financials)
#
# Metrics:
#   - Per-ticker marginal KS/AD pass rates
#   - Pairwise correlation reproduction (MAE vs observed)
#   - Portfolio-level correlation matrix Frobenius norm error
#
# Outputs:
#   data/Copula-Comparison-Results.jld2
#   stdout — comparison tables
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const TICKERS  = ["SPY", "NVDA", "JNJ", "JPM"]
const _RF_IS   = 0.043
const _DT      = 1.0 / 252.0
const _N_PATHS = 1_000
const _ALPHA   = 0.05
const _N       = 100
const _DF      = 5.0

# ── 1. Load data ─────────────────────────────────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train = original_train["AAPL"] |> nrow

train_dataset = Dict{String,DataFrame}()
for (ticker, df) in original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end

# Verify all tickers present
for t in TICKERS
    @assert haskey(train_dataset, t) "Ticker $t not found in training data"
end

# Extract price matrix (VWAP) for our tickers
n_days = max_days_train
price_matrix = Matrix{Float64}(undef, n_days, length(TICKERS))
for (j, ticker) in enumerate(TICKERS)
    price_matrix[:, j] = train_dataset[ticker][!, :volume_weighted_average_price]
end

@info "  $(length(TICKERS)) tickers, $n_days trading days"

# Compute growth rates for metrics (via VLPackage)
tickers_train = keys(train_dataset) |> collect |> sort
all_growth = log_growth_matrix(train_dataset, tickers_train;
                 Δt = _DT, risk_free_rate = _RF_IS)

# Extract our ticker columns
ticker_indices = [findfirst(==(t), tickers_train) for t in TICKERS]
g_obs = all_growth[1:(n_days - 1), ticker_indices]  # (T-1) x 4
T_is = size(g_obs, 1)

@info "  IS observations: $T_is per ticker"
@info "  Observed correlation matrix:"
obs_corr = cor(g_obs)
display(round.(obs_corr, digits=3))

# ── 2. Fit and evaluate each dependence model ───────────────────────────────

dep_types = [
    ("SingleIndexModel", SingleIndexModel),
    ("GaussianCopula",   GaussianCopula),
    ("StudentTCopula",   StudentTCopula),
    ("VineCopula",       VineCopula),
]

results = Dict{String, Any}()

for (name, DepType) in dep_types
    println("\n" * "="^70)
    @info "Fitting PortfolioModel with $name..."
    println("="^70)

    # Fit portfolio model
    portfolio = JumpHMM.fit(PortfolioModel, TICKERS, price_matrix;
                            dependence = DepType,
                            market = "SPY",
                            rf = _RF_IS, N = _N, ν = _DF)

    # Tune jump parameters for each marginal
    @info "  Tuning portfolio..."
    portfolio = tune(portfolio, price_matrix)

    # Simulate
    @info "  Simulating $_N_PATHS paths of length $T_is..."
    sim_result = simulate(portfolio, T_is; n_paths = _N_PATHS, seed = 1234)

    # ── Marginal metrics per ticker ─────────────────────────────────────
    marginal_metrics = Dict{String, NamedTuple}()

    for (j, ticker) in enumerate(TICKERS)
        obs_j = g_obs[:, j]

        # Get simulated paths for this ticker
        if haskey(sim_result.results, ticker)
            sim_paths_j = hcat([p.observations for p in sim_result.results[ticker].paths]...)
        else
            @warn "  $ticker not in simulation results, skipping"
            continue
        end

        # KS/AD tests
        ks_pvals = [pvalue(ApproximateTwoSampleKSTest(obs_j, sim_paths_j[:, i]))
                    for i in 1:_N_PATHS]
        ad_pvals = [pvalue(KSampleADTest(obs_j, sim_paths_j[:, i]))
                    for i in 1:_N_PATHS]
        kurt_vals = [kurtosis(sim_paths_j[:, i]) for i in 1:_N_PATHS]

        ks_pass = mean(ks_pvals .> _ALPHA)
        ad_pass = mean(ad_pvals .> _ALPHA)

        marginal_metrics[ticker] = (
            ks_pass = 100.0 * ks_pass,
            ks_se   = 100.0 * sqrt(ks_pass * (1 - ks_pass) / _N_PATHS),
            ad_pass = 100.0 * ad_pass,
            ad_se   = 100.0 * sqrt(ad_pass * (1 - ad_pass) / _N_PATHS),
            kurt_obs = kurtosis(obs_j),
            kurt_sim = mean(kurt_vals),
            kurt_se  = std(kurt_vals) / sqrt(_N_PATHS),
        )
    end

    # ── Cross-asset correlation reproduction ────────────────────────────
    # For each simulated ensemble, compute correlation matrix and compare
    n_tickers = length(TICKERS)
    corr_errors = Vector{Float64}(undef, _N_PATHS)
    sim_corr_accum = zeros(n_tickers, n_tickers)

    for i in 1:_N_PATHS
        # Build simulated return matrix for path i
        sim_mat = Matrix{Float64}(undef, T_is, n_tickers)
        for (j, ticker) in enumerate(TICKERS)
            if haskey(sim_result.results, ticker)
                sim_mat[:, j] = sim_result.results[ticker].paths[i].observations
            end
        end
        sim_corr_i = cor(sim_mat)
        sim_corr_accum .+= sim_corr_i

        # Frobenius norm of correlation error (upper triangle only)
        err = 0.0
        for a in 1:n_tickers
            for b in (a+1):n_tickers
                err += (obs_corr[a, b] - sim_corr_i[a, b])^2
            end
        end
        corr_errors[i] = sqrt(err)
    end

    mean_sim_corr = sim_corr_accum ./ _N_PATHS
    frob_mae = mean(corr_errors)
    frob_se  = std(corr_errors) / sqrt(_N_PATHS)

    # Pairwise correlation MAE
    pair_mae = 0.0
    n_pairs = 0
    for a in 1:n_tickers
        for b in (a+1):n_tickers
            pair_mae += abs(obs_corr[a, b] - mean_sim_corr[a, b])
            n_pairs += 1
        end
    end
    pair_mae /= n_pairs

    # ── Store results ────────────────────────────────────────────────────
    results[name] = (
        marginal = marginal_metrics,
        obs_corr = obs_corr,
        sim_corr = mean_sim_corr,
        corr_frob = frob_mae,
        corr_frob_se = frob_se,
        pair_corr_mae = pair_mae,
    )

    # ── Print summary ────────────────────────────────────────────────────
    @info "  Marginal KS/AD pass rates:"
    for ticker in TICKERS
        haskey(marginal_metrics, ticker) || continue
        m = marginal_metrics[ticker]
        @printf("    %-6s  KS: %5.1f%% (%4.1f)  AD: %5.1f%% (%4.1f)  κ_obs: %5.1f  κ_sim: %5.1f (%4.2f)\n",
            ticker, m.ks_pass, m.ks_se, m.ad_pass, m.ad_se,
            m.kurt_obs, m.kurt_sim, m.kurt_se)
    end

    @info @sprintf("  Correlation Frobenius error: %.4f (%.4f)", frob_mae, frob_se)
    @info @sprintf("  Pairwise correlation MAE:   %.4f", pair_mae)
    @info "  Mean simulated correlation matrix:"
    display(round.(mean_sim_corr, digits=3))
end

# ── 3. Print comparison table ──────────────────────────────────────────────
println("\n\n" * "="^90)
println("  DEPENDENCE MODEL COMPARISON — $(join(TICKERS, ", "))")
println("  $_N_PATHS paths, $T_is steps, α=$_ALPHA")
println("="^90)

dep_names = [d[1] for d in dep_types]

# Marginal KS pass rates
println("\n  Marginal KS Pass Rates (%):")
@printf("  %-8s", "Ticker")
for name in dep_names; @printf("  %18s", name); end
println()
println("  " * "-"^(8 + 20 * length(dep_names)))
for ticker in TICKERS
    @printf("  %-8s", ticker)
    for name in dep_names
        r = results[name]
        if haskey(r.marginal, ticker)
            m = r.marginal[ticker]
            @printf("  %10.1f (%4.1f)", m.ks_pass, m.ks_se)
        else
            @printf("  %18s", "N/A")
        end
    end
    println()
end

# Correlation reproduction
println("\n  Cross-Asset Dependence Quality:")
@printf("  %-24s", "Metric")
for name in dep_names; @printf("  %18s", name); end
println()
println("  " * "-"^(24 + 20 * length(dep_names)))

@printf("  %-24s", "Corr Frobenius error")
for name in dep_names
    r = results[name]
    @printf("  %10.4f (%5.4f)", r.corr_frob, r.corr_frob_se)
end
println()

@printf("  %-24s", "Pairwise corr MAE")
for name in dep_names
    r = results[name]
    @printf("  %18.4f", r.pair_corr_mae)
end
println()

# Print observed vs simulated correlation for each model
println("\n  Observed correlation matrix:")
for (i, ti) in enumerate(TICKERS)
    @printf("    %-6s", ti)
    for j in 1:length(TICKERS)
        @printf("  %7.3f", obs_corr[i, j])
    end
    println()
end

for name in dep_names
    r = results[name]
    println("\n  Simulated correlation ($name):")
    for (i, ti) in enumerate(TICKERS)
        @printf("    %-6s", ti)
        for j in 1:length(TICKERS)
            @printf("  %7.3f", r.sim_corr[i, j])
        end
        println()
    end
end

println("\n" * "="^90)

# ── 4. Save results ───────────────────────────────────────────────────────
@info "Saving results..."
save(joinpath(_PATH_TO_DATA, "Copula-Comparison-Results.jld2"),
     Dict("results" => results, "tickers" => TICKERS,
          "obs_corr" => obs_corr, "T_is" => T_is))
@info "Done."
