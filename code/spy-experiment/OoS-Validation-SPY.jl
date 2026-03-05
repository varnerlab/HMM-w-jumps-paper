# =============================================================================
# OoS-Validation-SPY.jl
#
# Computes out-of-sample validation statistics for GARCH(1,1), HMM-NJ, and
# HMM-WJ on the full 2025 SPY test set, then prints the complete Table 2
# numbers (IS + OoS for all three models).
#
# Prerequisites:
#   GARCH-Benchmark-SPY.jld2 must exist (run GARCH-Benchmark-SPY.jl first —
#   it provides IS metrics and the fitted GARCH model).
#
# Outputs
#   data/OoS-Validation-SPY.jld2  — all OoS metrics
#   stdout                         — Table 2 (copy into paper)
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const _RF_IS     = 0.043          # IS risk-free rate (matches IS notebook)
const _RF_OOS    = 0.0421         # OoS risk-free rate (adjust if needed for 2025)
const _DT        = 1.0 / 252.0
const _N_PATHS   = 1_000
const _L_ACF     = 252
const _ALPHA     = 0.05
const _JLD2_HMM   = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")
const _JLD2_GARCH = joinpath(_PATH_TO_DATA, "GARCH-Benchmark-SPY.jld2")
const _JLD2_OUT   = joinpath(_PATH_TO_DATA, "OoS-Validation-SPY.jld2")

# ── 1. Load data ──────────────────────────────────────────────────────────────
@info "Loading in-sample data..."
original_train  = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train  = original_train["AAPL"] |> nrow
train_dataset   = Dict(k => v for (k,v) ∈ original_train if nrow(v) == max_days_train)
tickers_train   = keys(train_dataset) |> collect |> sort
all_growth_train = log_growth_matrix(train_dataset, tickers_train;
                       Δt = _DT, risk_free_rate = _RF_IS)
spy_idx_is = findfirst(x -> x == "SPY", tickers_train)
g_is       = all_growth_train[1:(max_days_train - 1), spy_idx_is]

@info "Loading out-of-sample data..."
original_test  = MyTestingMarketDataSet() |> x -> x["dataset"]
max_days_test  = original_test["AAPL"] |> nrow
test_dataset   = Dict(k => v for (k,v) ∈ original_test if nrow(v) == max_days_test)
tickers_test   = keys(test_dataset) |> collect |> sort
all_growth_test = log_growth_matrix(test_dataset, tickers_test;
                      Δt = _DT, risk_free_rate = _RF_OOS)
spy_idx_oos = findfirst(x -> x == "SPY", tickers_test)
g_oos       = all_growth_test[1:(max_days_test - 1), spy_idx_oos]
T_oos       = length(g_oos)

@info "  IS  observations : $(length(g_is))"
@info "  OoS observations : $T_oos"
@info "  IS  kurtosis     : $(round(kurtosis(g_is),  digits=3))"
@info "  OoS kurtosis     : $(round(kurtosis(g_oos), digits=3))"

# ── 2. Load HMM model ────────────────────────────────────────────────────────
@info "Loading HMM from $(_JLD2_HMM)..."
hmm_dict     = load(_JLD2_HMM)
insample_obs = hmm_dict["insampledataset"]
T_is         = length(insample_obs)
π̄            = hmm_dict["stationary"]
decode_model = hmm_dict["decode"]
hmm_model    = hmm_dict["model"]
T_dict       = hmm_model.transition      # Dict{Int, Categorical}
jump_model   = hmm_dict["jump_model"]

# ── 3. Load IS metrics (already computed by GARCH-Benchmark-SPY.jl) ──────────
@info "Loading IS metrics from $(_JLD2_GARCH)..."
garch_dict       = load(_JLD2_GARCH)
garch_is_metrics  = garch_dict["garch_is_metrics"]
garch_oos_metrics = garch_dict["garch_oos_metrics"]
hmm_nj_is_metrics = garch_dict["hmm_nj_is_metrics"]
hmm_wj_is_metrics = garch_dict["hmm_wj_is_metrics"]

# ── 4. Metric helper ─────────────────────────────────────────────────────────
function compute_metrics(obs::Vector{Float64},
                         paths::Matrix{Float64},
                         alpha::Float64 = _ALPHA,
                         L::Int = _L_ACF)
    n_paths  = size(paths, 2)
    L        = min(L, length(obs) - 1)
    lags     = collect(1:L)
    obs_acf  = autocor(abs.(obs), lags)
    obs_kurt = kurtosis(obs)

    ks_pvals  = Vector{Float64}(undef, n_paths)
    ad_pvals  = Vector{Float64}(undef, n_paths)
    kurt_vals = Vector{Float64}(undef, n_paths)
    acf_mat   = Matrix{Float64}(undef, L, n_paths)

    Threads.@threads for i in 1:n_paths
        sim           = paths[:, i]
        ks_pvals[i]   = pvalue(ApproximateTwoSampleKSTest(obs, sim))
        ad_pvals[i]   = pvalue(KSampleADTest(obs, sim))
        kurt_vals[i]  = kurtosis(sim)
        acf_mat[:, i] = autocor(abs.(sim), lags)
    end

    mean_acf    = vec(mean(acf_mat, dims = 2))
    acf_mae_vec = abs.(obs_acf .- mean_acf)

    return (
        ks_pass_rate   = mean(ks_pvals  .> alpha),
        ad_pass_rate   = mean(ad_pvals  .> alpha),
        ks_pvals       = ks_pvals,
        ad_pvals       = ad_pvals,
        kurt_obs       = obs_kurt,
        kurt_mean      = mean(kurt_vals),
        kurt_std       = std(kurt_vals),
        acf_mae        = mean(acf_mae_vec),
        acf_mae_lag1   = L >= 1   ? acf_mae_vec[1]   : NaN,
        acf_mae_lag5   = L >= 5   ? acf_mae_vec[5]   : NaN,
        acf_mae_lag20  = L >= 20  ? acf_mae_vec[20]  : NaN,
        acf_mae_lag252 = L >= 252 ? acf_mae_vec[252] : NaN,
        mean_acf       = mean_acf,
        obs_acf        = obs_acf,
        acf_mat        = acf_mat,
    )
