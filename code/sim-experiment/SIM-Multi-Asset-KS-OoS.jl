# =============================================================================
# SIM-Multi-Asset-KS-OoS.jl
#
# Out-of-sample version of SIM-Multi-Asset-KS.jl.
# Uses training-period SIM parameters and empirical residuals to generate
# OoS asset paths via HMM-WJ SPY simulation, then KS-tests against
# observed 2025 growth rates.
#
# Prerequisites:
#   data/SIMs-SP500-01-03-14-to-12-31-24.jld2 — SIM parameters (training)
#   ../spy-experiment/data/HMM-WJ-SPY-N-100-daily-aggregate.jld2 — fitted HMM
#
# Outputs:
#   data/SIM-Multi-Asset-Results-OoS.jld2
# =============================================================================

include(joinpath(@__DIR__, "Include.jl"))

const _N_PATHS = 1_000
const _ALPHA   = 0.05
const _DT      = 1.0 / 252.0

# ── 1. Load SIM parameters (estimated on training data with r̄=0.0) ──────────
@info "Loading SIM parameters..."
sim_data = load(joinpath(_PATH_TO_DATA,
    "SIMs-SP500-01-03-14-to-12-31-24.jld2"))["data"]

# ── 2. Load HMM-WJ model ────────────────────────────────────────────────────
@info "Loading HMM-WJ model..."
hmm_d = load(joinpath(@__DIR__, "..", "spy-experiment", "data",
    "HMM-WJ-SPY-N-100-daily-aggregate.jld2"))

jump_model   = hmm_d["jump_model"]
decode_model = hmm_d["decode"]
pi_bar       = hmm_d["stationary"]

# ── 3. Load training data (for computing empirical residuals) ────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train = original_train["AAPL"] |> nrow
train_dataset  = Dict(k => v for (k, v) in original_train if nrow(v) == max_days_train)
tickers_train  = keys(train_dataset) |> collect |> sort
growth_train   = log_growth_matrix(train_dataset, tickers_train;
    Δt = _DT, risk_free_rate = 0.0)
spy_idx_train  = findfirst(==("SPY"), tickers_train)
G_spy_train    = growth_train[:, spy_idx_train]
T_train        = size(growth_train, 1)
@info "  Training: $(length(tickers_train)) assets, $T_train days"

# ── 4. Load OoS data ────────────────────────────────────────────────────────
@info "Loading out-of-sample data..."
original_test = MyTestingMarketDataSet() |> x -> x["dataset"]
max_days_test = original_test["AAPL"] |> nrow
test_dataset  = Dict(k => v for (k, v) in original_test if nrow(v) == max_days_test)
tickers_test  = keys(test_dataset) |> collect |> sort
growth_test   = log_growth_matrix(test_dataset, tickers_test;
    Δt = _DT, risk_free_rate = 0.0)
T_oos         = size(growth_test, 1)
@info "  OoS: $(length(tickers_test)) assets, $T_oos days"

# Common tickers (must be in both train, test, AND SIM parameters)
common_tickers = intersect(tickers_train, tickers_test) |>
    t -> intersect(t, collect(keys(sim_data))) |> sort
n_assets = length(common_tickers)
@info "  Common tickers: $n_assets"

# ── 5. Simulate HMM-WJ SPY OoS paths ────────────────────────────────────────
@info "Simulating $_N_PATHS HMM-WJ SPY OoS paths (T=$T_oos)..."
spy_sim_oos = Matrix{Float64}(undef, T_oos, _N_PATHS)
for j in 1:_N_PATHS
    start_state = rand(pi_bar)
    result = jump_model(start_state, T_oos)
    states = Int.(result[:, 1])
    spy_sim_oos[:, j] = [rand(decode_model[s]) for s in states]
    j % 200 == 0 && @info "  $j / $_N_PATHS SPY paths simulated..."
end

# ── 6. For each asset, compute OoS KS pass rate ─────────────────────────────
@info "Computing OoS KS pass rates for $n_assets assets..."

