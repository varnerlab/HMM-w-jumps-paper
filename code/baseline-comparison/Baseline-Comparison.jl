# =============================================================================
# Baseline-Comparison.jl
#
# Computes all metrics for Table 2 (expanded) across 6 generators:
#   Bootstrap, Gaussian, Laplace, GARCH(1,1), HMM-NJ, HMM-WJ
#
# Metrics (all with SEs):
#   Fidelity:  KS pass rate, AD pass rate, excess kurtosis
#   Temporal:  ACF-MAE (lags 1-252)
#   Novelty:   mean correlation distance to real path
#   Diversity: mean pairwise correlation distance among synthetic paths
#   Coverage:  fraction of 99 empirical quantiles within synthetic envelope
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
const _COV_QUANTILES = collect(0.01:0.01:0.99)  # 99 quantile levels
const _N_BINS  = 50                              # histogram bins for Hellinger

const _JLD2_HMM = joinpath(_PATH_TO_SPY_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")

# ── 1. Load data ─────────────────────────────────────────────────────────────
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
Ri_train      = all_growth_train[:, spy_idx_train]
g_is          = Ri_train[1:(max_days_train - 1)]

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
Ri_test      = all_growth_test[:, spy_idx_test]
g_oos        = Ri_test[1:(max_days_test - 1)]

@info "  IS obs: $(length(g_is)), OoS obs: $(length(g_oos))"

# ── 2. Load HMM model ───────────────────────────────────────────────────────
@info "Loading HMM model..."
hmm_dict     = load(_JLD2_HMM)
insample_obs = hmm_dict["insampledataset"]
T_is         = length(insample_obs)
π̄            = hmm_dict["stationary"]
decode_model = hmm_dict["decode"]
hmm_model    = hmm_dict["model"]
jump_model   = hmm_dict["jump_model"]
T_oos        = length(g_oos)

# ── 3. Metric computation functions ──────────────────────────────────────────

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

"""Mean of the strict upper triangle of a square matrix."""
function mean_upper_tri(M::AbstractMatrix)
    n = size(M, 1)
    s = 0.0
    c = 0
    @inbounds for j in 2:n
        for i in 1:(j-1)
            s += M[i, j]
            c += 1
        end
    end
    return s / c
end

"""
Wasserstein-1 distance between two equal-length empirical distributions.
W1 = mean|x_(i) - y_(i)| where (i) denotes the i-th order statistic.
Units are the same as the data.
"""
function wasserstein1(x::Vector{Float64}, y::Vector{Float64})
    return mean(abs.(sort(x) .- sort(y)))
end

"""
Hellinger distance between two empirical distributions via histogram.
Uses _N_BINS equal-width bins on the common support of x and y.
Returns H in [0, 1]: H=0 identical distributions, H=1 disjoint support.
"""
function hellinger(x::Vector{Float64}, y::Vector{Float64}; n_bins::Int = _N_BINS)
    lo = min(minimum(x), minimum(y))
    hi = max(maximum(x), maximum(y))
    edges = range(lo, hi, length = n_bins + 1)
    px = fit(Histogram, x, edges).weights ./ length(x)
    py = fit(Histogram, y, edges).weights ./ length(y)
    return sqrt(0.5 * sum((sqrt.(px) .- sqrt.(py)).^2))
end

"""
Compute all quality metrics for a set of synthetic paths against observed data.

Returns a NamedTuple with point estimates and SEs for:
  ks_pass, ad_pass, kurt, acf_mae, novelty, diversity, coverage
"""
function compute_all_metrics(obs::Vector{Float64}, paths::Matrix{Float64};
                              n_boot::Int = _N_BOOT)
    n_paths = size(paths, 2)
    T = size(paths, 1)
    L = min(_L_ACF, length(obs) - 1)
    lags = collect(1:L)
    obs_acf = autocor(abs.(obs), lags)

    # ── per-path fidelity + temporal + novelty ───────────────────────────────
    ks_pvals  = Vector{Float64}(undef, n_paths)
    ad_pvals  = Vector{Float64}(undef, n_paths)
    kurt_vals = Vector{Float64}(undef, n_paths)
    acf_mat   = Matrix{Float64}(undef, L, n_paths)
    nov_vals  = Vector{Float64}(undef, n_paths)  # novelty per path
    w1_vals   = Vector{Float64}(undef, n_paths)  # Wasserstein-1 per path
    hd_vals   = Vector{Float64}(undef, n_paths)  # Hellinger distance per path

    obs_trunc = obs[1:min(T, length(obs))]  # match lengths for correlation

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

    # ── fidelity ─────────────────────────────────────────────────────────────
    ks_pass = mean(ks_pvals .> _ALPHA)
    ad_pass = mean(ad_pvals .> _ALPHA)
    ks_se   = sqrt(ks_pass * (1 - ks_pass) / n_paths)
    ad_se   = sqrt(ad_pass * (1 - ad_pass) / n_paths)

    # ── kurtosis ─────────────────────────────────────────────────────────────
    kurt_m  = mean(kurt_vals)
    kurt_se = std(kurt_vals) / sqrt(n_paths)

    # ── temporal (ACF-MAE) ───────────────────────────────────────────────────
    mean_acf = vec(mean(acf_mat, dims = 2))
    acf_mae  = mean(abs.(obs_acf .- mean_acf))
    acf_se   = bootstrap_acf_mae_se(acf_mat, obs_acf; n_boot = n_boot)

    # ── novelty ──────────────────────────────────────────────────────────────
    novelty_m  = mean(nov_vals)
    novelty_se = std(nov_vals) / sqrt(n_paths)

    # ── diversity (pairwise correlation distance) ────────────────────────────
    @info "  Computing diversity (correlation matrix)..."
    cor_mat  = cor(paths)                        # n_paths × n_paths
    dist_mat = 1.0 .- abs.(cor_mat)
    for i in 1:n_paths; dist_mat[i, i] = 0.0; end

    diversity_m = mean_upper_tri(dist_mat)

    # bootstrap SE: resample path indices, recompute mean upper triangle
    boot_div = Vector{Float64}(undef, n_boot)
    for b in 1:n_boot
        idx = rand(1:n_paths, n_paths)
        boot_div[b] = mean_upper_tri(dist_mat[idx, idx])
    end
    diversity_se = std(boot_div)

    # ── coverage ─────────────────────────────────────────────────────────────
    n_q = length(_COV_QUANTILES)
    obs_q = quantile(obs, _COV_QUANTILES)

    # quantiles per synthetic path
    sim_q = Matrix{Float64}(undef, n_q, n_paths)
    for i in 1:n_paths
        sim_q[:, i] = quantile(paths[:, i], _COV_QUANTILES)
    end

    # point estimate: fraction of quantile levels where obs falls in [5th, 95th] of sim
    covered = 0
    for q in 1:n_q
        lo = quantile(sim_q[q, :], 0.05)
        hi = quantile(sim_q[q, :], 0.95)
        (lo <= obs_q[q] <= hi) && (covered += 1)
    end
    coverage_m = covered / n_q

    # bootstrap SE: resample paths, recompute coverage
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

    # ── Wasserstein-1 ────────────────────────────────────────────────────────
    w1_m  = mean(w1_vals)
    w1_se = std(w1_vals) / sqrt(n_paths)

    # ── Hellinger distance ───────────────────────────────────────────────────
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

# ── 4. Generate paths for all 6 models ──────────────────────────────────────

function generate_paths(generator::Function, T::Int, n::Int)
    paths = Matrix{Float64}(undef, T, n)
    for i in 1:n
        paths[:, i] = generator(T)
    end
    return paths
end

# ── 4a. Baselines (fit on insample_obs) ──────────────────────────────────────
μ_is  = mean(insample_obs)
σ_is  = std(insample_obs)
lap_b = mean(abs.(insample_obs .- μ_is))  # Laplace scale MLE = mean |x - μ|

bootstrap_gen(T) = insample_obs[rand(1:length(insample_obs), T)]
gaussian_gen(T)  = rand(Normal(μ_is, σ_is), T)
laplace_gen(T)   = rand(Laplace(μ_is, lap_b), T)

@info "Generating Bootstrap IS paths..."
boot_is_paths = generate_paths(bootstrap_gen, T_is, _N_PATHS)

@info "Generating Gaussian IS paths..."
gauss_is_paths = generate_paths(gaussian_gen, T_is, _N_PATHS)

@info "Generating Laplace IS paths..."
lap_is_paths = generate_paths(laplace_gen, T_is, _N_PATHS)

@info "Generating Bootstrap OoS paths..."
boot_oos_paths = generate_paths(bootstrap_gen, T_oos, _N_PATHS)

@info "Generating Gaussian OoS paths..."
gauss_oos_paths = generate_paths(gaussian_gen, T_oos, _N_PATHS)

@info "Generating Laplace OoS paths..."
lap_oos_paths = generate_paths(laplace_gen, T_oos, _N_PATHS)

# ── 4b. GARCH(1,1) ──────────────────────────────────────────────────────────
@info "Fitting GARCH(1,1)..."
garch_fit = fit(GARCH{1, 1}, insample_obs)

@info "Simulating GARCH IS paths..."
garch_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
for i in 1:_N_PATHS
    garch_is_paths[:, i] = simulate(garch_fit, T_is).data
end

@info "Simulating GARCH OoS paths..."
garch_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
for i in 1:_N_PATHS
    garch_oos_paths[:, i] = simulate(garch_fit, T_oos).data
end

# ── 4c. HMM-NJ ──────────────────────────────────────────────────────────────
@info "Simulating HMM-NJ IS paths..."
nj_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
for i in 1:_N_PATHS
    start = rand(π̄)
    result = hmm_model(start, T_is)
    for j in 1:T_is
        nj_is_paths[j, i] = rand(decode_model[result[j, 1]])
    end
end

@info "Simulating HMM-NJ OoS paths..."
nj_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
for i in 1:_N_PATHS
    start = rand(π̄)
    result = hmm_model(start, T_oos)
    for j in 1:T_oos
        nj_oos_paths[j, i] = rand(decode_model[result[j, 1]])
    end
end

# ── 4d. HMM-WJ ──────────────────────────────────────────────────────────────
@info "Simulating HMM-WJ IS paths..."
wj_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
for i in 1:_N_PATHS
    start = rand(π̄)
    result = jump_model(start, T_is)
    for j in 1:T_is
        wj_is_paths[j, i] = rand(decode_model[result[j, 1]])
    end
end

@info "Simulating HMM-WJ OoS paths..."
wj_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
for i in 1:_N_PATHS
    start = rand(π̄)
    result = jump_model(start, T_oos)
    for j in 1:T_oos
        wj_oos_paths[j, i] = rand(decode_model[result[j, 1]])
    end
end

# ── 5. Compute all metrics ──────────────────────────────────────────────────
models_is = [
    ("Bootstrap",  boot_is_paths),
    ("Gaussian",   gauss_is_paths),
    ("Laplace",    lap_is_paths),
    ("GARCH(1,1)", garch_is_paths),
    ("HMM-NJ",    nj_is_paths),
    ("HMM-WJ",    wj_is_paths),
]

models_oos = [
    ("Bootstrap",  boot_oos_paths),
    ("Gaussian",   gauss_oos_paths),
    ("Laplace",    lap_oos_paths),
    ("GARCH(1,1)", garch_oos_paths),
    ("HMM-NJ",    nj_oos_paths),
    ("HMM-WJ",    wj_oos_paths),
]

results_is  = Dict{String, NamedTuple}()
results_oos = Dict{String, NamedTuple}()

for (name, paths) in models_is
    @info "Computing IS metrics for $name..."
    results_is[name] = compute_all_metrics(insample_obs, paths)
end

for (name, paths) in models_oos
    @info "Computing OoS metrics for $name..."
    results_oos[name] = compute_all_metrics(g_oos, paths)
end

# ── 6. Print formatted table ────────────────────────────────────────────────
fmt_pct(val, se)  = @sprintf("%5.1f (%3.1f)", val, se)
fmt_dec(val, se)  = @sprintf("%5.3f (%5.3f)", val, se)
fmt_kurt(val, se) = @sprintf("%5.1f (%4.2f)", val, se)
fmt_nov(val, se)  = @sprintf("%5.3f (%5.3f)", val, se)

model_order = ["Bootstrap", "Gaussian", "Laplace", "GARCH(1,1)", "HMM-NJ", "HMM-WJ"]
n_params    = [0, 2, 2, 3, 2, 4]

function print_table(obs::Vector{Float64}, res::Dict, window::String)
    println("\n  $window:")
    hdr = @sprintf("  %-24s", "Metric")
    for m in model_order
        hdr *= @sprintf("  %16s", m)
    end
    println(hdr)
    println("  " * "-"^(24 + 16 * length(model_order) + 2 * length(model_order)))

    # KS pass rate
    row = @sprintf("  %-24s", "KS pass rate (%)")
    for m in model_order; row *= @sprintf("  %16s", fmt_pct(res[m].ks_pass, res[m].ks_se)); end
    println(row)

    # AD pass rate
    row = @sprintf("  %-24s", "AD pass rate (%)")
    for m in model_order; row *= @sprintf("  %16s", fmt_pct(res[m].ad_pass, res[m].ad_se)); end
    println(row)

    # Kurtosis (observed)
    row = @sprintf("  %-24s", "Kurtosis (observed)")
    kurt_obs = @sprintf("%.3f", kurtosis(obs))
    for _ in model_order; row *= @sprintf("  %16s", kurt_obs); end
    println(row)

    # Kurtosis (simulated)
    row = @sprintf("  %-24s", "Kurtosis (simulated)")
    for m in model_order; row *= @sprintf("  %16s", fmt_kurt(res[m].kurt, res[m].kurt_se)); end
    println(row)

    # ACF-MAE
    row = @sprintf("  %-24s", "ACF-MAE")
    for m in model_order; row *= @sprintf("  %16s", fmt_dec(res[m].acf_mae, res[m].acf_se)); end
    println(row)

    # Novelty
    row = @sprintf("  %-24s", "Novelty")
    for m in model_order; row *= @sprintf("  %16s", fmt_nov(res[m].novelty, res[m].novelty_se)); end
    println(row)

    # Diversity
    row = @sprintf("  %-24s", "Diversity")
    for m in model_order; row *= @sprintf("  %16s", fmt_nov(res[m].diversity, res[m].diversity_se)); end
    println(row)

    # Coverage
    row = @sprintf("  %-24s", "Coverage (%)")
    for m in model_order; row *= @sprintf("  %16s", fmt_pct(res[m].coverage, res[m].coverage_se)); end
    println(row)

    # Wasserstein-1
    row = @sprintf("  %-24s", "Wasserstein-1")
    for m in model_order; row *= @sprintf("  %16s", fmt_dec(res[m].w1, res[m].w1_se)); end
    println(row)

    # Hellinger distance
    row = @sprintf("  %-24s", "Hellinger dist")
    for m in model_order; row *= @sprintf("  %16s", fmt_dec(res[m].hellinger, res[m].hellinger_se)); end
    println(row)
end

println("\n" * "="^140)
println("  Table 2 (expanded) — Full Model Comparison with SEs")
println("  $_N_PATHS simulated paths, significance level α = $_ALPHA")
println("="^140)

print_table(insample_obs, results_is,
            "In-sample: $T_is trading days (2014-2024)")

print_table(g_oos, results_oos,
            "Out-of-sample: $T_oos trading days (2025)")

# Parameters
let row = @sprintf("  %-24s", "Parameters estimated")
    for p in n_params; row *= @sprintf("  %16d", p); end
    println()
    println(row)
end

println("\n" * "="^140)
@info "Done."
