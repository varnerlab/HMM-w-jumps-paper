# =============================================================================
# Table3-Sensitivity-ACF-MAE.jl
#
# Rebuilds HMM-NJ and HMM-WJ models from scratch for N ∈ {30, 60, 90, 100, 150, 200},
# simulates 1,000 paths from each, and computes KS pass rate, AD pass rate,
# and ACF-MAE (lags 1–252) with standard errors to populate Table 3.
#
# SE methodology:
#   KS/AD pass rate — binomial SE: sqrt(p̂(1-p̂)/n)
#   ACF-MAE         — bootstrap SE (B=500 resamples of the 1,000 paths)
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const _RF_IS      = 0.043
const _DT         = 1.0 / 252.0
const _N_PATHS    = 1_000
const _L_ACF      = 252
const _ALPHA      = 0.05
const _EPS        = 0.0001
const _LAM        = 100.0
const _N_BOOT     = 500          # bootstrap resamples for ACF-MAE SE

# ── 1. Load SPY excess growth rates ─────────────────────────────────────────
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

spy_idx = findfirst(x -> x == "SPY", tickers_train)
Rᵢ      = all_growth_train[:, spy_idx]
g_is    = Rᵢ[1:(max_days_train - 1)]
T_is    = length(g_is)

@info "  IS observations: $T_is"

obs_acf = autocor(abs.(g_is), collect(1:_L_ACF))

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

# ── 3. Helper: build model + simulate + compute all metrics + SEs ────────────
function build_and_evaluate(N::Int, g_is::Vector{Float64}, Rᵢ::Vector{Float64},
                            obs_acf::Vector{Float64}; with_jumps::Bool = false)

    T_is = length(g_is)
    states = collect(1:N)

    # (a) Laplace fit + quantile bins
    d = fit_mle(Laplace, Rᵢ)
    pct = range(0.0, 1.0, length = N + 1) |> collect
    bounds = Array{Float64,2}(undef, N, 2)
    for s in states
        bounds[s, 1] = quantile(d, pct[s])
        bounds[s, 2] = quantile(d, pct[s + 1])
    end

    # (b) Encode observations → state sequence
    encoded = Vector{Int}(undef, T_is)
    for i in eachindex(g_is)
        v = g_is[i]
        encoded[i] = 1
        for s in states
            if bounds[s, 1] ≤ v < bounds[s, 2]
                encoded[i] = s
                break
            end
        end
    end

    # (c) Count transitions → normalize
    P = zeros(N, N)
    for i in 2:T_is
        P[encoded[i-1], encoded[i]] += 1.0
    end

    P̂ = zeros(N, N)
    for row in states
        Z = sum(P[row, :])
        if Z > 0
            P̂[row, :] = P[row, :] ./ Z
        else
            P̂[row, :] .= 1.0 / N
        end
    end

    # (d) Stationary distribution
    π̄ = Categorical((P̂^50)[1, :])

    # (e) Decode distributions
    decode = Dict{Int,Normal}()
    for s in states
        idxs = findall(x -> x == s, encoded)
        if length(idxs) >= 2
            decode[s] = fit_mle(Normal, Rᵢ[idxs])
        else
            decode[s] = Normal(mean(Rᵢ), std(Rᵢ))
        end
    end

    # (f) Build model + simulate
    E = diagm(ones(N))
    if with_jumps
        model = build(MyHiddenMarkovModelWithJumps, (
            states = states, T = P̂, E = E, ϵ = _EPS, λ = _LAM,
        ))
    else
        model = build(MyHiddenMarkovModel, (
            states = states, T = P̂, E = E,
        ))
    end

    paths = Matrix{Float64}(undef, T_is, _N_PATHS)
    for i in 1:_N_PATHS
        start = rand(π̄)
        result = model(start, T_is)
        for j in 1:T_is
            s = result[j, 1]
            paths[j, i] = rand(decode[s])
        end
    end

    # (g) Compute metrics
    lags = collect(1:_L_ACF)
    ks_pvals = Vector{Float64}(undef, _N_PATHS)
    ad_pvals = Vector{Float64}(undef, _N_PATHS)
    acf_mat  = Matrix{Float64}(undef, _L_ACF, _N_PATHS)

    Threads.@threads for i in 1:_N_PATHS
        sim = paths[:, i]
        ks_pvals[i]   = pvalue(ApproximateTwoSampleKSTest(g_is, sim))
        ad_pvals[i]   = pvalue(KSampleADTest(g_is, sim))
        acf_mat[:, i] = autocor(abs.(sim), lags)
    end

    # Point estimates
    ks_pass = mean(ks_pvals .> _ALPHA)
    ad_pass = mean(ad_pvals .> _ALPHA)
    mean_acf = vec(mean(acf_mat, dims = 2))
    acf_mae  = mean(abs.(obs_acf .- mean_acf))

    # Standard errors
    ks_se  = sqrt(ks_pass * (1 - ks_pass) / _N_PATHS)
    ad_se  = sqrt(ad_pass * (1 - ad_pass) / _N_PATHS)
    mae_se = bootstrap_acf_mae_se(acf_mat, obs_acf)

    return (
        ks_pass  = 100.0 * ks_pass,
        ks_se    = 100.0 * ks_se,
        ad_pass  = 100.0 * ad_pass,
        ad_se    = 100.0 * ad_se,
        acf_mae  = acf_mae,
        acf_mae_se = mae_se,
    )
