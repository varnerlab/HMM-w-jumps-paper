# =============================================================================
# dump_dependence_is_oos.jl
#
# Standalone (does NOT touch the canonical Copula-Comparison.jl).
# Recomputes the 4-asset (SPY, NVDA, JNJ, JPM) cross-asset dependence metrics
# for the Paper I copula comparison in PAPER II's convention, for BOTH the
# in-sample (IS / train) and out-of-sample (OoS / 2025 test) windows.
#
# Convention (Paper II, like-for-like):
#   For each simulated path p:  Sigma_p = cor(sim_path_p)   (4x4)
#   Frobenius error = mean_p norm(Sigma_p - Sigma_obs)      (FULL-matrix Frobenius)
#   Off-diag MAE    = mean_p mean(|(Sigma_p - Sigma_obs)[i!=j]|)
# The simulated paths are the SAME IS-fit draws for both windows; only Sigma_obs
# changes:  Sigma_obs_IS = cor(observed growth, train window),
#           Sigma_obs_OoS = cor(observed growth, 2025 test window).
#
# Validation cross-check: off-diag MAE on the MEAN simulated correlation matrix
# (Paper I's original convention) must reproduce published 0.055 / 0.039 / 0.099.
# =============================================================================

include("Include.jl")
using LinearAlgebra, Statistics, Random

const TICKERS  = ["SPY", "NVDA", "JNJ", "JPM"]
const _RF_IS   = 0.043
const _DT      = 1.0 / 252.0
const _N_PATHS = 1_000
const _N       = 100
const _DF      = 5.0
const _SEED    = 1234

# ── IS (train) data — identical construction to Copula-Comparison.jl ──────────
original_train = MyTrainingMarketDataSet()["dataset"]
max_days_train = nrow(original_train["AAPL"])
train_dataset  = Dict{String,DataFrame}()
for (t, df) in original_train
    nrow(df) == max_days_train && (train_dataset[t] = df)
end
for t in TICKERS
    @assert haskey(train_dataset, t) "Ticker $t not full-length in train"
end
n_days = max_days_train
price_matrix = Matrix{Float64}(undef, n_days, length(TICKERS))
for (j, t) in enumerate(TICKERS)
    price_matrix[:, j] = train_dataset[t][!, :volume_weighted_average_price]
end

tickers_train = sort(collect(keys(train_dataset)))
all_growth_is = log_growth_matrix(train_dataset, tickers_train; Δt = _DT, risk_free_rate = _RF_IS)
tidx_is       = [findfirst(==(t), tickers_train) for t in TICKERS]
g_obs_is      = all_growth_is[1:(n_days - 1), tidx_is]
T_is          = size(g_obs_is, 1)
Sigma_obs_is  = cor(g_obs_is)

# ── OoS (2025 test) data — same source (VLQ), post-training window ────────────
original_test = MyTestingMarketDataSet()["dataset"]
max_days_test = nrow(original_test["SPY"])
test_dataset  = Dict{String,DataFrame}()
for (t, df) in original_test
    nrow(df) == max_days_test && (test_dataset[t] = df)
end
for t in TICKERS
    @assert haskey(test_dataset, t) "Ticker $t not full-length in test"
end
tickers_test  = sort(collect(keys(test_dataset)))
all_growth_oos = log_growth_matrix(test_dataset, tickers_test; Δt = _DT, risk_free_rate = _RF_IS)
tidx_oos      = [findfirst(==(t), tickers_test) for t in TICKERS]
g_obs_oos     = all_growth_oos[1:(max_days_test - 1), tidx_oos]
T_oos         = size(g_obs_oos, 1)
Sigma_obs_oos = cor(g_obs_oos)

oos_dates = (first(test_dataset["SPY"].timestamp), last(test_dataset["SPY"].timestamp))

@info "IS  observations: $T_is  (train window)"
@info "OoS observations: $T_oos (test window $(oos_dates[1]) .. $(oos_dates[2]))"

# ── metric helpers ───────────────────────────────────────────────────────────
const OFFDIAG = [(i, j) for i in 1:4 for j in 1:4 if i != j]

frob_pathavg(corrs, Sobs)   = mean(norm(Sp - Sobs)                                  for Sp in corrs)
offmae_pathavg(corrs, Sobs) = mean(mean(abs(Sp[i, j] - Sobs[i, j]) for (i, j) in OFFDIAG) for Sp in corrs)
function offmae_meanmat(corrs, Sobs)
    Smean = mean(corrs)
    mean(abs(Smean[i, j] - Sobs[i, j]) for (i, j) in OFFDIAG)
