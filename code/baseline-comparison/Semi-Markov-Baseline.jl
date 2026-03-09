# =============================================================================
# Semi-Markov-Baseline.jl
#
# Implements a Hidden Semi-Markov Model (HSMM) baseline following
# Bulla & Bulla (2006). Uses K states with negative-binomial dwell-time
# distributions and Student-t(5) emissions.
#
# Key difference from standard HMM: dwell times in each state are explicitly
# modeled (NegBin) rather than implicitly geometric. This is the approach
# cited in the paper as the prior solution to the volatility clustering gap.
#
# We sweep K in {3, 4, 5, 6, 8} and report the best-performing configuration
# along with the sweep results.
#
# The evaluation uses the same metrics as Table 2 (KS, AD, kurtosis, ACF-MAE,
# W1, Hellinger, novelty, diversity, coverage) with standard errors.
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
const _COV_QUANTILES = collect(0.01:0.01:0.99)
const _N_BINS  = 50
const _DF      = 5.0

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
g_oos = all_growth_test[:, spy_idx_test][1:(max_days_test - 1)]

# Also load insample_obs from JLD2 (same series, used for consistency)
hmm_dict     = load(_JLD2_HMM)
insample_obs = hmm_dict["insampledataset"]
T_is  = length(insample_obs)
T_oos = length(g_oos)
@info "  IS: T=$(T_is), OoS: T=$(T_oos)"

# ── 2. Metric computation (reused from Baseline-Comparison.jl) ──────────────

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

# ── 3. HSMM model construction ──────────────────────────────────────────────

"""
Build an HSMM from data using K equal-probability Laplace quantile states.

Returns:
  - decode: Dict{Int, Distribution} — Student-t(5) emission per state
  - trans:  Matrix{Float64} — K×K transition matrix (self-transitions zeroed, rows normalized)
  - dwell:  Dict{Int, Distribution} — per-state dwell-time distribution (NegBin or Geometric)
  - pi_bar: Vector{Float64} — stationary state probabilities (from occupancy)
  - K:      Int
"""
function build_hsmm(g::Vector{Float64}; K::Int = 4)
    d_laplace = fit_mle(Laplace, g)
    states = collect(1:K)

    # Quantile boundaries
    pct = collect(range(0.0, 1.0, length = K + 1))
    bounds = Matrix{Float64}(undef, K, 2)
    for s in states
        bounds[s, 1] = quantile(d_laplace, pct[s])
        bounds[s, 2] = quantile(d_laplace, pct[s + 1])
    end
    bounds[1, 1] = -Inf
    bounds[K, 2] = +Inf

    # Encode observations to states
    T_obs = length(g)
    encoded = Vector{Int}(undef, T_obs)
    for i in eachindex(g)
        v = g[i]
        encoded[i] = K
        for s in states
            if bounds[s, 1] <= v < bounds[s, 2]
                encoded[i] = s
                break
            end
        end
    end

    # ── Extract run lengths (dwell times) per state ──────────────────────────
    runs = Dict{Int, Vector{Int}}()
    for s in states; runs[s] = Int[]; end

    current_state = encoded[1]
    current_len = 1
    for i in 2:T_obs
        if encoded[i] == current_state
            current_len += 1
        else
            push!(runs[current_state], current_len)
            current_state = encoded[i]
            current_len = 1
        end
    end
    push!(runs[current_state], current_len)  # last run

    # ── Fit dwell-time distributions ─────────────────────────────────────────
    # Use NegativeBinomial(r, p) where mean = r(1-p)/p, var = r(1-p)/p^2
    # Fallback to Geometric if insufficient data or if NegBin fit fails
    dwell = Dict{Int, Distribution}()
    for s in states
        d = runs[s]
        if length(d) >= 5 && mean(d) > 1.01
            m = mean(d)
            v = var(d)
            if v > m  # overdispersed: NegBin is appropriate
                # Method of moments: r = m^2/(v - m), p = m/v
                r_est = m^2 / (v - m)
                p_est = m / v
                r_est = max(r_est, 0.1)  # floor
                p_est = clamp(p_est, 0.01, 0.99)
                dwell[s] = NegativeBinomial(r_est, p_est)
            else
                # Underdispersed or equidispersed: use Geometric
                # Geometric(p) has mean = (1-p)/p, so p = 1/mean
                p_geo = 1.0 / m
                p_geo = clamp(p_geo, 0.01, 0.99)
                dwell[s] = Geometric(p_geo)
            end
        else
            # Too few runs: fallback to Geometric with empirical mean
            m = length(d) > 0 ? mean(d) : 1.0
            p_geo = 1.0 / max(m, 1.0)
            p_geo = clamp(p_geo, 0.01, 0.99)
            dwell[s] = Geometric(p_geo)
        end
    end

    # ── Transition matrix (excluding self-transitions) ───────────────────────
    trans_counts = zeros(K, K)
    for i in 2:T_obs
        if encoded[i] != encoded[i-1]
            # This is a state transition (end of a run)
            trans_counts[encoded[i-1], encoded[i]] += 1.0
        end
    end
    # Zero out diagonal and normalize
    trans = zeros(K, K)
    for s in states
        trans_counts[s, s] = 0.0
        Z = sum(trans_counts[s, :])
        if Z > 0
            trans[s, :] = trans_counts[s, :] ./ Z
        else
            # Uniform over other states
            for j in states
                j != s && (trans[s, j] = 1.0 / (K - 1))
            end
        end
    end

    # ── Student-t(5) emissions per state ─────────────────────────────────────
    decode = Dict{Int, Distribution}()
    for s in states
        idxs = findall(x -> x == s, encoded)
        if length(idxs) >= 2
            mu_s = mean(g[idxs])
            sigma_s = std(g[idxs])
            sigma_s < 1e-12 && (sigma_s = std(g))
            decode[s] = LocationScale(mu_s, sigma_s, TDist(_DF))
        else
            decode[s] = LocationScale(mean(g), std(g), TDist(_DF))
        end
    end

    # ── Stationary distribution (from occupancy fractions) ───────────────────
    occ = [count(x -> x == s, encoded) / T_obs for s in states]

    # Diagnostics
    @info "  HSMM K=$K: state counts = $(Int[count(x->x==s, encoded) for s in states])"
    for s in states
        d = runs[s]
        @info "    State $s: $(length(d)) runs, mean dwell = $(round(mean(d), digits=1)), " *
              "dwell dist = $(typeof(dwell[s]).name.name)"
    end

    return (decode = decode, trans = trans, dwell = dwell, pi_bar = occ, K = K)
