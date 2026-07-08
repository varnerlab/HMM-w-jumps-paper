# =============================================================================
# GARCHt-Addendum.jl
#
# Computes the same seven Table-2 stylized-fact metrics as Baseline-Comparison.jl
# for a GARCH(1,1) model with STUDENT-t standardized innovations (the "GARCH(1,1)-t"
# benchmark used on the M-exam deck slides 7 and 13). The Gaussian GARCH(1,1) in
# Baseline-Comparison.jl only differs by its innovation distribution; every metric
# function, the SPY data, the windows, the path count, and the seed are identical
# here, so the GARCH-t column is apples-to-apples with the existing columns.
#
# Prints KS, AD, excess kurtosis, ACF-MAE, coverage, Wasserstein-1, Hellinger
# (point estimates, plus SEs) for the IS and OoS windows.
# =============================================================================

include("Include.jl")

# ── constants (identical to Baseline-Comparison.jl) ──────────────────────────
const _RF_IS   = 0.043
const _RF_OOS  = 0.0421
const _DT      = 1.0 / 252.0
const _N_PATHS = 1_000
const _L_ACF   = 252
const _ALPHA   = 0.05
const _N_BOOT  = 500
const _COV_QUANTILES = collect(0.01:0.01:0.99)
const _N_BINS  = 50