end

# ── 4. Run for each (model_type, N) combination ─────────────────────────────
N_values = [200, 150, 100, 90, 60, 30]
results = Dict{Tuple{String,Int}, Any}()

for N in N_values
    @info "Building HMM-NJ with N=$N..."
    results[("NJ", N)] = build_and_evaluate(N, g_is, Rᵢ, obs_acf; with_jumps = false)
    r = results[("NJ", N)]
    @info "  NJ N=$N  KS=$(r.ks_pass)±$(round(r.ks_se,digits=1))  AD=$(r.ad_pass)±$(round(r.ad_se,digits=1))  ACF-MAE=$(round(r.acf_mae,digits=3))±$(round(r.acf_mae_se,digits=3))"

    @info "Building HMM-WJ with N=$N..."
    results[("WJ", N)] = build_and_evaluate(N, g_is, Rᵢ, obs_acf; with_jumps = true)
    r = results[("WJ", N)]
    @info "  WJ N=$N  KS=$(r.ks_pass)±$(round(r.ks_se,digits=1))  AD=$(r.ad_pass)±$(round(r.ad_se,digits=1))  ACF-MAE=$(round(r.acf_mae,digits=3))±$(round(r.acf_mae_se,digits=3))"
end

# ── 5. Print results ─────────────────────────────────────────────────────────
println("\n" * "="^90)
println("  Table 3 — Full Results with SEs")
println("="^90)
@printf("  %-8s  %4s  %16s  %16s  %16s\n", "Model", "N", "KS pass%", "AD pass%", "ACF-MAE")
println("-"^90)
for N in N_values
    r = results[("NJ", N)]
    @printf("  %-8s  %4d  %5.1f (%.1f)     %5.1f (%.1f)     %5.3f (%.3f)\n",
        "HMM-NJ", N, r.ks_pass, r.ks_se, r.ad_pass, r.ad_se, r.acf_mae, r.acf_mae_se)
end
println("-"^90)
for N in N_values
    r = results[("WJ", N)]
    @printf("  %-8s  %4d  %5.1f (%.1f)     %5.1f (%.1f)     %5.3f (%.3f)\n",
        "HMM-WJ", N, r.ks_pass, r.ks_se, r.ad_pass, r.ad_se, r.acf_mae, r.acf_mae_se)
end
println("="^90)

println("\nLaTeX-ready rows (SEs in parentheses):")
for N in N_values
    r = results[("NJ", N)]
    @printf("HMM-NJ & %d & %.1f (%.1f) & %.1f (%.1f) & %.3f (%.3f) \\\\\n",
        N, r.ks_pass, r.ks_se, r.ad_pass, r.ad_se, r.acf_mae, r.acf_mae_se)
end
println("\\midrule")
for N in N_values
    r = results[("WJ", N)]
    @printf("HMM-WJ & %d & %.1f (%.1f) & %.1f (%.1f) & %.3f (%.3f) \\\\\n",
        N, r.ks_pass, r.ks_se, r.ad_pass, r.ad_se, r.acf_mae, r.acf_mae_se)
end

@info "Done."
