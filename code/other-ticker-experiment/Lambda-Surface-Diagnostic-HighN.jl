# =============================================================================
# Lambda-Surface-Diagnostic-HighN.jl
#
# Re-runs Lambda-Surface-Diagnostic.jl at n_paths = 2000 (10× the original)
# to test whether the J(ϵ, λ) surface stabilizes or remains chaotic.
#
# Output: data/lambda-surface-highN.jld2
# =============================================================================

include("Include.jl")

const TICKERS  = ["NVDA", "JNJ", "JPM", "SPY"]
const _N       = 100
const _N_PATHS = 2000                # ← 10× the original
const _DF      = 5.0
const _P_NEG   = 0.52
const _N_TAIL  = 5
const _RF_IS   = 0.043
const _DT      = 1.0 / 252.0
const W_κ      = 0.20
const ACF_LAGS = 25
const SEED     = 1234

const ϵ_GRID = collect(range(1e-4, 2.5e-2, length = 20))
const λ_GRID = collect(range(10.0, 160.0, length = 16))

function lambda_surface(model_nj, G_emp::Vector{Float64};
                        ϵ_range = ϵ_GRID, λ_range = λ_GRID,
                        n_paths::Int = _N_PATHS,
                        w_κ::Float64 = W_κ,
                        p_neg::Float64 = _P_NEG, N_tail::Int = _N_TAIL,
                        acf_lags::Int = ACF_LAGS, seed::Int = SEED)
    Random.seed!(seed)

    n_steps  = length(G_emp)
    acf_lags = min(acf_lags, min(length(G_emp), n_steps) - 1)
    lags     = collect(1:acf_lags)
    acf_obs  = autocor(abs.(G_emp), lags)
    κ_obs    = kurtosis(G_emp)

    J_grid       = fill(NaN, length(ϵ_range), length(λ_range))
    J_acf_grid   = fill(NaN, length(ϵ_range), length(λ_range))
    J_κ_grid     = fill(NaN, length(ϵ_range), length(λ_range))
    n_valid_grid = zeros(Int, length(ϵ_range), length(λ_range))

    for (i, ϵc) in enumerate(ϵ_range)
        for (j, λc) in enumerate(λ_range)
            jump_cand = JumpHMM.JumpParameters(Float64(ϵc), Float64(λc);
                                               p_neg = p_neg, N_tail = N_tail)
            candidate = JumpHMM.JumpHiddenMarkovModel(
                model_nj.partition, model_nj.transition, model_nj.emissions,
                model_nj.stationary, jump_cand, model_nj.ν, model_nj.rf, model_nj.dt,
            )
            result = simulate(candidate, n_steps; n_paths = n_paths)

            J_accum     = 0.0
            J_acf_accum = 0.0
            J_κ_accum   = 0.0
            n_valid     = 0
            for path in result.paths
                any(path.jumps) || continue
                acf_sim = autocor(abs.(path.observations), lags)
                κ_sim   = kurtosis(path.observations)
                acf_err = sum((acf_obs .- acf_sim) .^ 2)
                κ_err   = w_κ * (κ_obs - κ_sim)^2
                J_accum     += acf_err + κ_err
                J_acf_accum += acf_err
                J_κ_accum   += κ_err
                n_valid     += 1
            end
            if n_valid > 0
                J_grid[i, j]     = J_accum / n_valid
                J_acf_grid[i, j] = J_acf_accum / n_valid
                J_κ_grid[i, j]   = J_κ_accum / n_valid
                n_valid_grid[i, j] = n_valid
            end
        end
    end
    return (J = J_grid, J_acf = J_acf_grid, J_κ = J_κ_grid,
            n_valid = n_valid_grid)
end

@info "Loading training data..."
train_full = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_train  = nrow(train_full["AAPL"])
train      = Dict(t => df for (t, df) in train_full if nrow(df) == max_train)
tickers_tr = collect(keys(train)) |> sort
G_train    = log_growth_matrix(train, tickers_tr; Δt = _DT, risk_free_rate = _RF_IS)

surfaces = Dict{String, Any}()

for ticker in TICKERS
    println("\n" * "="^70)
    @info "Computing J(ϵ, λ) surface for $ticker at n_paths=$_N_PATHS..."

    idx     = findfirst(==(ticker), tickers_tr)
    g_is    = G_train[1:(max_train - 1), idx]
    prices  = train[ticker][!, :volume_weighted_average_price]
    T_is    = length(g_is)
    @info "  T_is = $T_is, obs kurt = $(round(kurtosis(g_is), digits = 3))"

    model_nj = JumpHMM.fit(JumpHiddenMarkovModel, prices;
                           rf = _RF_IS, N = _N, ν = _DF, dt = _DT)

    surf = lambda_surface(model_nj, g_is)
    surfaces[ticker] = surf

    J = surf.J
    ci = argmin(replace(J, NaN => Inf))
    iϵ, jλ = ci.I
    J_min  = J[iϵ, jλ]
    ϵ_star = ϵ_GRID[iϵ]
    λ_star = λ_GRID[jλ]
    @info @sprintf("  argmin: ϵ*=%.1e, λ*=%.0f, J*=%.5f", ϵ_star, λ_star, J_min)

    @printf("\n  Conditional J(λ | ϵ = ϵ*=%.1e) across the full λ grid:\n", ϵ_star)
    @printf("  %5s  %10s  %10s  %10s  %10s\n",
            "λ", "J", "J_acf", "J_κ", "ΔJ/J*")
    for (j, λ) in enumerate(λ_GRID)
        Jv  = J[iϵ, j]
        Ja  = surf.J_acf[iϵ, j]
        Jk  = surf.J_κ[iϵ, j]
        if !isnan(Jv)
            mark = (j == jλ) ? "  ← argmin" : ""
            @printf("  %5.0f  %10.5f  %10.5f  %10.5f  %+10.3f%s\n",
                    λ, Jv, Ja, Jk, (Jv - J_min)/J_min, mark)
        end
    end
end

out_path = joinpath(_PATH_TO_DATA, "lambda-surface-highN.jld2")
jldsave(out_path; surfaces = surfaces,
        eps_grid = ϵ_GRID, lambda_grid = λ_GRID,
        tickers = TICKERS, seed = SEED, n_paths = _N_PATHS, w_kappa = W_κ)
@info "Saved $out_path"
