# =============================================================================
# Multi-Ticker-Evaluation.jl
#
# Uses JumpHMM.jl to build HMM-NJ and HMM-WJ for each ticker in TICKERS,
# tunes jump parameters, then evaluates 1,000 simulated paths using
# KS, AD, excess kurtosis, and ACF-MAE (with SEs).
#
# Tickers:
#   NVDA — high-beta tech (Information Technology)
#   JNJ  — low-beta defensive (Health Care)
#   JPM  — moderate-high beta financials (Financials)
#
# Outputs:
#   data/Multi-Ticker-Results.jld2
# =============================================================================

include("Include.jl")

# ── Configuration ─────────────────────────────────────────────────────────────
const TICKERS  = ["NVDA", "JNJ", "JPM"]
const _N       = 100
const _N_PATHS = 1_000
const _L_ACF   = 252
const _ALPHA   = 0.05
const _N_BOOT  = 500
const _N_TAIL  = 5
const _P_NEG   = 0.52
const _DF      = 5.0
const _RF_IS   = 0.043
const _RF_OOS  = 0.0421
const _DT      = 1.0 / 252.0

# ── 1. Load data ──────────────────────────────────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train = original_train["AAPL"] |> nrow

train_dataset = Dict{String,DataFrame}()
for (ticker, df) in original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end
tickers_train = keys(train_dataset) |> collect |> sort

all_growth_train = log_growth_matrix(train_dataset, tickers_train;
                       Δt = _DT, risk_free_rate = _RF_IS)

@info "Loading testing data..."
original_test = MyTestingMarketDataSet() |> x -> x["dataset"]
max_days_test = original_test["AAPL"] |> nrow

test_dataset = Dict{String,DataFrame}()
for (ticker, df) in original_test
    nrow(df) == max_days_test && (test_dataset[ticker] = df)
end
tickers_test = keys(test_dataset) |> collect |> sort

all_growth_test = log_growth_matrix(test_dataset, tickers_test;
                      Δt = _DT, risk_free_rate = _RF_OOS)

# ── 2. Helper: bootstrap SE for ACF-MAE ──────────────────────────────────────
function bootstrap_acf_mae_se(acf_mat::Matrix{Float64}, obs_acf::Vector{Float64};
                               n_boot::Int = _N_BOOT)
    n_paths = size(acf_mat, 2)
    boot_mae = Vector{Float64}(undef, n_boot)
    for b in 1:n_boot
        idx = rand(1:n_paths, n_paths)
        mean_acf_b = vec(mean(acf_mat[:, idx], dims = 2))
        boot_mae[b] = mean(abs.(obs_acf .- mean_acf_b))
    end
    return std(boot_mae)
end

# ── 3. Helper: compute all metrics with SEs ───────────────────────────────────
function compute_metrics(obs::Vector{Float64}, paths::Matrix{Float64})
    n_paths = size(paths, 2)
    L = min(_L_ACF, length(obs) - 1)
    lags = collect(1:L)
    obs_acf = autocor(abs.(obs), lags)

    ks_pvals  = Vector{Float64}(undef, n_paths)
    ad_pvals  = Vector{Float64}(undef, n_paths)
    kurt_vals = Vector{Float64}(undef, n_paths)
    acf_mat   = Matrix{Float64}(undef, L, n_paths)

    Threads.@threads for i in 1:n_paths
        sim = paths[:, i]
        ks_pvals[i]   = pvalue(ApproximateTwoSampleKSTest(obs, sim))
        ad_pvals[i]   = pvalue(KSampleADTest(obs, sim))
        kurt_vals[i]  = kurtosis(sim)
        acf_mat[:, i] = autocor(abs.(sim), lags)
    end

    ks_pass  = mean(ks_pvals .> _ALPHA)
    ad_pass  = mean(ad_pvals .> _ALPHA)
    kurt_m   = mean(kurt_vals)
    mean_acf = vec(mean(acf_mat, dims = 2))
    acf_mae  = mean(abs.(obs_acf .- mean_acf))

    ks_se   = sqrt(ks_pass * (1 - ks_pass) / n_paths)
    ad_se   = sqrt(ad_pass * (1 - ad_pass) / n_paths)
    kurt_se = std(kurt_vals) / sqrt(n_paths)
    mae_se  = bootstrap_acf_mae_se(acf_mat, obs_acf)

    return (
        ks_pass = 100.0 * ks_pass, ks_se = 100.0 * ks_se,
        ad_pass = 100.0 * ad_pass, ad_se = 100.0 * ad_se,
        kurt    = kurt_m,          kurt_se = kurt_se,
        acf_mae = acf_mae,         acf_mae_se = mae_se,
    )
end

# ── 4. Main loop over tickers ────────────────────────────────────────────────
results = Dict{String, Any}()