const _JLD2_HMM = joinpath(_PATH_TO_SPY_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")

# ── 1. Load SPY data (identical to Baseline-Comparison.jl) ───────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train = original_train["AAPL"] |> nrow
train_dataset = Dict{String,DataFrame}()
for (ticker, df) in original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end
tickers_train = keys(train_dataset) |> collect |> sort
all_growth_train = log_growth_matrix(train_dataset, tickers_train; Δt = _DT, risk_free_rate = _RF_IS)
spy_idx_train = findfirst(x -> x == "SPY", tickers_train)
g_is = all_growth_train[:, spy_idx_train][1:(max_days_train - 1)]

@info "Loading testing data..."
original_test = MyTestingMarketDataSet() |> x -> x["dataset"]
max_days_test = original_test["AAPL"] |> nrow
test_dataset = Dict{String,DataFrame}()
for (ticker, df) in original_test
    nrow(df) == max_days_test && (test_dataset[ticker] = df)
end
tickers_test = keys(test_dataset) |> collect |> sort
all_growth_test = log_growth_matrix(test_dataset, tickers_test; Δt = _DT, risk_free_rate = _RF_OOS)
spy_idx_test = findfirst(x -> x == "SPY", tickers_test)
g_oos = all_growth_test[:, spy_idx_test][1:(max_days_test - 1)]

# the Gaussian GARCH baseline fits on `insample_obs` (the HMM in-sample series),
# so use the same series here for an exact parallel.
hmm_dict     = load(_JLD2_HMM)
insample_obs = hmm_dict["insampledataset"]
T_is = length(insample_obs)
T_oos = length(g_oos)
@info "  IS obs: $T_is, OoS obs: $T_oos"

# ── 2. Metric functions (verbatim from Baseline-Comparison.jl) ───────────────
function bootstrap_acf_mae_se(acf_mat::Matrix{Float64}, obs_acf::Vector{Float64}; n_boot::Int = _N_BOOT)
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
    n = size(M, 1); s = 0.0; c = 0
    @inbounds for j in 2:n, i in 1:(j-1)
        s += M[i, j]; c += 1
    end
    return s / c
end

wasserstein1(x::Vector{Float64}, y::Vector{Float64}) = mean(abs.(sort(x) .- sort(y)))

function hellinger(x::Vector{Float64}, y::Vector{Float64}; n_bins::Int = _N_BINS)
    lo = min(minimum(x), minimum(y)); hi = max(maximum(x), maximum(y))
    edges = range(lo, hi, length = n_bins + 1)
    px = fit(Histogram, x, edges).weights ./ length(x)
    py = fit(Histogram, y, edges).weights ./ length(y)
    return sqrt(0.5 * sum((sqrt.(px) .- sqrt.(py)).^2))
end

function compute_all_metrics(obs::Vector{Float64}, paths::Matrix{Float64}; n_boot::Int = _N_BOOT)
    n_paths = size(paths, 2); T = size(paths, 1)
    L = min(_L_ACF, length(obs) - 1); lags = collect(1:L)
    obs_acf = autocor(abs.(obs), lags)
    ks_pvals  = Vector{Float64}(undef, n_paths)
    ad_pvals  = Vector{Float64}(undef, n_paths)
    kurt_vals = Vector{Float64}(undef, n_paths)
    acf_mat   = Matrix{Float64}(undef, L, n_paths)
    w1_vals   = Vector{Float64}(undef, n_paths)
    hd_vals   = Vector{Float64}(undef, n_paths)
    Threads.@threads for i in 1:n_paths
        sim = paths[:, i]
        ks_pvals[i]   = pvalue(ApproximateTwoSampleKSTest(obs, sim))
        ad_pvals[i]   = pvalue(KSampleADTest(obs, sim))
        kurt_vals[i]  = kurtosis(sim)
        acf_mat[:, i] = autocor(abs.(sim), lags)
        w1_vals[i]    = wasserstein1(obs, sim)
        hd_vals[i]    = hellinger(obs, sim)
    end
    ks_pass = mean(ks_pvals .> _ALPHA); ad_pass = mean(ad_pvals .> _ALPHA)
    ks_se   = sqrt(ks_pass * (1 - ks_pass) / n_paths)
    ad_se   = sqrt(ad_pass * (1 - ad_pass) / n_paths)
    kurt_m  = mean(kurt_vals); kurt_se = std(kurt_vals) / sqrt(n_paths)
    mean_acf = vec(mean(acf_mat, dims = 2))
    acf_mae  = mean(abs.(obs_acf .- mean_acf))
    acf_se   = bootstrap_acf_mae_se(acf_mat, obs_acf; n_boot = n_boot)

    n_q = length(_COV_QUANTILES); obs_q = quantile(obs, _COV_QUANTILES)
    sim_q = Matrix{Float64}(undef, n_q, n_paths)
    for i in 1:n_paths; sim_q[:, i] = quantile(paths[:, i], _COV_QUANTILES); end
    covered = 0
    for q in 1:n_q
        lo = quantile(sim_q[q, :], 0.05); hi = quantile(sim_q[q, :], 0.95)
        (lo <= obs_q[q] <= hi) && (covered += 1)
    end
    coverage_m = covered / n_q
    boot_cov = Vector{Float64}(undef, n_boot)
    for b in 1:n_boot
        idx = rand(1:n_paths, n_paths); c = 0
        for q in 1:n_q
            lo = quantile(sim_q[q, idx], 0.05); hi = quantile(sim_q[q, idx], 0.95)
            (lo <= obs_q[q] <= hi) && (c += 1)
        end
        boot_cov[b] = c / n_q
    end
    coverage_se = std(boot_cov)
    w1_m  = mean(w1_vals);  w1_se  = std(w1_vals) / sqrt(n_paths)
    hd_m  = mean(hd_vals);  hd_se  = std(hd_vals) / sqrt(n_paths)
    return (
        ks_pass  = 100.0 * ks_pass,  ks_se  = 100.0 * ks_se,
        ad_pass  = 100.0 * ad_pass,  ad_se  = 100.0 * ad_se,
        kurt     = kurt_m,           kurt_se = kurt_se,
        acf_mae  = acf_mae,          acf_se  = acf_se,
        coverage = 100.0 * coverage_m, coverage_se = 100.0 * coverage_se,
        w1       = w1_m,             w1_se  = w1_se,
        hellinger = hd_m,            hellinger_se = hd_se,
    )
end

# ── 3. Fit GARCH(1,1)-t (Student-t innovations; only change vs the Gaussian row) ──
@info "Fitting GARCH(1,1) with Student-t standardized innovations..."
garcht_fit = fit(GARCH{1,1}, insample_obs; dist = StdT)
display(garcht_fit)

@info "Simulating $_N_PATHS GARCH-t IS paths..."
garcht_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
for i in 1:_N_PATHS
    garcht_is_paths[:, i] = ARCHModels.simulate(garcht_fit, T_is).data
end
@info "Simulating $_N_PATHS GARCH-t OoS paths..."
garcht_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
for i in 1:_N_PATHS
    garcht_oos_paths[:, i] = ARCHModels.simulate(garcht_fit, T_oos).data
end

@info "Computing IS metrics..."
r_is  = compute_all_metrics(insample_obs, garcht_is_paths)
@info "Computing OoS metrics..."
r_oos = compute_all_metrics(g_oos, garcht_oos_paths)

# ── 4. Print (machine-readable) ──────────────────────────────────────────────
function emit(tag, obs, r)
    println("GARCHT_RESULT $tag ks=$(round(r.ks_pass,digits=1)) ad=$(round(r.ad_pass,digits=1)) " *
            "kurt=$(round(r.kurt,digits=2)) kurt_obs=$(round(kurtosis(obs),digits=2)) " *
            "acf=$(round(r.acf_mae,digits=4)) cov=$(round(r.coverage,digits=1)) " *
            "w1=$(round(r.w1,digits=3)) hell=$(round(r.hellinger,digits=4))")
end
println("\n" * "="^72)
emit("IS",  insample_obs, r_is)
emit("OOS", g_oos,        r_oos)
println("="^72)
@info "Done."
