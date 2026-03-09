# =============================================================================
# export_spy_data.jl
#
# Exports SPY excess growth rate series to CSV for the Python neural baseline.
# Produces two files:
#   spy_is.csv  — in-sample (2014-2024, 2766 values)
#   spy_oos.csv — out-of-sample (2025, 249 values)
# =============================================================================

include(joinpath(@__DIR__, "..", "Include.jl"))

const _RF_IS  = 0.043
const _RF_OOS = 0.0421
const _DT     = 1.0 / 252.0

# ── Load training data ──────────────────────────────────────────────────────
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
g_is = all_growth_train[1:(max_days_train - 1), spy_idx]

# ── Load testing data ──────────────────────────────────────────────────────
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
g_oos = all_growth_test[1:(max_days_test - 1), spy_idx_test]

# ── Write CSV ──────────────────────────────────────────────────────────────
using DelimitedFiles

outdir = @__DIR__
writedlm(joinpath(outdir, "spy_is.csv"), g_is, ',')
writedlm(joinpath(outdir, "spy_oos.csv"), g_oos, ',')

@info "Exported IS: $(length(g_is)) values → spy_is.csv"
@info "Exported OoS: $(length(g_oos)) values → spy_oos.csv"
