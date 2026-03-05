# =============================================================================
# SIM-Multi-Asset-KS.jl
#
# Computes KS pass rates and R² for all 424 assets using the SIM extension
# of the HMM-WJ model. For each asset, we:
#   1. Generate 1000 SPY paths from the HMM-WJ model
#   2. Propagate each path through the SIM: Ĝᵢ = α̂ᵢ + β̂ᵢ * G_SPY + η̂ᵢ
#   3. Run a two-sample KS test against observed growth rates
#
# Prerequisites:
#   data/SIMs-SP500-01-03-14-to-12-31-24.jld2 — SIM parameters for 424 assets
#   ../spy-experiment/data/HMM-WJ-SPY-N-100-daily-aggregate.jld2 — fitted HMM
#
# Outputs:
#   data/SIM-Multi-Asset-Results.jld2
# =============================================================================

include(joinpath(@__DIR__, "Include.jl"))

const _N_PATHS = 1_000
const _ALPHA   = 0.05
const _DT      = 1.0 / 252.0

# ── 1. Load SIM parameters ──────────────────────────────────────────────────
@info "Loading SIM parameters..."
sim_jld2 = joinpath(_PATH_TO_DATA, "SIMs-SP500-01-03-14-to-12-31-24.jld2")
sim_data = load(sim_jld2)["data"]  # Dict{String, NamedTuple} with fields alpha, beta, training_variance, etc.

# ── 2. Load HMM-WJ model ────────────────────────────────────────────────────
@info "Loading HMM-WJ model..."
hmm_jld2 = joinpath(@__DIR__, "..", "spy-experiment", "data",
                     "HMM-WJ-SPY-N-100-daily-aggregate.jld2")
hmm_d = load(hmm_jld2)

jump_model   = hmm_d["jump_model"]
decode_model = hmm_d["decode"]
pi_bar       = hmm_d["stationary"]
g_is_spy     = hmm_d["insampledataset"]  # observed SPY growth rates, length 2766
T_is         = length(g_is_spy)

@info "  T_is = $T_is trading days"

# ── 3. Load training data and compute growth rate matrix ─────────────────────
@info "Loading training data..."
original_dataset = MyTrainingMarketDataSet() |> x -> x["dataset"]
maximum_trading_days = original_dataset["AAPL"] |> nrow

dataset = Dict{String,DataFrame}()
for (ticker, data) in original_dataset
    if nrow(data) == maximum_trading_days
        dataset[ticker] = data
    end
end

list_of_tickers = keys(dataset) |> collect |> sort
n_assets = length(list_of_tickers)
@info "  $n_assets assets with $maximum_trading_days trading days"

growth_rate_array = log_growth_matrix(dataset, list_of_tickers,
    Δt = _DT, risk_free_rate = 0.0)

# SPY column index
spy_idx = findfirst(==("SPY"), list_of_tickers)
G_spy_obs = growth_rate_array[:, spy_idx]

# ── 4. Simulate 1000 HMM-WJ SPY paths ───────────────────────────────────────
@info "Simulating $_N_PATHS HMM-WJ SPY paths (T=$T_is)..."
spy_sim_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
for j in 1:_N_PATHS
    start_state = rand(pi_bar)
    result = jump_model(start_state, T_is)
    states = Int.(result[:, 1])
    spy_sim_paths[:, j] = [rand(decode_model[s]) for s in states]
    j % 200 == 0 && @info "  $j / $_N_PATHS SPY paths simulated..."
end

# ── 5. For each asset, compute R² and KS pass rate ──────────────────────────
@info "Computing KS pass rates and R² for $n_assets assets..."

tickers_out    = Vector{String}(undef, n_assets)
betas_out      = Vector{Float64}(undef, n_assets)
alphas_out     = Vector{Float64}(undef, n_assets)
r_squared_out  = Vector{Float64}(undef, n_assets)
ks_pass_rates  = Vector{Float64}(undef, n_assets)
ks_pvals_mat   = Matrix{Float64}(undef, n_assets, _N_PATHS)

