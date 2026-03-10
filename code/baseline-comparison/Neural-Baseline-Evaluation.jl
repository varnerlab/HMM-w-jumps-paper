# =============================================================================
# Neural-Baseline-Evaluation.jl
#
# Loads GRU-generated synthetic paths from CSV and evaluates them using the
# same metric suite as Baseline-Comparison.jl (Table 2).
#
# Prerequisites:
#   1. Run neural-baseline/export_spy_data.jl  (exports SPY data to CSV)
#   2. Run neural-baseline/train_gru.py        (trains GRU, generates paths)
#   3. Run this script                         (computes all quality metrics)
# =============================================================================

include("Include.jl")
using DelimitedFiles

# ── constants ────────────────────────────────────────────────────────────────
const _RF_IS   = 0.043
const _RF_OOS  = 0.0421
const _DT      = 1.0 / 252.0
const _N_PATHS = 1_000
const _L_ACF   = 252
const _ALPHA   = 0.05
const _N_BOOT  = 500
const _COV_QUANTILES = collect(0.01:0.01:0.99)
const _N_BINS  = 50

const _NEURAL_DIR = joinpath(@__DIR__, "neural-baseline")

# ── 1. Load observed data ──────────────────────────────────────────────────
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
spy_idx_train = findfirst(x -> x == "SPY", tickers_train)
g_is = all_growth_train[1:(max_days_train - 1), spy_idx_train]

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
spy_idx_test = findfirst(x -> x == "SPY", tickers_test)
g_oos = all_growth_test[1:(max_days_test - 1), spy_idx_test]

@info "  IS obs: $(length(g_is)), OoS obs: $(length(g_oos))"

# ── 2. Load GRU paths from CSV ────────────────────────────────────────────
@info "Loading GRU IS paths..."
gru_is_path = joinpath(_NEURAL_DIR, "gru_paths_is.csv")
if !isfile(gru_is_path)
    error("GRU IS paths not found at $gru_is_path. Run train_gru.py first.")
end
gru_is_paths = readdlm(gru_is_path, ',', Float64)
@info "  GRU IS paths: $(size(gru_is_paths))"

@info "Loading GRU OoS paths..."
gru_oos_path = joinpath(_NEURAL_DIR, "gru_paths_oos.csv")
gru_oos_paths = readdlm(gru_oos_path, ',', Float64)
@info "  GRU OoS paths: $(size(gru_oos_paths))"

# ── 3. Metric functions (same as Baseline-Comparison.jl) ──────────────────

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

function mean_upper_tri(M::AbstractMatrix)
    n = size(M, 1)
    s = 0.0; c = 0
    @inbounds for j in 2:n
        for i in 1:(j-1); s += M[i, j]; c += 1; end
    end
    return s / c
end

function wasserstein1(x::Vector{Float64}, y::Vector{Float64})
    return mean(abs.(sort(x) .- sort(y)))
end

function hellinger(x::Vector{Float64}, y::Vector{Float64}; n_bins::Int = _N_BINS)
    lo = min(minimum(x), minimum(y))
    hi = max(maximum(x), maximum(y))
    edges = range(lo, hi, length = n_bins + 1)
    px = fit(Histogram, x, edges).weights ./ length(x)
    py = fit(Histogram, y, edges).weights ./ length(y)
    return sqrt(0.5 * sum((sqrt.(px) .- sqrt.(py)).^2))
end

