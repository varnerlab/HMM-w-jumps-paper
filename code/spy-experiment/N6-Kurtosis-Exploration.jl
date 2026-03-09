# =============================================================================
# N6-Kurtosis-Exploration.jl
#
# Explores two approaches to reduce the kurtosis gap between observed (7.7)
# and simulated (5.5) excess growth rates:
#
#   A. Tail-concentrated bins: 3x finer resolution in the bottom/top 5%
#      of the Laplace distribution, with Normal emissions per state.
#
#   B. Student-t emissions: standard equal-probability Laplace bins, but
#      each state emits from a location-scale Student-t instead of Normal.
#
# Both variants use the same jump mechanism (epsilon*=1e-4, lambda*=100)
# and are compared against the baseline HMM-WJ on kurtosis, KS/AD pass
# rates, and ACF-MAE.
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
const N        = 100
const _N_TAIL  = 5
const _P_NEG   = 0.52
const _EPS_STAR = 1e-4
const _LAM_STAR = 100.0

# ── 1. Load SPY data ────────────────────────────────────────────────────────
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
T_is = length(g_is)

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
T_oos = length(g_oos)

obs_kurt_is  = kurtosis(g_is)
obs_kurt_oos = kurtosis(g_oos)
obs_acf_is   = autocor(abs.(g_is), collect(1:_L_ACF))
obs_acf_oos  = autocor(abs.(g_oos), collect(1:min(_L_ACF, T_oos - 1)))

@info "  IS: T=$(T_is), kurtosis=$(round(obs_kurt_is, digits=3))"
@info "  OoS: T=$(T_oos), kurtosis=$(round(obs_kurt_oos, digits=3))"

# ── 2. Helper functions ─────────────────────────────────────────────────────

"""Build a complete HMM-WJ model from a quantile grid and emission type."""
function build_model(g::Vector{Float64}, pct_grid::Vector{Float64},
                     d_base::Distribution; emission_type::Symbol = :normal,
                     student_df::Float64 = 5.0)

    n_states = length(pct_grid) - 1
    states = collect(1:n_states)

    # Quantile boundaries from the fitted distribution
    bounds = Matrix{Float64}(undef, n_states, 2)
    for s in states
        bounds[s, 1] = quantile(d_base, pct_grid[s])
        bounds[s, 2] = quantile(d_base, pct_grid[s + 1])
    end
    bounds[1, 1]         = -Inf
    bounds[n_states, 2]  = +Inf

    # Encode observations to states
    T_obs = length(g)
    encoded = Vector{Int}(undef, T_obs)
    for i in eachindex(g)
        v = g[i]
        encoded[i] = n_states  # default to last state
        for s in states
            if bounds[s, 1] <= v < bounds[s, 2]
                encoded[i] = s
                break
            end
        end
    end

    # Count transitions -> stochastic matrix
    P = zeros(n_states, n_states)
    for i in 2:T_obs
        P[encoded[i-1], encoded[i]] += 1.0
    end
    P_hat = zeros(n_states, n_states)
    for row in states
        Z = sum(P[row, :])
        if Z > 0
            P_hat[row, :] = P[row, :] ./ Z
        else
            P_hat[row, :] .= 1.0 / n_states
        end
    end

    # Transition dictionary (for simulation)
    T_dict = Dict{Int, Categorical}()
    for s in states
        T_dict[s] = Categorical(P_hat[s, :])
    end

    # Stationary distribution
    pi_bar = Categorical((P_hat^50)[1, :])

    # Emission distributions
    decode = Dict{Int, Distribution}()
    for s in states
        idxs = findall(x -> x == s, encoded)
        if length(idxs) >= 2
            obs_in_state = g[idxs]
            mu_s = mean(obs_in_state)
            sigma_s = std(obs_in_state)
            if sigma_s < 1e-12
                sigma_s = std(g)
            end

            if emission_type == :normal
                decode[s] = Normal(mu_s, sigma_s)
            elseif emission_type == :student_t
                # Location-scale Student-t: mu + sigma * t(df)
                decode[s] = LocationScale(mu_s, sigma_s, TDist(student_df))
            end
        else
            # Fallback
            if emission_type == :normal
                decode[s] = Normal(mean(g), std(g))
            elseif emission_type == :student_t
                decode[s] = LocationScale(mean(g), std(g), TDist(student_df))
            end
        end
    end

    # State occupancy diagnostics
    counts = [count(x -> x == s, encoded) for s in states]
    empty_states = count(x -> x == 0, counts)
    min_count = minimum(counts)

    return (T_dict = T_dict, pi_bar = pi_bar, decode = decode,
            n_states = n_states, bounds = bounds, encoded = encoded,
            empty_states = empty_states, min_count = min_count,
            state_counts = counts)
