# =============================================================================
# Table2-StudentT-Emissions.jl
#
# Regenerates all Table 2 metrics with Student-t(df=5) emissions for
# HMM-NJ and HMM-WJ using JumpHMM.jl. All other models (Bootstrap,
# Gaussian, Laplace, GARCH) are unchanged.
#
# The HMM model is fit via JumpHMM.fit(JumpHiddenMarkovModel, ...) which
# builds the Laplace quantile partition, transition matrix, and Student-t
# emissions internally. Jump parameters are optimized via tune().
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
const _N_BINS  = 50
const _COV_QUANTILES = collect(0.01:0.01:0.99)
const N_STATES = 100
const _N_TAIL  = 5
const _P_NEG   = 0.52
const _DF      = 5.0

const _JLD2_HMM = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")

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
spy_idx = findfirst(x -> x == "SPY", tickers_train)
g_is = all_growth_train[:, spy_idx][1:(max_days_train - 1)]

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
g_oos = all_growth_test[:, spy_idx_test][1:(max_days_test - 1)]

T_is  = length(g_is)
T_oos = length(g_oos)
@info "  IS: T=$(T_is), OoS: T=$(T_oos)"

# Extract SPY prices for JumpHMM (uses VWAP, same as log_growth_matrix)
spy_prices_is  = train_dataset["SPY"][!, :volume_weighted_average_price]
spy_prices_oos = test_dataset["SPY"][!, :volume_weighted_average_price]

# ── 2. Fit HMM model via JumpHMM.jl ─────────────────────────────────────────
@info "Fitting JumpHiddenMarkovModel (N=$N_STATES, ν=$_DF)..."
model_nj = JumpHMM.fit(JumpHiddenMarkovModel, spy_prices_is;
                       rf = _RF_IS, N = N_STATES, ν = _DF, dt = _DT)

@info "Tuning jump parameters..."
model_wj = tune(model_nj, spy_prices_is;
                ϵ_range = range(1e-4, 2.5e-2, length = 20),
                λ_range = range(10.0, 160.0, length = 16),
                n_paths = 200, w_κ = 0.20,
                p_neg = _P_NEG, N_tail = _N_TAIL,
                acf_lags = 25, seed = 1234)

@info "  Optimal: ε=$(model_wj.jump.ϵ), λ=$(model_wj.jump.λ)"

# Use g_is as the reference observation vector (from VLPackage, consistent with baselines)
insample_obs = g_is

# ── 3. Metric computation functions ─────────────────────────────────────────

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
        for i in 1:(j-1)
            s += M[i, j]; c += 1
        end
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

function compute_all_metrics(obs::Vector{Float64}, paths::Matrix{Float64})
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
    acf_se   = bootstrap_acf_mae_se(acf_mat, obs_acf)
    novelty_m  = mean(nov_vals)
    novelty_se = std(nov_vals) / sqrt(n_paths)

    @info "  Computing diversity..."
    cor_mat  = cor(paths)
    dist_mat = 1.0 .- abs.(cor_mat)
    for i in 1:n_paths; dist_mat[i, i] = 0.0; end
    diversity_m = mean_upper_tri(dist_mat)
    boot_div = Vector{Float64}(undef, _N_BOOT)
    for b in 1:_N_BOOT
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
    boot_cov = Vector{Float64}(undef, _N_BOOT)
    for b in 1:_N_BOOT
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

    w1_m  = mean(w1_vals);  w1_se  = std(w1_vals) / sqrt(n_paths)
    hd_m  = mean(hd_vals);  hd_se  = std(hd_vals) / sqrt(n_paths)

    return (
        ks_pass = 100.0 * ks_pass, ks_se = 100.0 * ks_se,
        ad_pass = 100.0 * ad_pass, ad_se = 100.0 * ad_se,
        kurt = kurt_m, kurt_se = kurt_se,
        acf_mae = acf_mae, acf_se = acf_se,
        novelty = novelty_m, novelty_se = novelty_se,
        diversity = diversity_m, diversity_se = diversity_se,
        coverage = 100.0 * coverage_m, coverage_se = 100.0 * coverage_se,
        w1 = w1_m, w1_se = w1_se,
        hellinger = hd_m, hellinger_se = hd_se,
    )
end

# ── 4. Simulate HMM paths via JumpHMM.jl ────────────────────────────────────

@info "Simulating HMM-NJ IS paths..."
nj_result_is = simulate(model_nj, T_is; n_paths = _N_PATHS, seed = 1234)
nj_is = hcat([p.observations for p in nj_result_is.paths]...)

@info "Simulating HMM-NJ OoS paths..."
nj_result_oos = simulate(model_nj, T_oos; n_paths = _N_PATHS, seed = 1234)
nj_oos = hcat([p.observations for p in nj_result_oos.paths]...)

@info "Simulating HMM-WJ IS paths..."
wj_result_is = simulate(model_wj, T_is; n_paths = _N_PATHS, seed = 1234)
wj_is = hcat([p.observations for p in wj_result_is.paths]...)

@info "Simulating HMM-WJ OoS paths..."
wj_result_oos = simulate(model_wj, T_oos; n_paths = _N_PATHS, seed = 1234)
wj_oos = hcat([p.observations for p in wj_result_oos.paths]...)

# ── 5. Generate baseline paths (unchanged) ──────────────────────────────────

μ_is  = mean(insample_obs)
σ_is  = std(insample_obs)
lap_b = mean(abs.(insample_obs .- μ_is))

gen_paths(gen, T, n) = hcat([gen(T) for _ in 1:n]...)