function compute_all_metrics(obs::Vector{Float64}, paths::Matrix{Float64};
                              n_boot::Int = _N_BOOT)
    n_paths = size(paths, 2)
    T = size(paths, 1)
    L = min(_L_ACF, length(obs) - 1)
    lags = collect(1:L)
    obs_acf = autocor(abs.(obs), lags)

    ks_pvals  = Vector{Float64}(undef, n_paths)
    ad_pvals  = Vector{Float64}(undef, n_paths)
    kurt_vals = Vector{Float64}(undef, n_paths)
    acf_mat   = Matrix{Float64}(undef, L, n_paths)
    nov_vals  = Vector{Float64}(undef, n_paths)
    w1_vals   = Vector{Float64}(undef, n_paths)
    hd_vals   = Vector{Float64}(undef, n_paths)

    obs_trunc = obs[1:min(T, length(obs))]

    Threads.@threads for i in 1:n_paths
        sim = paths[:, i]
        ks_pvals[i]   = pvalue(ApproximateTwoSampleKSTest(obs, sim))
        ad_pvals[i]   = pvalue(KSampleADTest(obs, sim))
        kurt_vals[i]  = kurtosis(sim)
        acf_mat[:, i] = autocor(abs.(sim), lags)
        nov_vals[i]   = 1.0 - abs(cor(obs_trunc, sim[1:length(obs_trunc)]))
        w1_vals[i]    = wasserstein1(obs, sim)
        hd_vals[i]    = hellinger(obs, sim)
    end

    ks_pass = mean(ks_pvals .> _ALPHA)
    ad_pass = mean(ad_pvals .> _ALPHA)
    ks_se   = sqrt(ks_pass * (1 - ks_pass) / n_paths)
    ad_se   = sqrt(ad_pass * (1 - ad_pass) / n_paths)

    kurt_m  = mean(kurt_vals)
    kurt_se = std(kurt_vals) / sqrt(n_paths)

    mean_acf = vec(mean(acf_mat, dims = 2))
    acf_mae  = mean(abs.(obs_acf .- mean_acf))
    acf_se   = bootstrap_acf_mae_se(acf_mat, obs_acf; n_boot = n_boot)

    novelty_m  = mean(nov_vals)
    novelty_se = std(nov_vals) / sqrt(n_paths)

    @info "  Computing diversity..."
    cor_mat  = cor(paths)
    dist_mat = 1.0 .- abs.(cor_mat)
    for i in 1:n_paths; dist_mat[i, i] = 0.0; end
    diversity_m = mean_upper_tri(dist_mat)
    boot_div = Vector{Float64}(undef, n_boot)
    for b in 1:n_boot
        idx = rand(1:n_paths, n_paths)
        boot_div[b] = mean_upper_tri(dist_mat[idx, idx])
    end
    diversity_se = std(boot_div)

    n_q = length(_COV_QUANTILES)
    obs_q = quantile(obs, _COV_QUANTILES)
    sim_q = Matrix{Float64}(undef, n_q, n_paths)
    for i in 1:n_paths
        sim_q[:, i] = quantile(paths[:, i], _COV_QUANTILES)
    end
    covered = 0
    for q in 1:n_q
        lo = quantile(sim_q[q, :], 0.05)
        hi = quantile(sim_q[q, :], 0.95)
        (lo <= obs_q[q] <= hi) && (covered += 1)
    end
    coverage_m = covered / n_q
    boot_cov = Vector{Float64}(undef, n_boot)
    for b in 1:n_boot
        idx = rand(1:n_paths, n_paths)
        c = 0
        for q in 1:n_q
            lo = quantile(sim_q[q, idx], 0.05)
            hi = quantile(sim_q[q, idx], 0.95)
            (lo <= obs_q[q] <= hi) && (c += 1)
        end
        boot_cov[b] = c / n_q
    end
    coverage_se = std(boot_cov)

    w1_m  = mean(w1_vals)
    w1_se = std(w1_vals) / sqrt(n_paths)
    hd_m  = mean(hd_vals)
    hd_se = std(hd_vals) / sqrt(n_paths)

    return (
        ks_pass  = 100.0 * ks_pass,  ks_se  = 100.0 * ks_se,
        ad_pass  = 100.0 * ad_pass,  ad_se  = 100.0 * ad_se,
        kurt     = kurt_m,           kurt_se = kurt_se,
        acf_mae  = acf_mae,         acf_se  = acf_se,
        novelty  = novelty_m,       novelty_se = novelty_se,
        diversity = diversity_m,    diversity_se = diversity_se,
        coverage  = 100.0 * coverage_m, coverage_se = 100.0 * coverage_se,
        w1       = w1_m,            w1_se  = w1_se,
        hellinger = hd_m,           hellinger_se = hd_se,
    )
end

# ── 4. Compute metrics ────────────────────────────────────────────────────
@info "Computing IS metrics for GRU..."
gru_is = compute_all_metrics(g_is, gru_is_paths)

@info "Computing OoS metrics for GRU..."
gru_oos = compute_all_metrics(g_oos, gru_oos_paths)

# ── 5. Print results ──────────────────────────────────────────────────────
fmt_pct(val, se)  = @sprintf("%5.1f (%3.1f)", val, se)
fmt_dec(val, se)  = @sprintf("%5.3f (%5.3f)", val, se)
fmt_kurt(val, se) = @sprintf("%5.1f (%4.2f)", val, se)
fmt_nov(val, se)  = @sprintf("%5.3f (%5.3f)", val, se)

function print_results(label, obs, res)
    println("\n  $label:")
    println("  " * "-"^50)
    println(@sprintf("  %-24s  %16s", "KS pass rate (%)",   fmt_pct(res.ks_pass, res.ks_se)))
    println(@sprintf("  %-24s  %16s", "AD pass rate (%)",   fmt_pct(res.ad_pass, res.ad_se)))
    println(@sprintf("  %-24s  %16.3f", "Kurtosis (observed)",  kurtosis(obs)))
    println(@sprintf("  %-24s  %16s", "Kurtosis (simulated)", fmt_kurt(res.kurt, res.kurt_se)))
    println(@sprintf("  %-24s  %16s", "ACF-MAE",            fmt_dec(res.acf_mae, res.acf_se)))
    println(@sprintf("  %-24s  %16s", "Novelty",            fmt_nov(res.novelty, res.novelty_se)))
    println(@sprintf("  %-24s  %16s", "Diversity",          fmt_nov(res.diversity, res.diversity_se)))
    println(@sprintf("  %-24s  %16s", "Coverage (%)",       fmt_pct(res.coverage, res.coverage_se)))
    println(@sprintf("  %-24s  %16s", "Wasserstein-1",      fmt_dec(res.w1, res.w1_se)))
    println(@sprintf("  %-24s  %16s", "Hellinger dist",     fmt_dec(res.hellinger, res.hellinger_se)))
end

println("\n" * "="^70)
println("  GRU Neural Baseline — Quality Metrics")
println("  $_N_PATHS simulated paths, α = $_ALPHA")
println("="^70)

print_results("In-sample: $(length(g_is)) trading days (2014-2024)", g_is, gru_is)
print_results("Out-of-sample: $(length(g_oos)) trading days (2025)", g_oos, gru_oos)

println("\n" * "="^70)
@info "Done."
