# setup paths
const _ROOT = @__DIR__
const _PATH_TO_SPY_DATA = joinpath(_ROOT, "..", "spy-experiment", "data")

# make sure all is up to date
using Pkg
if !isfile(joinpath(_ROOT, "Manifest.toml"))
    Pkg.add(path="https://github.com/varnerlab/VLQuantitativeFinancePackage.jl.git")
    Pkg.add(url="https://github.com/varnerlab/JumpHMM.jl.git")
    Pkg.activate("."); Pkg.resolve(); Pkg.instantiate(); Pkg.update();
end

# load external packages
using VLQuantitativeFinancePackage
import JumpHMM
using JumpHMM: JumpHiddenMarkovModel, JumpParameters, SimulationResult, SimulationPath,
               ValidationReport, simulate, tune, validate
using DataFrames
using Statistics
using StatsBase
using Distributions
using HypothesisTests
using FileIO
using JLD2
using ARCHModels
using Random
using Printf
using LinearAlgebra

# set the random seed for reproducibility
Random.seed!(1234);
