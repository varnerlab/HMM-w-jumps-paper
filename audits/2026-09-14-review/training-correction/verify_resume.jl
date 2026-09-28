using Test
include(joinpath(@__DIR__,"..","..","..","code","downstream-evaluation","src","TrainingSetup.jl"))
@testset "Training checkpoint recovery" begin
    canonical,_,_=load_canonical_training()
    temporary=mktempdir()
    recovered=run_canonical_training(load_config();output=temporary)
    @test recovered==canonical
    @test load(joinpath(temporary,"results.jld2"),"results")==canonical
    @test read(joinpath(temporary,"results-summary.csv"))==read(joinpath(_PATH_TO_DATA,"results-summary.csv"))
    changed=load_config()
    changed["simulation"]["n_paths"]=2
    @test_throws ErrorException run_canonical_training(changed;output=temporary)
    rm(temporary;recursive=true)
end