end

# ── 5. Simulate HMM-NJ OoS paths ─────────────────────────────────────────────
@info "Simulating HMM-NJ OoS paths (T=$T_oos, N=$(_N_PATHS))..."
hmm_nj_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
for i in 1:_N_PATHS
    states    = Vector{Int}(undef, T_oos)
    states[1] = rand(π̄)
    for t in 2:T_oos
        states[t] = rand(T_dict[states[t-1]])
    end
    hmm_nj_oos_paths[:, i] = [rand(decode_model[s]) for s in states]
end

# ── 6. Simulate HMM-WJ OoS paths ─────────────────────────────────────────────
@info "Simulating HMM-WJ OoS paths (T=$T_oos, N=$(_N_PATHS))..."
hmm_wj_oos_all   = Matrix{Float64}(undef, T_oos, _N_PATHS)
jump_oos_indices = Int[]

for i in 1:_N_PATHS
    start_state  = rand(π̄)
    result       = jump_model(start_state, T_oos)
    states       = result[:, 1]
    jump_flags   = result[:, 2]
    hmm_wj_oos_all[:, i] = [rand(decode_model[s]) for s in states]
    any(==(1), jump_flags) && push!(jump_oos_indices, i)
end
@info "  WJ OoS paths with ≥1 jump: $(length(jump_oos_indices)) / $(_N_PATHS)"

# ── 7. Compute OoS metrics ────────────────────────────────────────────────────
@info "Computing HMM-NJ OoS metrics..."
hmm_nj_oos_metrics = compute_metrics(g_oos, hmm_nj_oos_paths)

@info "Computing HMM-WJ OoS metrics..."
hmm_wj_oos_metrics = compute_metrics(g_oos, hmm_wj_oos_all)

# ── 8. Print Table 2 ──────────────────────────────────────────────────────────
fmt(x) = x isa Number ? round(x, digits=3) : x
pct(x) = @sprintf("%.1f%%", 100*x)

println("\n" * "="^80)
println("  TABLE 2 — Model Comparison: SPY Excess Growth Rate")
println("  In-sample: $(length(g_is)) trading days (2014–2024)")
println("  Out-of-sample: $T_oos trading days (2025)")
println("="^80)

header = ["Metric", "GARCH(1,1)", "HMM-NJ (N=100)", "HMM-WJ (N=100)"]

is_data = [
    "── In-Sample ──────────────"  ""  ""  "";
    "KS pass rate"   pct(garch_is_metrics.ks_pass_rate)   pct(hmm_nj_is_metrics.ks_pass_rate)   pct(hmm_wj_is_metrics.ks_pass_rate);
    "AD pass rate"   pct(garch_is_metrics.ad_pass_rate)   pct(hmm_nj_is_metrics.ad_pass_rate)   pct(hmm_wj_is_metrics.ad_pass_rate);
    "Kurtosis (obs)" fmt(garch_is_metrics.kurt_obs)       fmt(hmm_nj_is_metrics.kurt_obs)       fmt(hmm_wj_is_metrics.kurt_obs);
    "Kurtosis (sim)" fmt(garch_is_metrics.kurt_mean)      fmt(hmm_nj_is_metrics.kurt_mean)      fmt(hmm_wj_is_metrics.kurt_mean);
    "ACF-MAE (1–252)" fmt(garch_is_metrics.acf_mae)       fmt(hmm_nj_is_metrics.acf_mae)        fmt(hmm_wj_is_metrics.acf_mae);
    "── Out-of-Sample ──────────"  ""  ""  "";
    "KS pass rate"   pct(garch_oos_metrics.ks_pass_rate)  pct(hmm_nj_oos_metrics.ks_pass_rate)  pct(hmm_wj_oos_metrics.ks_pass_rate);
    "AD pass rate"   pct(garch_oos_metrics.ad_pass_rate)  pct(hmm_nj_oos_metrics.ad_pass_rate)  pct(hmm_wj_oos_metrics.ad_pass_rate);
    "Kurtosis (obs)" fmt(garch_oos_metrics.kurt_obs)      fmt(hmm_nj_oos_metrics.kurt_obs)      fmt(hmm_wj_oos_metrics.kurt_obs);
    "Kurtosis (sim)" fmt(garch_oos_metrics.kurt_mean)     fmt(hmm_nj_oos_metrics.kurt_mean)     fmt(hmm_wj_oos_metrics.kurt_mean);
    "ACF-MAE (1–252)" fmt(garch_oos_metrics.acf_mae)      fmt(hmm_nj_oos_metrics.acf_mae)       fmt(hmm_wj_oos_metrics.acf_mae);
    "── Model complexity ───────"  ""  ""  "";
    "Parameters est." "3"  "2"  "4";
]
pretty_table(is_data; column_labels = header)

# ── 9. Save results ───────────────────────────────────────────────────────────
@info "Saving to $(_JLD2_OUT)..."
save(_JLD2_OUT,
    "g_oos",               g_oos,
    "hmm_nj_oos_paths",    hmm_nj_oos_paths,
    "hmm_wj_oos_all",      hmm_wj_oos_all,
    "jump_oos_indices",    jump_oos_indices,
    "hmm_nj_oos_metrics",  hmm_nj_oos_metrics,
    "hmm_wj_oos_metrics",  hmm_wj_oos_metrics,
)
@info "Done."