bootstrap_gen(T) = insample_obs[rand(1:length(insample_obs), T)]
gaussian_gen(T)  = rand(Normal(μ_is, σ_is), T)
laplace_gen(T)   = rand(Laplace(μ_is, lap_b), T)

@info "Generating baseline IS paths..."
boot_is   = gen_paths(bootstrap_gen, T_is, _N_PATHS)
gauss_is  = gen_paths(gaussian_gen, T_is, _N_PATHS)
lap_is    = gen_paths(laplace_gen, T_is, _N_PATHS)

@info "Generating baseline OoS paths..."
boot_oos  = gen_paths(bootstrap_gen, T_oos, _N_PATHS)
gauss_oos = gen_paths(gaussian_gen, T_oos, _N_PATHS)
lap_oos   = gen_paths(laplace_gen, T_oos, _N_PATHS)

# GARCH
@info "Fitting GARCH(1,1)..."
garch_fit = fit(GARCH{1, 1}, insample_obs)

@info "Simulating GARCH paths..."
garch_is  = hcat([ARCHModels.simulate(garch_fit, T_is).data for _ in 1:_N_PATHS]...)
garch_oos = hcat([ARCHModels.simulate(garch_fit, T_oos).data for _ in 1:_N_PATHS]...)

# ── 6. Compute all metrics ───────────────────────────────────────────────────

model_names = ["Bootstrap", "Gaussian", "Laplace", "GARCH(1,1)", "HMM-NJ", "HMM-WJ"]
is_paths  = [boot_is, gauss_is, lap_is, garch_is, nj_is, wj_is]
oos_paths = [boot_oos, gauss_oos, lap_oos, garch_oos, nj_oos, wj_oos]

results_is  = Dict{String, NamedTuple}()
results_oos = Dict{String, NamedTuple}()

for (name, paths) in zip(model_names, is_paths)
    @info "Computing IS metrics: $name..."
    results_is[name] = compute_all_metrics(insample_obs, paths)
end

for (name, paths) in zip(model_names, oos_paths)
    @info "Computing OoS metrics: $name..."
    results_oos[name] = compute_all_metrics(g_oos, paths)
end

# ── 7. Print Table 2 ─────────────────────────────────────────────────────────

function print_row(label, res, model_names, getter; fmt_fn)
    row = @sprintf("  %-24s", label)
    for m in model_names
        r = res[m]
        val, se = getter(r)
        row *= @sprintf("  %16s", fmt_fn(val, se))
    end
    println(row)
end

fmt_pct(v, s)  = @sprintf("%5.1f (%3.1f)", v, s)
fmt_dec(v, s)  = @sprintf("%5.3f (%5.3f)", v, s)
fmt_kurt(v, s) = @sprintf("%5.1f (%4.2f)", v, s)

function print_full_table(obs, res, window)
    println("\n  $window:")
    hdr = @sprintf("  %-24s", "Metric")
    for m in model_names; hdr *= @sprintf("  %16s", m); end
    println(hdr)
    println("  " * "-"^(24 + 18 * length(model_names)))

    print_row("KS pass rate (%)", res, model_names, r -> (r.ks_pass, r.ks_se); fmt_fn=fmt_pct)
    print_row("AD pass rate (%)", res, model_names, r -> (r.ad_pass, r.ad_se); fmt_fn=fmt_pct)

    row = @sprintf("  %-24s", "Kurtosis (observed)")
    k_obs = @sprintf("%.3f", kurtosis(obs))
    for _ in model_names; row *= @sprintf("  %16s", k_obs); end
    println(row)

    print_row("Kurtosis (simulated)", res, model_names, r -> (r.kurt, r.kurt_se); fmt_fn=fmt_kurt)
    print_row("ACF-MAE", res, model_names, r -> (r.acf_mae, r.acf_se); fmt_fn=fmt_dec)
    print_row("Novelty", res, model_names, r -> (r.novelty, r.novelty_se); fmt_fn=fmt_dec)
    print_row("Diversity", res, model_names, r -> (r.diversity, r.diversity_se); fmt_fn=fmt_dec)
    print_row("Coverage (%)", res, model_names, r -> (r.coverage, r.coverage_se); fmt_fn=fmt_pct)
    print_row("Wasserstein-1", res, model_names, r -> (r.w1, r.w1_se); fmt_fn=fmt_dec)
    print_row("Hellinger dist", res, model_names, r -> (r.hellinger, r.hellinger_se); fmt_fn=fmt_dec)
end

println("\n" * "="^140)
println("  Table 2 — Student-t(df=$(_DF)) Emissions")
println("  $_N_PATHS simulated paths, α=$(_ALPHA)")
println("  HMM-WJ: ε=$(model_wj.jump.ϵ), λ=$(model_wj.jump.λ)")
println("="^140)

print_full_table(insample_obs, results_is,
                 "In-sample: $T_is trading days (2014-2024)")
print_full_table(g_oos, results_oos,
                 "Out-of-sample: $T_oos trading days (2025)")

# Parameters
let row = @sprintf("  %-24s", "Parameters estimated")
    for p in [0, 2, 2, 3, 2, 4]; row *= @sprintf("  %16d", p); end
    println(); println(row)
end

println("\n" * "="^140)

# ── 8. Save JumpHMM model for downstream scripts ────────────────────────────
@info "Saving JumpHMM model to JLD2..."
save(_JLD2_HMM, Dict(
    "insampledataset"  => insample_obs,
    "model_nj"         => model_nj,
    "model_wj"         => model_wj,
    "number_of_states" => N_STATES,
))

@info "Done."