tickers_out   = Vector{String}(undef, n_assets)
betas_out     = Vector{Float64}(undef, n_assets)
alphas_out    = Vector{Float64}(undef, n_assets)
r_squared_out = Vector{Float64}(undef, n_assets)
ks_pass_rates = Vector{Float64}(undef, n_assets)
ks_pvals_mat  = Matrix{Float64}(undef, n_assets, _N_PATHS)

for i in eachindex(common_tickers)
    ticker = common_tickers[i]
    tickers_out[i] = ticker

    # SIM parameters
    params_i = sim_data[ticker]
    α_i = params_i.alpha
    β_i = params_i.beta
    betas_out[i] = β_i
    alphas_out[i] = α_i

    # Training residuals (empirical, preserves fat tails)
    train_idx = findfirst(==(ticker), tickers_train)
    g_train_i = growth_train[:, train_idx]
    resid_train = g_train_i .- (α_i .+ β_i .* G_spy_train)

    # OoS observed growth rates
    test_idx = findfirst(==(ticker), tickers_test)
    g_oos_i = growth_test[:, test_idx]

    # OoS R²: use SIM prediction with observed OoS SPY
    spy_idx_test = findfirst(==("SPY"), tickers_test)
    G_spy_oos = growth_test[:, spy_idx_test]
    ŷ_oos = α_i .+ β_i .* G_spy_oos
    SS_resid = sum((g_oos_i .- ŷ_oos) .^ 2)
    SS_total = sum((g_oos_i .- mean(g_oos_i)) .^ 2)
    r_squared_out[i] = 1.0 - SS_resid / SS_total

    # KS tests: resample training residuals, combine with simulated SPY OoS
    n_pass = 0
    for j in 1:_N_PATHS
        η_hat = resid_train[rand(1:T_train, T_oos)]
        G_hat = α_i .+ β_i .* spy_sim_oos[:, j] .+ η_hat
        pval = pvalue(ApproximateTwoSampleKSTest(g_oos_i, G_hat))
        ks_pvals_mat[i, j] = pval
        if pval >= _ALPHA
            n_pass += 1
        end
    end
    ks_pass_rates[i] = n_pass / _N_PATHS

    i % 50 == 0 && @info @sprintf("  %d / %d assets done — %s: β=%.2f, R²=%.3f, KS pass=%.1f%%",
        i, n_assets, ticker, β_i, r_squared_out[i], 100ks_pass_rates[i])
end

# ── 7. Save results ─────────────────────────────────────────────────────────
@info "Saving results..."
results_path = joinpath(_PATH_TO_DATA, "SIM-Multi-Asset-Results-OoS.jld2")
save(results_path, Dict(
    "tickers"       => tickers_out,
    "betas"         => betas_out,
    "alphas"        => alphas_out,
    "r_squared"     => r_squared_out,
    "ks_pass_rates" => ks_pass_rates,
    "ks_pvals_mat"  => ks_pvals_mat,
    "spy_sim_paths" => spy_sim_oos,
    "T_oos"         => T_oos,
))

# ── 8. Summary statistics ───────────────────────────────────────────────────
valid = .!isnan.(ks_pass_rates)
@info @sprintf("Results saved to %s", results_path)
@info @sprintf("  Assets: %d (valid: %d)", n_assets, sum(valid))
@info @sprintf("  Median KS pass rate: %.1f%%", 100median(ks_pass_rates[valid]))
@info @sprintf("  Mean KS pass rate:   %.1f%%", 100mean(ks_pass_rates[valid]))
@info @sprintf("  Mean R²:             %.3f", mean(r_squared_out[valid]))
@info @sprintf("  Median β:            %.3f", median(betas_out[valid]))

for t in ["MSFT", "NVDA", "JNJ", "QQQ", "SPY"]
    idx = findfirst(==(t), tickers_out)
    idx !== nothing && @info @sprintf("  %s: β=%.3f, R²=%.3f, KS pass=%.1f%%",
        t, betas_out[idx], r_squared_out[idx], 100ks_pass_rates[idx])
end

@info "Done — SIM-Multi-Asset-KS OoS computation complete."
