# Exercise the original production loop with isolated inputs and compare it with
# the canonical runner, including an excluded GARCH fit and both tracker assets.
using Test
include(joinpath(@__DIR__,"..","..","..","code","downstream-evaluation","src","TrainingSetup.jl"))

module SerialPipeline
    using CSV, DataFrames, Distributions, HypothesisTests, JLD2, LinearAlgebra
    using Random, Statistics, StatsBase, TOML
    import JumpHMM, ARCHModels
    using JumpHMM: JumpHiddenMarkovModel, simulate
    const _PATH_TO_DATA = mktempdir()
    const source = normpath(joinpath(@__DIR__,"..","..","..","code","downstream-evaluation","src"))
    for name in ("Composers.jl","Metrics.jl","GARCHFit.jl","Pipeline.jl")
        include(joinpath(source,name))
    end
end

@testset "Direct production-loop equivalence" begin
    cfg=load_config(); cfg["simulation"]["n_paths"]=2
    selected=["AAPL","ALB","F","QQQ","SPYG","T"]
    universe=load(resolve_data_artifact("universe.jld2"))
    calibration=filter(r->r.ticker in selected,load(resolve_data_artifact("sim-calibration.jld2"),"calibration"))
    symlink(resolve_data_artifact("universe.jld2"),joinpath(SerialPipeline._PATH_TO_DATA,"universe.jld2"))
    jldsave(joinpath(SerialPipeline._PATH_TO_DATA,"sim-calibration.jld2");calibration)
    reference=SerialPipeline.run_composer_experiment(cfg;persist=false)
    full=load(resolve_data_artifact("marginals.jld2"),"marginals")
    residual=load(resolve_data_artifact("marginals-residuals.jld2"),"marginals")
    garch=load_validated_garch_models(resolve_data_artifact("garch-t-models.jld2");trial_length=2766)
    index=Dict(t=>i for (i,t) in enumerate(universe["tickers"]))
    gm=universe["growth_rates"][:,index["SPY"]]
    score=training_scorer(gm)
    blocks=[training_asset(i,cal,universe["growth_rates"][:,index[cal.ticker]],gm,
        full[cal.ticker],residual[cal.ticker],garch,cfg,score) for (i,cal) in enumerate(eachrow(calibration))]
    actual=vcat(blocks...)
    @test names(actual)==names(reference)
    @test nrow(actual)==2sum(5+haskey(garch,ticker) for ticker in selected)
    for name in names(reference)
        @test actual[!,name]==reference[!,name]
    end
    rm(SerialPipeline._PATH_TO_DATA;recursive=true)
end