for ticker in TICKERS
    println("\n" * "="^80)
    @info "Processing $ticker..."
    println("="^80)

    # --- Find ticker in training data ---
    idx_train = findfirst(==(ticker), tickers_train)
    if idx_train === nothing
        @warn "  $ticker not found in training data, skipping"
        continue
    end
    g_is = all_growth_train[1:(max_days_train - 1), idx_train]
    T_is = length(g_is)

    # Extract prices for JumpHMM fit
    prices_is = train_dataset[ticker][!, :volume_weighted_average_price]

    # --- Find ticker in testing data ---
    idx_test = findfirst(==(ticker), tickers_test)
    g_oos = nothing
    if idx_test !== nothing
        g_oos = all_growth_test[1:(max_days_test - 1), idx_test]
    else
        @warn "  $ticker not found in testing data, OoS will be skipped"
    end

    # --- Descriptive stats ---
    obs_kurt_is = kurtosis(g_is)
    obs_kurt_oos = g_oos !== nothing ? kurtosis(g_oos) : NaN
    @info @sprintf("  IS observations: %d, excess kurtosis: %.3f", T_is, obs_kurt_is)
    if g_oos !== nothing
        @info @sprintf("  OoS observations: %d, excess kurtosis: %.3f", length(g_oos), obs_kurt_oos)
    end

    # --- Fit HMM via JumpHMM.jl ---
    @info "  Fitting JumpHiddenMarkovModel (N=$_N, ν=$_DF)..."
    model_nj = JumpHMM.fit(JumpHiddenMarkovModel, prices_is;
                   rf = _RF_IS, N = _N, ν = _DF, dt = _DT)

    # --- Tune jump parameters ---
    @info "  Tuning jump parameters..."
    model_wj = tune(model_nj, prices_is;
                    ϵ_range = range(1e-4, 2.5e-2, length = 20),
                    λ_range = range(10.0, 160.0, length = 16),
                    n_paths = 200, w_κ = 0.20,
                    p_neg = _P_NEG, N_tail = _N_TAIL,
                    seed = 1234)
    @info @sprintf("  Optimal: ε=%.1e, λ=%.1f", model_wj.jump.ϵ, model_wj.jump.λ)

    # --- Simulate IS paths ---
    @info "  Simulating $_N_PATHS HMM-NJ IS paths..."
    nj_is_result = simulate(model_nj, T_is; n_paths = _N_PATHS, seed = 1234)
    nj_is_paths = hcat([p.observations for p in nj_is_result.paths]...)

    @info "  Simulating $_N_PATHS HMM-WJ IS paths..."
    wj_is_result = simulate(model_wj, T_is; n_paths = _N_PATHS, seed = 1234)
    wj_is_paths = hcat([p.observations for p in wj_is_result.paths]...)

    # --- Compute IS metrics ---
    @info "  Computing IS metrics..."
    nj_is_metrics = compute_metrics(g_is, nj_is_paths)
    wj_is_metrics = compute_metrics(g_is, wj_is_paths)

    # --- OoS paths and metrics ---
    nj_oos_metrics = nothing
    wj_oos_metrics = nothing
    if g_oos !== nothing
        T_oos = length(g_oos)

        @info "  Simulating $_N_PATHS HMM-NJ OoS paths (T=$T_oos)..."
        nj_oos_result = simulate(model_nj, T_oos; n_paths = _N_PATHS, seed = 1234)
        nj_oos_paths = hcat([p.observations for p in nj_oos_result.paths]...)

        @info "  Simulating $_N_PATHS HMM-WJ OoS paths (T=$T_oos)..."
        wj_oos_result = simulate(model_wj, T_oos; n_paths = _N_PATHS, seed = 1234)
        wj_oos_paths = hcat([p.observations for p in wj_oos_result.paths]...)

        @info "  Computing OoS metrics..."
        nj_oos_metrics = compute_metrics(g_oos, nj_oos_paths)
        wj_oos_metrics = compute_metrics(g_oos, wj_oos_paths)
    end

    # --- Store results ---
    results[ticker] = (
        eps_star = model_wj.jump.ϵ,
        lam_star = model_wj.jump.λ,
        obs_kurt_is = obs_kurt_is,
        obs_kurt_oos = obs_kurt_oos,
        n_is = T_is,
        n_oos = g_oos !== nothing ? length(g_oos) : 0,
        nj_is = nj_is_metrics,
        wj_is = wj_is_metrics,
        nj_oos = nj_oos_metrics,
        wj_oos = wj_oos_metrics,
    )

    # --- Print summary ---
    println("\n  --- $ticker Results ---")
    @printf("  Optimal hyperparameters: eps=%.1e, lambda=%.1f\n", model_wj.jump.ϵ, model_wj.jump.λ)
    @printf("  Observed excess kurtosis (IS): %.3f\n", obs_kurt_is)

    @printf("\n  %-20s  %16s  %16s\n", "IS Metric", "HMM-NJ", "HMM-WJ")
    println("  " * "-"^54)
    @printf("  %-20s  %10.1f (%4.1f)  %10.1f (%4.1f)\n", "KS pass (%)",
        nj_is_metrics.ks_pass, nj_is_metrics.ks_se,
        wj_is_metrics.ks_pass, wj_is_metrics.ks_se)
    @printf("  %-20s  %10.1f (%4.1f)  %10.1f (%4.1f)\n", "AD pass (%)",
        nj_is_metrics.ad_pass, nj_is_metrics.ad_se,
        wj_is_metrics.ad_pass, wj_is_metrics.ad_se)
    @printf("  %-20s  %10.1f (%4.2f)  %10.1f (%4.2f)\n", "Excess kurtosis",
        nj_is_metrics.kurt, nj_is_metrics.kurt_se,
        wj_is_metrics.kurt, wj_is_metrics.kurt_se)
    @printf("  %-20s  %10.3f (%5.3f)  %10.3f (%5.3f)\n", "ACF-MAE",
        nj_is_metrics.acf_mae, nj_is_metrics.acf_mae_se,
        wj_is_metrics.acf_mae, wj_is_metrics.acf_mae_se)

    if nj_oos_metrics !== nothing && wj_oos_metrics !== nothing
        @printf("\n  Observed excess kurtosis (OoS): %.3f\n", obs_kurt_oos)
        @printf("\n  %-20s  %16s  %16s\n", "OoS Metric", "HMM-NJ", "HMM-WJ")
        println("  " * "-"^54)
        @printf("  %-20s  %10.1f (%4.1f)  %10.1f (%4.1f)\n", "KS pass (%)",
            nj_oos_metrics.ks_pass, nj_oos_metrics.ks_se,
            wj_oos_metrics.ks_pass, wj_oos_metrics.ks_se)
        @printf("  %-20s  %10.1f (%4.1f)  %10.1f (%4.1f)\n", "AD pass (%)",
            nj_oos_metrics.ad_pass, nj_oos_metrics.ad_se,
            wj_oos_metrics.ad_pass, wj_oos_metrics.ad_se)
        @printf("  %-20s  %10.1f (%4.2f)  %10.1f (%4.2f)\n", "Excess kurtosis",
            nj_oos_metrics.kurt, nj_oos_metrics.kurt_se,
            wj_oos_metrics.kurt, wj_oos_metrics.kurt_se)
        @printf("  %-20s  %10.3f (%5.3f)  %10.3f (%5.3f)\n", "ACF-MAE",
            nj_oos_metrics.acf_mae, nj_oos_metrics.acf_mae_se,
            wj_oos_metrics.acf_mae, wj_oos_metrics.acf_mae_se)
    end
