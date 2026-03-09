# =============================================================================
# N6-df-Sensitivity.jl
#
# Sweep Student-t degrees of freedom (df) for within-state emissions.
# Reports kurtosis, KS/AD pass rates, and ACF-MAE for each df value.
# df=Inf recovers the Normal baseline.
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const _RF_IS   = 0.043
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

obs_kurt = kurtosis(g_is)
obs_acf  = autocor(abs.(g_is), collect(1:_L_ACF))
@info "  IS: T=$(T_is), observed kurtosis=$(round(obs_kurt, digits=3))"

# ── 2. Build model for a given df ──────────────────────────────────────────

function build_model_with_df(g::Vector{Float64}, df_val::Float64)
    d_laplace = fit_mle(Laplace, g)
    n_states = N
    states = collect(1:n_states)

    # Equal-probability Laplace quantile partition
    pct = collect(range(0.0, 1.0, length = n_states + 1))
    bounds = Matrix{Float64}(undef, n_states, 2)
    for s in states
        bounds[s, 1] = quantile(d_laplace, pct[s])
        bounds[s, 2] = quantile(d_laplace, pct[s + 1])
    end
    bounds[1, 1] = -Inf
    bounds[n_states, 2] = +Inf

    # Encode
    T_obs = length(g)
    encoded = Vector{Int}(undef, T_obs)
    for i in eachindex(g)
        v = g[i]
        encoded[i] = n_states
        for s in states
            if bounds[s, 1] <= v < bounds[s, 2]
                encoded[i] = s
                break
            end
        end
    end

    # Transition matrix
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

    T_dict = Dict{Int, Categorical}()
    for s in states
        T_dict[s] = Categorical(P_hat[s, :])
    end
    pi_bar = Categorical((P_hat^50)[1, :])

    # Emissions: Normal if df_val >= 1000, else Student-t
    decode = Dict{Int, Distribution}()
    for s in states
        idxs = findall(x -> x == s, encoded)
        if length(idxs) >= 2
            mu_s = mean(g[idxs])
            sigma_s = std(g[idxs])
            sigma_s < 1e-12 && (sigma_s = std(g))
            if df_val >= 1000.0
                decode[s] = Normal(mu_s, sigma_s)
            else
                decode[s] = LocationScale(mu_s, sigma_s, TDist(df_val))
            end
        else
            if df_val >= 1000.0
                decode[s] = Normal(mean(g), std(g))
            else
                decode[s] = LocationScale(mean(g), std(g), TDist(df_val))
            end
        end
    end

    return (T_dict = T_dict, pi_bar = pi_bar, decode = decode, n_states = n_states)
end

# ── 3. Simulate and evaluate ───────────────────────────────────────────────

function simulate_and_eval(model, g_obs::Vector{Float64}, n_steps::Int)
    bottom = collect(1:_N_TAIL)
    top    = collect((model.n_states - _N_TAIL + 1):model.n_states)
    lags   = collect(1:_L_ACF)
    obs_acf_local = autocor(abs.(g_obs), lags)

    paths = Matrix{Float64}(undef, n_steps, _N_PATHS)
    for i in 1:_N_PATHS
        states = Vector{Int}(undef, n_steps)
        states[1] = rand(model.pi_bar)
        t = 2
        while t <= n_steps
            if rand() < _EPS_STAR
                K = rand(Poisson(_LAM_STAR))
                if K > 0
                    for _ in 1:K
                        t > n_steps && break
                        states[t] = rand() < _P_NEG ? rand(bottom) : rand(top)
                        t += 1
                    end
                else
                    states[t] = rand(model.T_dict[states[t-1]])
                    t += 1
                end
            else
                states[t] = rand(model.T_dict[states[t-1]])
                t += 1
            end
        end
        for j in 1:n_steps
            paths[j, i] = rand(model.decode[states[j]])
        end
    end

    ks_pvals  = Vector{Float64}(undef, _N_PATHS)
    ad_pvals  = Vector{Float64}(undef, _N_PATHS)
    kurt_vals = Vector{Float64}(undef, _N_PATHS)
    acf_mat   = Matrix{Float64}(undef, _L_ACF, _N_PATHS)

    Threads.@threads for i in 1:_N_PATHS
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
    acf_mae  = mean(abs.(obs_acf_local .- mean_acf))

    ks_se   = sqrt(ks_pass * (1 - ks_pass) / _N_PATHS)
    ad_se   = sqrt(ad_pass * (1 - ad_pass) / _N_PATHS)
    kurt_se = std(kurt_vals) / sqrt(_N_PATHS)

    boot_mae = Vector{Float64}(undef, _N_BOOT)
    for b in 1:_N_BOOT
        idx = rand(1:_N_PATHS, _N_PATHS)
        mean_acf_b = vec(mean(acf_mat[:, idx], dims = 2))
        boot_mae[b] = mean(abs.(obs_acf_local .- mean_acf_b))
    end
    mae_se = std(boot_mae)

    return (ks_pass = 100.0 * ks_pass, ks_se = 100.0 * ks_se,
            ad_pass = 100.0 * ad_pass, ad_se = 100.0 * ad_se,
            kurt = kurt_m, kurt_se = kurt_se,
            acf_mae = acf_mae, acf_mae_se = mae_se)
end

# ── 4. Sweep df values ──────────────────────────────────────────────────────

df_values = [3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 15.0, 30.0, Inf]
df_labels = ["3", "4", "5", "6", "7", "8", "10", "15", "30", "Normal"]

println("\n" * "="^100)
println("  Student-t df Sensitivity — HMM-WJ, N=$(N), ε=$(_EPS_STAR), λ=$(_LAM_STAR)")
println("  Observed IS kurtosis: $(round(obs_kurt, digits=3))")
println("="^100)
@printf("  %-10s  %14s  %14s  %14s  %14s  %10s\n",
        "df", "Kurtosis", "KS pass%", "AD pass%", "ACF-MAE", "Kurt gap%")
println("  " * "-"^90)

for (df_val, df_lab) in zip(df_values, df_labels)
    df_build = df_val == Inf ? 10000.0 : df_val
    @info "Building and evaluating df=$(df_lab)..."
    model = build_model_with_df(g_is, df_build)
    r = simulate_and_eval(model, g_is, T_is)
    gap_pct = 100.0 * abs(r.kurt - obs_kurt) / obs_kurt
    @printf("  %-10s  %6.1f (%4.2f)  %6.1f (%4.1f)  %6.1f (%4.1f)  %6.3f (%5.3f)  %8.1f%%\n",
            df_lab, r.kurt, r.kurt_se,
            r.ks_pass, r.ks_se, r.ad_pass, r.ad_se,
            r.acf_mae, r.acf_mae_se, gap_pct)
end

println("="^100)
@info "Done."
