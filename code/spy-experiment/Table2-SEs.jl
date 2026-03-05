# =============================================================================
# Table2-SEs.jl
#
# Computes standard errors for all metrics in Table 2 (model comparison).
# Loads pre-saved simulated paths from GARCH-Benchmark-SPY.jld2 (GARCH paths)
# and HMM-WJ-SPY-N-100-daily-aggregate.jld2 (HMM model), re-simulates HMM
# paths to get raw per-path data, then computes SEs.
#
# SE methodology:
#   KS/AD pass rate — binomial SE: sqrt(p̂(1-p̂)/n)
#   Kurtosis (sim)  — SE = std(kurt_vals) / sqrt(n)
#   ACF-MAE         — bootstrap SE (B=500 resamples of the 1,000 paths)
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const _RF_IS   = 0.043
const _RF_OOS  = 0.0421
const _DT      = 1.0 / 252.0
const _N_PATHS = 1_000
const _L_ACF   = 252
const _ALPHA   = 0.05
const _N_BOOT  = 500

const _JLD2_HMM   = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")
const _JLD2_GARCH = joinpath(_PATH_TO_DATA, "GARCH-Benchmark-SPY.jld2")

# ── 1. Load data ─────────────────────────────────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train = original_train["AAPL"] |> nrow

train_dataset = Dict{String,DataFrame}()
for (ticker, df) ∈ original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end
tickers_train = keys(train_dataset) |> collect |> sort

all_growth_train = log_growth_matrix(train_dataset, tickers_train;
                       Δt = _DT, risk_free_rate = _RF_IS)

spy_idx_train = findfirst(x -> x == "SPY", tickers_train)
Ri_train      = all_growth_train[:, spy_idx_train]
g_is          = Ri_train[1:(max_days_train - 1)]

@info "Loading testing data..."
original_test = MyTestingMarketDataSet() |> x -> x["dataset"]
max_days_test = original_test["AAPL"] |> nrow

test_dataset = Dict{String,DataFrame}()
for (ticker, df) ∈ original_test
    nrow(df) == max_days_test && (test_dataset[ticker] = df)
end
tickers_test = keys(test_dataset) |> collect |> sort

all_growth_test = log_growth_matrix(test_dataset, tickers_test;
                      Δt = _DT, risk_free_rate = _RF_OOS)

spy_idx_test = findfirst(x -> x == "SPY", tickers_test)
Ri_test      = all_growth_test[:, spy_idx_test]
g_oos        = Ri_test[1:(max_days_test - 1)]

@info "  IS obs: $(length(g_is)), OoS obs: $(length(g_oos))"

# ── 2. Bootstrap SE for ACF-MAE ─────────────────────────────────────────────
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

# ── 3. Full metrics + SEs from paths ────────────────────────────────────────
function compute_metrics_with_se(obs::Vector{Float64}, paths::Matrix{Float64})
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

    # Point estimates
    ks_pass  = mean(ks_pvals .> _ALPHA)
    ad_pass  = mean(ad_pvals .> _ALPHA)
    kurt_m   = mean(kurt_vals)
    mean_acf = vec(mean(acf_mat, dims = 2))
    acf_mae  = mean(abs.(obs_acf .- mean_acf))

    # SEs
    ks_se   = sqrt(ks_pass * (1 - ks_pass) / n_paths)
    ad_se   = sqrt(ad_pass * (1 - ad_pass) / n_paths)
    kurt_se = std(kurt_vals) / sqrt(n_paths)
    mae_se  = bootstrap_acf_mae_se(acf_mat, obs_acf)

    return (
        ks_pass = 100.0 * ks_pass, ks_se = 100.0 * ks_se,
        ad_pass = 100.0 * ad_pass, ad_se = 100.0 * ad_se,
        kurt    = kurt_m,          kurt_se = kurt_se,
        acf_mae = acf_mae,        acf_mae_se = mae_se,
    )
end

# ── 4. Load HMM model and simulate fresh paths ──────────────────────────────
@info "Loading HMM model from $(_JLD2_HMM)..."
hmm_dict     = load(_JLD2_HMM)
insample_obs = hmm_dict["insampledataset"]
T_is         = length(insample_obs)
π̄            = hmm_dict["stationary"]
decode_model = hmm_dict["decode"]
hmm_model    = hmm_dict["model"]
jump_model   = hmm_dict["jump_model"]

# NJ paths
@info "Simulating $_N_PATHS HMM-NJ in-sample paths..."
nj_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
for i in 1:_N_PATHS
    start = rand(π̄)
    result = hmm_model(start, T_is)
    for j in 1:T_is
        nj_is_paths[j, i] = rand(decode_model[result[j, 1]])
    end
end

# WJ paths
@info "Simulating $_N_PATHS HMM-WJ in-sample paths..."
wj_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
for i in 1:_N_PATHS
    start = rand(π̄)
    result = jump_model(start, T_is)
    for j in 1:T_is
        wj_is_paths[j, i] = rand(decode_model[result[j, 1]])
    end
end

# NJ OoS paths (same model, shorter length)
T_oos = length(g_oos)
@info "Simulating $_N_PATHS HMM-NJ OoS paths (T=$T_oos)..."
nj_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
for i in 1:_N_PATHS
    start = rand(π̄)
    result = hmm_model(start, T_oos)
    for j in 1:T_oos
        nj_oos_paths[j, i] = rand(decode_model[result[j, 1]])
    end