end

# ── 5. Save all results ──────────────────────────────────────────────────────
results_path = joinpath(_PATH_TO_DATA, "Multi-Ticker-Results.jld2")
save(results_path, Dict("results" => results, "tickers" => TICKERS))
@info "Results saved to $results_path"

# ── 6. Print LaTeX table rows ────────────────────────────────────────────────
println("\n" * "="^80)
println("LaTeX rows for Supplemental Table (Table S5)")
println("="^80)

for ticker in TICKERS
    haskey(results, ticker) || continue
    r = results[ticker]

    @printf("\n%% --- %s (eps*=%.1e, lam*=%.0f) ---\n", ticker, r.eps_star, r.lam_star)

    println("% In-sample:")
    @printf("%-6s & HMM-NJ & %.1f (%.1f) & %.1f (%.1f) & %.1f (%.2f) & %.3f (%.3f) \\\\\n",
        ticker,
        r.nj_is.ks_pass, r.nj_is.ks_se,
        r.nj_is.ad_pass, r.nj_is.ad_se,
        r.nj_is.kurt, r.nj_is.kurt_se,
        r.nj_is.acf_mae, r.nj_is.acf_mae_se)
    @printf("%-6s & HMM-WJ & %.1f (%.1f) & %.1f (%.1f) & %.1f (%.2f) & %.3f (%.3f) \\\\\n",
        ticker,
        r.wj_is.ks_pass, r.wj_is.ks_se,
        r.wj_is.ad_pass, r.wj_is.ad_se,
        r.wj_is.kurt, r.wj_is.kurt_se,
        r.wj_is.acf_mae, r.wj_is.acf_mae_se)

    if r.nj_oos !== nothing && r.wj_oos !== nothing
        println("% Out-of-sample:")
        @printf("%-6s & HMM-NJ & %.1f (%.1f) & %.1f (%.1f) & %.1f (%.2f) & %.3f (%.3f) \\\\\n",
            ticker,
            r.nj_oos.ks_pass, r.nj_oos.ks_se,
            r.nj_oos.ad_pass, r.nj_oos.ad_se,
            r.nj_oos.kurt, r.nj_oos.kurt_se,
            r.nj_oos.acf_mae, r.nj_oos.acf_mae_se)
        @printf("%-6s & HMM-WJ & %.1f (%.1f) & %.1f (%.1f) & %.1f (%.2f) & %.3f (%.3f) \\\\\n",
            ticker,
            r.wj_oos.ks_pass, r.wj_oos.ks_se,
            r.wj_oos.ad_pass, r.wj_oos.ad_se,
            r.wj_oos.kurt, r.wj_oos.kurt_se,
            r.wj_oos.acf_mae, r.wj_oos.acf_mae_se)
    end
end

println("\nDone.")