for i in eachindex(list_of_tickers)
    ticker = list_of_tickers[i]
    tickers_out[i] = ticker

    # Observed growth rates for this asset
    g_i = growth_rate_array[:, i]

    # SIM parameters — NamedTuple with fields: alpha, beta, training_variance, etc.
    if haskey(sim_data, ticker)
        params_i = sim_data[ticker]
        α_i = params_i.alpha
        β_i = params_i.beta
    else
        @warn "  Ticker $ticker not found in SIM parameters, skipping"
        betas_out[i] = NaN
        alphas_out[i] = NaN
        r_squared_out[i] = NaN
        ks_pass_rates[i] = NaN
        ks_pvals_mat[i, :] .= NaN
        continue
    end

    betas_out[i] = β_i
    alphas_out[i] = α_i

    # R² computation: 1 - SS_resid / SS_total
    ŷ_i = α_i .+ β_i .* G_spy_obs
    resid_i = g_i .- ŷ_i  # empirical residuals (preserves fat tails)
    SS_resid = sum(resid_i .^ 2)
    SS_total = sum((g_i .- mean(g_i)) .^ 2)
    r_squared_out[i] = 1.0 - SS_resid / SS_total

    # KS tests across 1000 SPY paths
    # Use empirical residual bootstrap (resampling actual residuals preserves
    # non-Gaussian features like fat tails and skewness)
    n_pass = 0
    for j in 1:_N_PATHS
        η_hat = resid_i[rand(1:T_is, T_is)]  # resample with replacement
        G_hat = α_i .+ β_i .* spy_sim_paths[:, j] .+ η_hat
        pval = pvalue(ApproximateTwoSampleKSTest(g_i, G_hat))
        ks_pvals_mat[i, j] = pval
        if pval >= _ALPHA
            n_pass += 1
        end
    end
    ks_pass_rates[i] = n_pass / _N_PATHS

    i % 50 == 0 && @info @sprintf("  %d / %d assets done — %s: β=%.2f, R²=%.3f, KS pass=%.1f%%",
        i, n_assets, ticker, β_i, r_squared_out[i], 100ks_pass_rates[i])
end

# ── 6. Save results ─────────────────────────────────────────────────────────
@info "Saving results..."
results_path = joinpath(_PATH_TO_DATA, "SIM-Multi-Asset-Results.jld2")
save(results_path, Dict(
    "tickers"        => tickers_out,
    "betas"          => betas_out,
    "alphas"         => alphas_out,
    "r_squared"      => r_squared_out,
    "ks_pass_rates"  => ks_pass_rates,
    "ks_pvals_mat"   => ks_pvals_mat,
    "spy_sim_paths"  => spy_sim_paths,
))

# ── 7. Summary statistics ───────────────────────────────────────────────────
valid = .!isnan.(ks_pass_rates)
@info @sprintf("Results saved to %s", results_path)
@info @sprintf("  Assets: %d (valid: %d)", n_assets, sum(valid))
@info @sprintf("  Median KS pass rate: %.1f%%", 100median(ks_pass_rates[valid]))
@info @sprintf("  Mean KS pass rate:   %.1f%%", 100mean(ks_pass_rates[valid]))
@info @sprintf("  Mean R²:             %.3f", mean(r_squared_out[valid]))
@info @sprintf("  Median β:            %.3f", median(betas_out[valid]))

# Spot-check MSFT
msft_idx = findfirst(==("MSFT"), tickers_out)
if msft_idx !== nothing
    @info @sprintf("  MSFT: β=%.3f, R²=%.3f, KS pass=%.1f%%",
        betas_out[msft_idx], r_squared_out[msft_idx], 100ks_pass_rates[msft_idx])
end

@info "Done — SIM-Multi-Asset-KS computation complete."