end

"""Simulate one jump path."""
function simulate_jump_path(T_dict::Dict, pi_bar, decode::Dict,
                            eps::Float64, lam::Float64, n_steps::Int,
                            n_states::Int;
                            n_tail::Int = _N_TAIL, p_neg::Float64 = _P_NEG)

    bottom = collect(1:n_tail)
    top    = collect((n_states - n_tail + 1):n_states)
    states = Vector{Int}(undef, n_steps)

    states[1] = rand(pi_bar)
    t = 2
    while t <= n_steps
        if rand() < eps
            K = rand(Poisson(lam))
            if K > 0
                for _ in 1:K
                    t > n_steps && break
                    states[t] = rand() < p_neg ? rand(bottom) : rand(top)
                    t += 1
                end
            else
                states[t] = rand(T_dict[states[t-1]])
                t += 1
            end
        else
            states[t] = rand(T_dict[states[t-1]])
            t += 1
        end
    end

    decoded = [rand(decode[s]) for s in states]
    return decoded
end

"""Simulate n_paths and compute metrics."""
function evaluate_model(model, g_obs::Vector{Float64}, n_steps::Int;
                        eps::Float64 = _EPS_STAR, lam::Float64 = _LAM_STAR,
                        n_paths::Int = _N_PATHS)

    L = min(_L_ACF, n_steps - 1)
    lags = collect(1:L)
    obs_acf = autocor(abs.(g_obs), lags)

    paths = Matrix{Float64}(undef, n_steps, n_paths)
    for i in 1:n_paths
        paths[:, i] = simulate_jump_path(model.T_dict, model.pi_bar,
                                          model.decode, eps, lam, n_steps,
                                          model.n_states)
    end

    # Metrics
    ks_pvals  = Vector{Float64}(undef, n_paths)
    ad_pvals  = Vector{Float64}(undef, n_paths)
    kurt_vals = Vector{Float64}(undef, n_paths)
    acf_mat   = Matrix{Float64}(undef, L, n_paths)

    Threads.@threads for i in 1:n_paths
        sim = paths[:, i]
        ks_pvals[i]   = pvalue(ApproximateTwoSampleKSTest(g_obs, sim))
        ad_pvals[i]   = pvalue(KSampleADTest(g_obs, sim))
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

    # Bootstrap SE for ACF-MAE
    boot_mae = Vector{Float64}(undef, _N_BOOT)
    for b in 1:_N_BOOT
        idx = rand(1:n_paths, n_paths)
        mean_acf_b = vec(mean(acf_mat[:, idx], dims = 2))
        boot_mae[b] = mean(abs.(obs_acf .- mean_acf_b))
    end
    mae_se = std(boot_mae)

    return (ks_pass = 100.0 * ks_pass, ks_se = 100.0 * ks_se,
            ad_pass = 100.0 * ad_pass, ad_se = 100.0 * ad_se,
            kurt = kurt_m, kurt_se = kurt_se,
            acf_mae = acf_mae, acf_mae_se = mae_se)
end

# ── 3. Build quantile grids ────────────────────────────────────────────────

# Fit Laplace to training data (same as baseline)
d_laplace = fit_mle(Laplace, g_is)

# Grid A: equal-probability (baseline)
pct_equal = collect(range(0.0, 1.0, length = N + 1))