end

# WJ OoS paths
@info "Simulating $_N_PATHS HMM-WJ OoS paths (T=$T_oos)..."
wj_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
for i in 1:_N_PATHS
    start = rand(π̄)
    result = jump_model(start, T_oos)
    for j in 1:T_oos
        wj_oos_paths[j, i] = rand(decode_model[result[j, 1]])
    end
end

# ── 5. GARCH: fit and simulate ──────────────────────────────────────────────
@info "Fitting GARCH(1,1)..."
garch_fit = fit(GARCH{1, 1}, g_is)

@info "Simulating $_N_PATHS GARCH IS paths..."
garch_is_paths = Matrix{Float64}(undef, length(g_is), _N_PATHS)
for i in 1:_N_PATHS
    garch_is_paths[:, i] = simulate(garch_fit, length(g_is)).data
end

@info "Simulating $_N_PATHS GARCH OoS paths..."
garch_oos_paths = Matrix{Float64}(undef, length(g_oos), _N_PATHS)
for i in 1:_N_PATHS
    garch_oos_paths[:, i] = simulate(garch_fit, length(g_oos)).data
end

# ── 6. Compute all metrics + SEs ────────────────────────────────────────────
@info "Computing IS metrics..."
garch_is = compute_metrics_with_se(insample_obs, garch_is_paths)
nj_is    = compute_metrics_with_se(insample_obs, nj_is_paths)
wj_is    = compute_metrics_with_se(insample_obs, wj_is_paths)

@info "Computing OoS metrics..."
garch_oos = compute_metrics_with_se(g_oos, garch_oos_paths)
nj_oos    = compute_metrics_with_se(g_oos, nj_oos_paths)
wj_oos    = compute_metrics_with_se(g_oos, wj_oos_paths)

# ── 7. Print results ─────────────────────────────────────────────────────────
function fmt(val, se; pct=false)
    if pct
        return @sprintf("%.1f (%.1f)", val, se)
    else
        return @sprintf("%.3f (%.3f)", val, se)
    end
end

function fmt_kurt(val, se)
    return @sprintf("%.1f (%.2f)", val, se)
end

println("\n" * "="^80)
println("  Table 2 — Model Comparison with SEs (parenthetical)")
println("="^80)

println("\n  IN-SAMPLE:")
@printf("  %-28s  %16s  %16s  %16s\n", "Metric", "GARCH(1,1)", "HMM-NJ", "HMM-WJ")
println("  " * "-"^78)
@printf("  %-28s  %16s  %16s  %16s\n", "KS pass rate (%)",
    fmt(garch_is.ks_pass, garch_is.ks_se; pct=true),
    fmt(nj_is.ks_pass, nj_is.ks_se; pct=true),
    fmt(wj_is.ks_pass, wj_is.ks_se; pct=true))
@printf("  %-28s  %16s  %16s  %16s\n", "AD pass rate (%)",
    fmt(garch_is.ad_pass, garch_is.ad_se; pct=true),
    fmt(nj_is.ad_pass, nj_is.ad_se; pct=true),
    fmt(wj_is.ad_pass, wj_is.ad_se; pct=true))
@printf("  %-28s  %16s  %16s  %16s\n", "Kurtosis (sim)",
    fmt_kurt(garch_is.kurt, garch_is.kurt_se),
    fmt_kurt(nj_is.kurt, nj_is.kurt_se),
    fmt_kurt(wj_is.kurt, wj_is.kurt_se))
@printf("  %-28s  %16s  %16s  %16s\n", "ACF-MAE",
    fmt(garch_is.acf_mae, garch_is.acf_mae_se),
    fmt(nj_is.acf_mae, nj_is.acf_mae_se),
    fmt(wj_is.acf_mae, wj_is.acf_mae_se))

println("\n  OUT-OF-SAMPLE:")
@printf("  %-28s  %16s  %16s  %16s\n", "Metric", "GARCH(1,1)", "HMM-NJ", "HMM-WJ")
println("  " * "-"^78)
@printf("  %-28s  %16s  %16s  %16s\n", "KS pass rate (%)",
    fmt(garch_oos.ks_pass, garch_oos.ks_se; pct=true),
    fmt(nj_oos.ks_pass, nj_oos.ks_se; pct=true),
    fmt(wj_oos.ks_pass, wj_oos.ks_se; pct=true))
@printf("  %-28s  %16s  %16s  %16s\n", "AD pass rate (%)",
    fmt(garch_oos.ad_pass, garch_oos.ad_se; pct=true),
    fmt(nj_oos.ad_pass, nj_oos.ad_se; pct=true),
    fmt(wj_oos.ad_pass, wj_oos.ad_se; pct=true))
@printf("  %-28s  %16s  %16s  %16s\n", "Kurtosis (sim)",
    fmt_kurt(garch_oos.kurt, garch_oos.kurt_se),
    fmt_kurt(nj_oos.kurt, nj_oos.kurt_se),
    fmt_kurt(wj_oos.kurt, wj_oos.kurt_se))
@printf("  %-28s  %16s  %16s  %16s\n", "ACF-MAE",
    fmt(garch_oos.acf_mae, garch_oos.acf_mae_se),
    fmt(nj_oos.acf_mae, nj_oos.acf_mae_se),
    fmt(wj_oos.acf_mae, wj_oos.acf_mae_se))

println("\n" * "="^80)

@info "Done."
