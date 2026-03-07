# =============================================================================
# Multi-Ticker-Evaluation.jl
#
# Builds a standalone HMM-NJ and HMM-WJ for each ticker in TICKERS, runs
# a grid search over (epsilon, lambda) to find the optimal jump parameters,
# then evaluates 1,000 simulated paths against the observed series using
# KS, AD, excess kurtosis, and ACF-MAE (with SEs).
#
# This script addresses the "single-asset evaluation" concern by showing
# that the framework generalises to individual equities with different
# risk profiles (low-beta defensive, high-beta growth, financials).
#
# Tickers:
#   NVDA — high-beta tech (Information Technology)
#   JNJ  — low-beta defensive (Health Care)
#   JPM  — moderate-high beta financials (Financials)
#
# Outputs:
#   data/Multi-Ticker-Results.jld2
#
# Usage:
#   cd code/other-ticker-experiment && julia Multi-Ticker-Evaluation.jl
# =============================================================================

include("Include.jl")

# ── Configuration ─────────────────────────────────────────────────────────────
const TICKERS  = ["NVDA", "JNJ", "JPM"]
const _N       = 100           # number of HMM states
const _N_PATHS = 1_000         # simulated paths per model
const _L_ACF   = 252           # max ACF lag
const _ALPHA   = 0.05          # significance level
const _N_BOOT  = 500           # bootstrap resamples for ACF-MAE SE
const _N_TAIL  = 5             # tail states on each side
const _P_NEG   = 0.52          # negative-tail bias
const _W_KURT  = 0.20          # kurtosis penalty weight in grid search
const _RF_IS   = 0.043         # risk-free rate (IS)
const _RF_OOS  = 0.0421        # risk-free rate (OoS)
const _DT      = 1.0 / 252.0   # daily time step

# Grid search ranges (same as SPY experiment)
const _EPS_GRID = [1e-4, 5e-4, 1e-3, 2.5e-3, 5e-3, 1e-2, 2.5e-2]
const _LAM_GRID = [10.0, 20.0, 30.0, 50.0, 70.0, 100.0, 130.0, 160.0]
const _N_GRID_PATHS = 200      # paths per grid point (fast sweep)

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

# ── 2. Helper: build HMM from growth rates ───────────────────────────────────
function build_hmm(g::Vector{Float64}, N::Int)
    states = collect(1:N)
    T_is = length(g)

    # Laplace fit + quantile bins
    d = fit_mle(Laplace, g)
    pct = range(0.0, 1.0, length = N + 1) |> collect
    bounds = Matrix{Float64}(undef, N, 2)
    for s in states
        bounds[s, 1] = quantile(d, pct[s])
        bounds[s, 2] = quantile(d, pct[s + 1])
    end

    # Encode observations to state sequence
    encoded = Vector{Int}(undef, T_is)
    for i in eachindex(g)
        v = g[i]
        encoded[i] = 1
        for s in states
            if bounds[s, 1] <= v < bounds[s, 2]
                encoded[i] = s
                break
            end
        end
    end

    # Count transitions and normalize
    P = zeros(N, N)
    for i in 2:T_is
        P[encoded[i-1], encoded[i]] += 1.0
    end

    P_hat = zeros(N, N)
    for row in states
        Z = sum(P[row, :])
        if Z > 0
            P_hat[row, :] = P[row, :] ./ Z
        else
            P_hat[row, :] .= 1.0 / N
        end
    end

    # Stationary distribution
    pi_bar = Categorical((P_hat^50)[1, :])

    # Decode distributions (fit Normal per state from actual observations)
    decode = Dict{Int,Normal}()
    for s in states
        idxs = findall(x -> x == s, encoded)
        if length(idxs) >= 2
            decode[s] = fit_mle(Normal, g[idxs])
        else
            decode[s] = Normal(mean(g), std(g))
        end
    end

    return (P = P_hat, pi_bar = pi_bar, decode = decode, states = states,
            encoded = encoded, bounds = bounds, laplace = d)
end

# ── 3. Helper: simulate jump path (inline, for grid search) ──────────────────
function simulate_jump_path(T_dict::Matrix{Float64}, pi_bar, decode::Dict,
                            eps::Float64, lam::Float64, n_steps::Int,
                            N::Int; n_tail::Int = _N_TAIL, p_neg::Float64 = _P_NEG)
    bottom = collect(1:n_tail)
    top = collect((N - n_tail + 1):N)
    states_seq = Vector{Int}(undef, n_steps)
    decoded = Vector{Float64}(undef, n_steps)

    states_seq[1] = rand(pi_bar)
    t = 2
    while t <= n_steps
        if rand() < eps
            K = rand(Poisson(lam))
            for _ in 1:K
                t > n_steps && break
                states_seq[t] = rand() < p_neg ? rand(bottom) : rand(top)
                t += 1
            end
        else
            row = states_seq[t-1]
            states_seq[t] = rand(Categorical(T_dict[row, :]))
            t += 1
        end
    end

    for i in 1:n_steps
        decoded[i] = rand(decode[states_seq[i]])
    end

    return decoded
end

