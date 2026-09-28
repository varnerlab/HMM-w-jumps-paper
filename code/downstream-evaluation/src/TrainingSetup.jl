# Headless setup for the canonical training runner and table checks. The command
# selects the pinned project; no Pkg activation or plotting backend is needed.
const _ROOT = normpath(joinpath(@__DIR__,".."))
const _PATH_TO_SRC = joinpath(_ROOT,"src")
const _PATH_TO_DATA = joinpath(_ROOT,"data")
const _PATH_TO_CONFIG = joinpath(_ROOT,"config.toml")
Base.active_project()==joinpath(_ROOT,"Project.toml") ||
    error("Run with --project=code/downstream-evaluation")
using CSV, DataFrames, Dates, Distributions, HypothesisTests, JLD2
using LinearAlgebra, Printf, Random, SHA, Statistics, StatsBase, TOML
import JumpHMM, ARCHModels
using JumpHMM: JumpHiddenMarkovModel, simulate
for file in ("Composers.jl","Metrics.jl","GARCHFit.jl","Pipeline.jl","TrainingResults.jl")
    include(joinpath(_PATH_TO_SRC,file))
end