end

# ── per-path simulated 4x4 correlation matrices ──────────────────────────────
function sim_corrs_copula(DepType)
    portfolio = JumpHMM.fit(PortfolioModel, TICKERS, price_matrix;
                            dependence = DepType, market = "SPY",
                            rf = _RF_IS, N = _N, ν = _DF)
    portfolio = tune(portfolio, price_matrix)
    sim_result = simulate(portfolio, T_is; n_paths = _N_PATHS, seed = _SEED)
    corrs = Vector{Matrix{Float64}}(undef, _N_PATHS)
    for i in 1:_N_PATHS
        M = Matrix{Float64}(undef, T_is, 4)
        for (j, t) in enumerate(TICKERS)
            M[:, j] = sim_result.results[t].paths[i].observations
        end
        corrs[i] = cor(M)
    end
    corrs
end

# SIM: JumpHMM's SIM simulate drops the market (SPY) path, so we reconstruct the
# self-consistent market-retaining Monte Carlo (identical to dump_sim_spy_corr.jl):
#   SPY_t = simulated market factor;  asset_i = α_i + β_i·SPY_t + σε_i·N(0,1)
function sim_corrs_sim()
    portfolio = JumpHMM.fit(PortfolioModel, TICKERS, price_matrix;
                            dependence = SingleIndexModel, market = "SPY",
                            rf = _RF_IS, N = _N, ν = _DF)
    portfolio = tune(portfolio, price_matrix)
    sim = portfolio.dependence
    Random.seed!(_SEED)
    corrs = Vector{Matrix{Float64}}(undef, _N_PATHS)
    for p in 1:_N_PATHS
        mkt = simulate(sim.market_model, T_is; n_paths = 1).paths[1].observations
        M = Matrix{Float64}(undef, T_is, 4)
        M[:, 1] = mkt
        for k in 1:3
            M[:, k + 1] = sim.α[k] .+ sim.β[k] .* mkt .+ sim.σ_ε[k] .* randn(T_is)
        end
        corrs[p] = cor(M)
    end
    corrs
end

models = [
    ("SIM",       :sim),
    ("Gaussian",  GaussianCopula),
    ("Student-t", StudentTCopula),
    ("C-vine",    VineCopula),
]

published = Dict("Gaussian" => 0.055, "Student-t" => 0.039, "C-vine" => 0.099)

rows = NamedTuple[]
for (label, dep) in models
    @info "Simulating $label ..."
    corrs = dep === :sim ? sim_corrs_sim() : sim_corrs_copula(dep)
    push!(rows, (
        label     = label,
        frob_is   = frob_pathavg(corrs,   Sigma_obs_is),
        mae_is    = offmae_pathavg(corrs, Sigma_obs_is),
        frob_oos  = frob_pathavg(corrs,   Sigma_obs_oos),
        mae_oos   = offmae_pathavg(corrs, Sigma_obs_oos),
        mae_mean  = offmae_meanmat(corrs, Sigma_obs_is),
    ))
end

# ── report ───────────────────────────────────────────────────────────────────
println("\n" * "="^96)
println("  CROSS-ASSET DEPENDENCE — Paper II convention (path-averaged)")
println("  N_PATHS = $_N_PATHS   seed = $_SEED   |  IS T=$T_is   OoS T=$T_oos ($(oos_dates[1]) .. $(oos_dates[2]))")
println("="^96)
@printf("  %-10s %12s %12s %12s %12s %14s %10s\n",
        "Model", "Frob IS", "OffMAE IS", "Frob OoS", "OffMAE OoS", "MeanMat MAE", "Pub?")
println("  " * "-"^92)
for r in rows
    pub = get(published, r.label, NaN)
    pubstr = isnan(pub) ? "  n/a" :
             (abs(r.mae_mean - pub) < 0.003 ? @sprintf("~%.3f OK", pub) : @sprintf("~%.3f X", pub))
    @printf("  %-10s %12.4f %12.4f %12.4f %12.4f %14.4f %10s\n",
            r.label, r.frob_is, r.mae_is, r.frob_oos, r.mae_oos, r.mae_mean, pubstr)
end
println("="^96)

showmat(name, M) = (println("\n  $name:"); show(stdout, "text/plain", round.(M, digits = 4)); println())
showmat("Sigma_obs_IS  (order $(join(TICKERS, ", ")))", Sigma_obs_is)
showmat("Sigma_obs_OoS (order $(join(TICKERS, ", ")))", Sigma_obs_oos)
