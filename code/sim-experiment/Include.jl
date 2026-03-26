# setup paths -
const _ROOT = @__DIR__;
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
using Plots
using Colors
using StatsPlots
using JLD2
using FileIO
using Distributions
using Distances
using MathOptInterface
using DataStructures
using PrettyTables
using StatsBase
using KernelFunctions
using HypothesisTests
using Random
using Printf
using KernelDensity

# set the random seed for reproducibility -
Random.seed!(1234);

# # load my codes -
# include(joinpath(_PATH_TO_SRC, "Files.jl"));
# include(joinpath(_PATH_TO_SRC, "Compute.jl"));