# Grid B: tail-concentrated — 3x finer resolution in bottom/top 5%
# Bottom 5%: 15 bins (each ~0.33%), Middle 90%: 70 bins (each ~1.29%), Top 5%: 15 bins
pct_tail = vcat(
    range(0.0,  0.05, length = 16)[1:end-1],   # 15 bins in [0, 0.05)
    range(0.05, 0.95, length = 71)[1:end-1],    # 70 bins in [0.05, 0.95)
    range(0.95, 1.0,  length = 16)              # 15 bins in [0.95, 1.0]
) |> collect

@info "Quantile grid sizes: equal=$(length(pct_equal)-1), tail=$(length(pct_tail)-1)"

# ── 4. Build all model variants ─────────────────────────────────────────────

@info "Building models..."

# Baseline: equal-prob bins, Normal emissions
model_baseline = build_model(g_is, pct_equal, d_laplace; emission_type = :normal)
@info "  Baseline: $(model_baseline.n_states) states, min_count=$(model_baseline.min_count), empty=$(model_baseline.empty_states)"

# Variant A: tail-concentrated bins, Normal emissions
model_tail = build_model(g_is, pct_tail, d_laplace; emission_type = :normal)
@info "  Tail-conc: $(model_tail.n_states) states, min_count=$(model_tail.min_count), empty=$(model_tail.empty_states)"

# Variant B: equal-prob bins, Student-t emissions (df=5)
model_t5 = build_model(g_is, pct_equal, d_laplace; emission_type = :student_t, student_df = 5.0)
@info "  Student-t(5): $(model_t5.n_states) states, min_count=$(model_t5.min_count), empty=$(model_t5.empty_states)"

# Variant C: equal-prob bins, Student-t emissions (df=3) — heavier tails
model_t3 = build_model(g_is, pct_equal, d_laplace; emission_type = :student_t, student_df = 3.0)
@info "  Student-t(3): $(model_t3.n_states) states, min_count=$(model_t3.min_count), empty=$(model_t3.empty_states)"

# Variant D: tail-concentrated bins + Student-t(5) emissions
model_tail_t5 = build_model(g_is, pct_tail, d_laplace; emission_type = :student_t, student_df = 5.0)
@info "  Tail+t(5): $(model_tail_t5.n_states) states, min_count=$(model_tail_t5.min_count), empty=$(model_tail_t5.empty_states)"

# ── 5. Evaluate all variants ────────────────────────────────────────────────

models = [
    ("Baseline (equal, Normal)", model_baseline),
    ("Tail-conc (3x, Normal)",   model_tail),
    ("Equal bins, t(df=5)",      model_t5),
    ("Equal bins, t(df=3)",      model_t3),
    ("Tail-conc + t(df=5)",      model_tail_t5),
]

println("\n" * "="^100)
println("  N6 Kurtosis Exploration — HMM-WJ with ε*=$(_EPS_STAR), λ*=$(_LAM_STAR)")
println("="^100)

for window in [:IS, :OoS]
    g_obs   = window == :IS ? g_is : g_oos
    n_steps = window == :IS ? T_is : T_oos
    obs_k   = window == :IS ? obs_kurt_is : obs_kurt_oos

    println("\n  $(window) — observed kurtosis: $(round(obs_k, digits=3))")
    @printf("  %-28s  %14s  %14s  %14s  %14s\n",
            "Variant", "Kurtosis", "KS pass%", "AD pass%", "ACF-MAE")
    println("  " * "-"^88)

    for (name, model) in models
        @info "  Evaluating: $(name) [$(window)]..."
        r = evaluate_model(model, g_obs, n_steps)
        @printf("  %-28s  %6.1f (%4.2f)  %6.1f (%4.1f)  %6.1f (%4.1f)  %6.3f (%5.3f)\n",
                name, r.kurt, r.kurt_se,
                r.ks_pass, r.ks_se, r.ad_pass, r.ad_se,
                r.acf_mae, r.acf_mae_se)
    end
end

println("\n" * "="^100)
@info "Done."