end

# ── 4. HSMM simulation ──────────────────────────────────────────────────────

"""
Simulate one path from the HSMM.

At each epoch:
  1. Sample dwell time d ~ D_k (minimum 1 step)
  2. Emit d observations from decode[k]
  3. Transition to next state j ~ trans[k, :]
"""
function simulate_hsmm_path(model, n_steps::Int)
    path = Vector{Float64}(undef, n_steps)
    K = model.K

    # Sample initial state from stationary distribution
    state = StatsBase.sample(1:K, Weights(model.pi_bar))
    t = 1

    while t <= n_steps
        # Sample dwell time (minimum 1)
        d = rand(model.dwell[state]) + 1  # +1 because NegBin/Geometric are 0-indexed
        d = max(d, 1)

        # Emit observations for this dwell
        for _ in 1:d
            t > n_steps && break
            path[t] = rand(model.decode[state])
            t += 1
        end

        # Transition to next state (if we haven't exceeded n_steps)
        if t <= n_steps
            probs = model.trans[state, :]
            state = StatsBase.sample(1:K, Weights(probs))
        end
    end

    return path
end

# ── 5. Sweep K values ────────────────────────────────────────────────────────

K_values = [3, 4, 5, 6, 8]

println("\n" * "="^120)
println("  HSMM State Resolution Sweep (Student-t(df=$(_DF)) emissions, NegBin dwell times)")
println("  $_N_PATHS paths, α=$(_ALPHA)")
println("="^120)

best_ks_is = -1.0
best_K = 4
sweep_results = Dict{Int, NamedTuple}()

for K in K_values
    @info "Building HSMM with K=$K..."
    model = build_hsmm(g_is; K = K)

    @info "Simulating $(_N_PATHS) IS paths (K=$K)..."
    paths_is = Matrix{Float64}(undef, T_is, _N_PATHS)
    for i in 1:_N_PATHS
        paths_is[:, i] = simulate_hsmm_path(model, T_is)
    end

    # Quick evaluation: just KS pass rate and ACF-MAE
    lags = collect(1:_L_ACF)
    obs_acf = autocor(abs.(insample_obs), lags)

    ks_pvals = Vector{Float64}(undef, _N_PATHS)
    ad_pvals = Vector{Float64}(undef, _N_PATHS)
    kurt_vals = Vector{Float64}(undef, _N_PATHS)
    acf_mat = Matrix{Float64}(undef, _L_ACF, _N_PATHS)

    Threads.@threads for i in 1:_N_PATHS
        sim = paths_is[:, i]
        ks_pvals[i]   = pvalue(ApproximateTwoSampleKSTest(insample_obs, sim))
        ad_pvals[i]   = pvalue(KSampleADTest(insample_obs, sim))
        kurt_vals[i]  = kurtosis(sim)
        acf_mat[:, i] = autocor(abs.(sim), lags)
    end

    ks_pass = 100.0 * mean(ks_pvals .> _ALPHA)
    ad_pass = 100.0 * mean(ad_pvals .> _ALPHA)
    kurt_m  = mean(kurt_vals)
    mean_acf = vec(mean(acf_mat, dims = 2))
    acf_mae = mean(abs.(obs_acf .- mean_acf))

    obs_kurt = kurtosis(insample_obs)
    gap_pct = 100.0 * abs(kurt_m - obs_kurt) / abs(obs_kurt)

    @printf("  K=%d:  KS=%.1f%%  AD=%.1f%%  Kurt=%.1f (gap %.0f%%)  ACF-MAE=%.3f\n",
            K, ks_pass, ad_pass, kurt_m, gap_pct, acf_mae)

    sweep_results[K] = (ks_pass = ks_pass, ad_pass = ad_pass,
                         kurt = kurt_m, acf_mae = acf_mae, model = model)

    if ks_pass > best_ks_is
        global best_ks_is = ks_pass
        global best_K = K
    end
