# Recompute the Single-Index-Model correlation matrix WITH the market (SPY) column.
#
# JumpHMM's SIM simulate discards the simulated market factor path (SPY is the driver,
# not a stored output), so Copula-Comparison.jl leaves the SPY row/column of the SIM
# correlation matrix as NaN. Here we re-fit the SIM (deterministic) and run a
# self-consistent Monte Carlo that RETAINS the market path, so SPY's correlations are
# filled. Only overwrites data/panels/sim_corr_sim.csv (the SIM matrix is not asserted
# in any table). Mirrors the data load / fit / tune of Copula-Comparison.jl.
include("Include.jl")
using Random, DelimitedFiles, Statistics

const TICKERS  = ["SPY", "NVDA", "JNJ", "JPM"]
const _RF_IS   = 0.043
const _DT      = 1.0 / 252.0
const _N_PATHS = 1_000
const _N       = 100
const _DF      = 5.0

# ── data load (identical to Copula-Comparison.jl) ──
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train = original_train["AAPL"] |> nrow
train_dataset = Dict{String,DataFrame}()
for (ticker, df) in original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end
n_days = max_days_train
price_matrix = Matrix{Float64}(undef, n_days, length(TICKERS))
for (j, t) in enumerate(TICKERS)
    price_matrix[:, j] = train_dataset[t][!, :volume_weighted_average_price]
end
T_is = n_days - 1

# ── fit + tune the SIM portfolio (deterministic; SPY is the market factor) ──
portfolio = JumpHMM.fit(PortfolioModel, TICKERS, price_matrix;
                        dependence = SingleIndexModel, market = "SPY",
                        rf = _RF_IS, N = _N, ν = _DF)
portfolio = tune(portfolio, price_matrix)
sim = portfolio.dependence   # SingleIndexModel: α, β, σ_ε (order NVDA,JNJ,JPM) + market_model

# ── Monte Carlo retaining the market (SPY) path ──
#   SPY_t   = simulated market factor
#   asset_i = α_i + β_i · SPY_t + σ_ε_i · N(0,1)
Random.seed!(1234)
acc = zeros(4, 4)
for _ in 1:_N_PATHS
    mkt = simulate(sim.market_model, T_is; n_paths = 1).paths[1].observations
    M = Matrix{Float64}(undef, T_is, 4)
    M[:, 1] = mkt                                  # SPY (market factor)
    for k in 1:3                                   # NVDA, JNJ, JPM
        M[:, k + 1] = sim.α[k] .+ sim.β[k] .* mkt .+ sim.σ_ε[k] .* randn(T_is)
    end
    acc .+= cor(M)
end
sim_corr = acc ./ _N_PATHS

outdir = joinpath(@__DIR__, "data", "panels")
isdir(outdir) || mkpath(outdir)
writedlm(joinpath(outdir, "sim_corr_sim.csv"), sim_corr, ',')

println("SIM correlation (SPY-inclusive) written to ", joinpath(outdir, "sim_corr_sim.csv"))
println("  SPY row      : ", round.(sim_corr[1, :], digits = 3))
println("  NVDA-JNJ/JPM : ", round(sim_corr[2, 3], digits = 3), " / ", round(sim_corr[2, 4], digits = 3))
println("  JNJ-JPM      : ", round(sim_corr[3, 4], digits = 3))
