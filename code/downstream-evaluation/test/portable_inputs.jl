# Check that a reader can load the distributed inputs and fit new marginals
# without any of the author's fitted-model caches or external data symlinks.
using Test, JLD2, TOML, DataFrames, Statistics, LinearAlgebra
using VLQuantitativeFinancePackage
import JumpHMM
using JumpHMM: JumpHiddenMarkovModel, fit

const pipeline_root = normpath(joinpath(@__DIR__, ".."))
const distributed_data = joinpath(pipeline_root, "data")
const _PATH_TO_DATA = mktempdir()
include(joinpath(pipeline_root, "src", "Pipeline.jl"))

@testset "Portable cached inputs and fresh marginal fitting" begin
    for name in ("universe.jld2", "sim-calibration.jld2", "results.jld2")
        path = joinpath(distributed_data, name)
        @test isfile(path)
        @test !islink(path)
        @test !isempty(JLD2.load(path))
    end
    cfg = TOML.parsefile(joinpath(pipeline_root, "config.toml"))
    saved = JLD2.load(joinpath(distributed_data, "universe.jld2"))
    tickers, prices = load_universe(Int(cfg["universe"]["min_obs_required"]))
    @test tickers == saved["tickers"]
    @test prices == saved["prices"]
    growth = growth_rate_matrix(prices;
        rf=Float64(cfg["hmm"]["risk_free_rate"]), dt=Float64(cfg["hmm"]["dt"]))
    @test growth ≈ saved["growth_rates"]
    calibration = calibrate_sim(growth, tickers, cfg["universe"]["market_ticker"])
    cached_calibration = JLD2.load(joinpath(distributed_data, "sim-calibration.jld2"))["calibration"]
    @test calibration.ticker == cached_calibration.ticker
    for name in (:alpha, :beta, :r2_real, :sigma_eps_real)
        @test calibration[!,name] ≈ cached_calibration[!,name]
    end
    selected = ["AAPL", "QQQ", "SPY"]
    indices = [only(findall(==(ticker), tickers)) for ticker in selected]
    models = fit_per_ticker_marginals(prices[:,indices], selected; cfg=cfg)
    @test Set(keys(models)) == Set(selected)
    @test isfile(joinpath(_PATH_TO_DATA, "marginals.jld2"))
    reread = JLD2.load(joinpath(_PATH_TO_DATA, "marginals.jld2"))["marginals"]
    @test Set(keys(reread)) == Set(selected)
end