# ── 4. Helper: grid search for optimal (epsilon, lambda) ──────────────────────
function grid_search(g_is::Vector{Float64}, hmm; N::Int = _N)
    T_is = length(g_is)
    lags = collect(1:_L_ACF)
    obs_acf = autocor(abs.(g_is), lags)
    obs_kurt = kurtosis(g_is)

    best_eps = _EPS_GRID[1]
    best_lam = _LAM_GRID[1]
    best_J = Inf
    J_surface = Matrix{Float64}(undef, length(_EPS_GRID), length(_LAM_GRID))

    for (ie, eps) in enumerate(_EPS_GRID)
        for (il, lam) in enumerate(_LAM_GRID)
            acf_sum = zeros(_L_ACF)
            kurt_sum = 0.0

            for _ in 1:_N_GRID_PATHS
                path = simulate_jump_path(hmm.P, hmm.pi_bar, hmm.decode,
                                          eps, lam, T_is, N)
                acf_sum .+= autocor(abs.(path), lags)
                kurt_sum += kurtosis(path)
            end

            mean_acf = acf_sum ./ _N_GRID_PATHS
            mean_kurt = kurt_sum / _N_GRID_PATHS

            J = sum((obs_acf .- mean_acf).^2) + _W_KURT * (obs_kurt - mean_kurt)^2
            J_surface[ie, il] = J

            if J < best_J
                best_J = J
                best_eps = eps
                best_lam = lam
            end
        end
    end

    return (eps = best_eps, lam = best_lam, J = best_J, surface = J_surface)
end

# ── 5. Helper: bootstrap SE for ACF-MAE ──────────────────────────────────────
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

# ── 6. Helper: compute all metrics with SEs from simulated paths ──────────────
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

# ── 7. Main loop over tickers ────────────────────────────────────────────────
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
    @info @sprintf("  IS observations: %d, excess kurtosis: %.3f", length(g_is), obs_kurt_is)
    if g_oos !== nothing
        @info @sprintf("  OoS observations: %d, excess kurtosis: %.3f", length(g_oos), obs_kurt_oos)
    end

    # --- Build HMM ---
    @info "  Building HMM with N=$_N states..."
    hmm = build_hmm(g_is, _N)

    # --- Grid search for optimal (epsilon, lambda) ---
    @info "  Running grid search over (epsilon, lambda)..."
    gs = grid_search(g_is, hmm; N = _N)
    @info @sprintf("  Optimal: eps=%.1e, lambda=%.1f, J=%.6f", gs.eps, gs.lam, gs.J)

    # --- Build HMM-NJ model (using VLQuantitativeFinancePackage) ---
    E = diagm(ones(_N))
    hmm_nj = build(MyHiddenMarkovModel, (
        states = hmm.states, T = hmm.P, E = E,
    ))
    hmm_wj = build(MyHiddenMarkovModelWithJumps, (
        states = hmm.states, T = hmm.P, E = E,
        ϵ = gs.eps, λ = gs.lam,
    ))

    # --- Simulate IS paths ---
    T_is = length(g_is)

    @info "  Simulating $_N_PATHS HMM-NJ IS paths..."
    nj_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
    for i in 1:_N_PATHS
        start = rand(hmm.pi_bar)
        result = hmm_nj(start, T_is)
        for j in 1:T_is
            nj_is_paths[j, i] = rand(hmm.decode[result[j, 1]])
        end
    end

    @info "  Simulating $_N_PATHS HMM-WJ IS paths..."
    wj_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
    for i in 1:_N_PATHS
        start = rand(hmm.pi_bar)
        result = hmm_wj(start, T_is)
        for j in 1:T_is
            wj_is_paths[j, i] = rand(hmm.decode[result[j, 1]])
        end
    end

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
        nj_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
        for i in 1:_N_PATHS
            start = rand(hmm.pi_bar)
            result = hmm_nj(start, T_oos)
            for j in 1:T_oos
                nj_oos_paths[j, i] = rand(hmm.decode[result[j, 1]])
            end
        end

        @info "  Simulating $_N_PATHS HMM-WJ OoS paths (T=$T_oos)..."
        wj_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
        for i in 1:_N_PATHS
            start = rand(hmm.pi_bar)
            result = hmm_wj(start, T_oos)
            for j in 1:T_oos
                wj_oos_paths[j, i] = rand(hmm.decode[result[j, 1]])
            end
        end

        @info "  Computing OoS metrics..."
        nj_oos_metrics = compute_metrics(g_oos, nj_oos_paths)
        wj_oos_metrics = compute_metrics(g_oos, wj_oos_paths)
    end

    # --- Store results ---
    results[ticker] = (
        eps_star = gs.eps,
        lam_star = gs.lam,
        J_star = gs.J,
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
    @printf("  Optimal hyperparameters: eps=%.1e, lambda=%.1f\n", gs.eps, gs.lam)
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

# ── 8. Save all results ──────────────────────────────────────────────────────
results_path = joinpath(_PATH_TO_DATA, "Multi-Ticker-Results.jld2")
save(results_path, Dict("results" => results, "tickers" => TICKERS))
@info "Results saved to $results_path"

# ── 9. Print LaTeX table rows ────────────────────────────────────────────────
println("\n" * "="^80)
println("LaTeX rows for Supplemental Table (Table S1)")
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