end

println("\n  Best K = $best_K (IS KS pass = $(round(best_ks_is, digits=1))%)")

# ── 6. Full evaluation of best K ─────────────────────────────────────────────

@info "Running full evaluation for HSMM K=$best_K..."
best_model = sweep_results[best_K].model

@info "Generating IS paths..."
hsmm_is_paths = Matrix{Float64}(undef, T_is, _N_PATHS)
for i in 1:_N_PATHS
    hsmm_is_paths[:, i] = simulate_hsmm_path(best_model, T_is)
end

@info "Generating OoS paths..."
hsmm_oos_paths = Matrix{Float64}(undef, T_oos, _N_PATHS)
for i in 1:_N_PATHS
    hsmm_oos_paths[:, i] = simulate_hsmm_path(best_model, T_oos)
end

@info "Computing IS metrics..."
r_is = compute_all_metrics(insample_obs, hsmm_is_paths)

@info "Computing OoS metrics..."
r_oos = compute_all_metrics(g_oos, hsmm_oos_paths)

# ── 7. Print results ────────────────────────────────────────────────────────

fmt_pct(v, s)  = @sprintf("%5.1f (%3.1f)", v, s)
fmt_dec(v, s)  = @sprintf("%5.3f (%5.3f)", v, s)
fmt_kurt(v, s) = @sprintf("%5.1f (%4.2f)", v, s)

println("\n" * "="^80)
println("  HSMM (K=$best_K) — Full Metrics for Table 2")
println("="^80)

println("\n  In-sample: $T_is trading days (2014-2024):")
println("  " * "-"^70)
@printf("  %-24s  %s\n", "KS pass rate (%)", fmt_pct(r_is.ks_pass, r_is.ks_se))
@printf("  %-24s  %s\n", "AD pass rate (%)", fmt_pct(r_is.ad_pass, r_is.ad_se))
@printf("  %-24s  %s\n", "Kurtosis (observed)", @sprintf("%.3f", kurtosis(insample_obs)))
@printf("  %-24s  %s\n", "Kurtosis (simulated)", fmt_kurt(r_is.kurt, r_is.kurt_se))
@printf("  %-24s  %s\n", "ACF-MAE", fmt_dec(r_is.acf_mae, r_is.acf_se))
@printf("  %-24s  %s\n", "Novelty", fmt_dec(r_is.novelty, r_is.novelty_se))
@printf("  %-24s  %s\n", "Diversity", fmt_dec(r_is.diversity, r_is.diversity_se))
@printf("  %-24s  %s\n", "Coverage (%)", fmt_pct(r_is.coverage, r_is.coverage_se))
@printf("  %-24s  %s\n", "Wasserstein-1", fmt_dec(r_is.w1, r_is.w1_se))
@printf("  %-24s  %s\n", "Hellinger dist", fmt_dec(r_is.hellinger, r_is.hellinger_se))

println("\n  Out-of-sample: $T_oos trading days (2025):")
println("  " * "-"^70)
@printf("  %-24s  %s\n", "KS pass rate (%)", fmt_pct(r_oos.ks_pass, r_oos.ks_se))
@printf("  %-24s  %s\n", "AD pass rate (%)", fmt_pct(r_oos.ad_pass, r_oos.ad_se))
@printf("  %-24s  %s\n", "Kurtosis (observed)", @sprintf("%.3f", kurtosis(g_oos)))
@printf("  %-24s  %s\n", "Kurtosis (simulated)", fmt_kurt(r_oos.kurt, r_oos.kurt_se))
@printf("  %-24s  %s\n", "ACF-MAE", fmt_dec(r_oos.acf_mae, r_oos.acf_se))
@printf("  %-24s  %s\n", "Novelty", fmt_dec(r_oos.novelty, r_oos.novelty_se))
@printf("  %-24s  %s\n", "Diversity", fmt_dec(r_oos.diversity, r_oos.diversity_se))
@printf("  %-24s  %s\n", "Coverage (%)", fmt_pct(r_oos.coverage, r_oos.coverage_se))
@printf("  %-24s  %s\n", "Wasserstein-1", fmt_dec(r_oos.w1, r_oos.w1_se))
@printf("  %-24s  %s\n", "Hellinger dist", fmt_dec(r_oos.hellinger, r_oos.hellinger_se))

# Count parameters: 2 (Laplace μ, b) + 2K (NegBin r,p per state) = 2 + 2K
n_params_hsmm = 2 + 2 * best_K
@printf("\n  Parameters estimated: %d (2 Laplace + %d NegBin dwell)\n",
        n_params_hsmm, 2 * best_K)

println("\n" * "="^80)
@info "Done."
