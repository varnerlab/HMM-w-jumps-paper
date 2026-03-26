# setup paths -
const _ROOT = pwd();
const _PATH_TO_SRC = joinpath(_ROOT, "src");
const _PATH_TO_DATA = joinpath(_ROOT, "data");
const _PATH_TO_FIGS = joinpath(_ROOT, "figs");

# make sure all is up to date -
using Pkg
if (isfile(joinpath(_ROOT, "Manifest.toml")) == false) # have manifest file, we are good. Otherwise, we need to instantiate the environment
    Pkg.add(path="https://github.com/varnerlab/VLQuantitativeFinancePackage.jl.git")
    Pkg.add(url="https://github.com/varnerlab/JumpHMM.jl.git")
    Pkg.activate("."); Pkg.resolve(); Pkg.instantiate(); Pkg.update();
end

# load external packages -
using VLQuantitativeFinancePackage
import JumpHMM
using JumpHMM: JumpHiddenMarkovModel, JumpParameters, SimulationResult, SimulationPath,
               simulate, tune, validate
using DataFrames
using CSV
using Dates
using LinearAlgebra
using Statistics
using StatsBase
using Plots
using Colors
using StatsPlots
using JLD2
using FileIO
using Distributions
using PrettyTables
using HypothesisTests
using Random

# set the random seed for reproducibility -
Random.seed!(1234);