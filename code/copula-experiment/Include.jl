# setup paths
const _ROOT = @__DIR__
const _PATH_TO_DATA = joinpath(_ROOT, "data")
const _PATH_TO_FIGS = joinpath(_ROOT, "figs")
const _PATH_TO_SPY_DATA = joinpath(_ROOT, "..", "spy-experiment", "data")

# make sure all is up to date
using Pkg
Pkg.activate(_ROOT)
if !isfile(joinpath(_ROOT, "Manifest.toml"))
    Pkg.add(url="https://github.com/varnerlab/VLQuantitativeFinancePackage.jl.git")
    Pkg.add(url="https://github.com/varnerlab/JumpHMM.jl.git")
    Pkg.resolve(); Pkg.instantiate(); Pkg.update();
end

# load external packages
using VLQuantitativeFinancePackage
import JumpHMM
using JumpHMM: JumpHiddenMarkovModel, JumpParameters, SimulationResult, SimulationPath,
               ValidationReport, StudentTEmission, LaplacePartition,
               simulate, tune, validate,
               GaussianCopula, StudentTCopula, VineCopula, SingleIndexModel,
               PortfolioModel, PortfolioSimulationResult,
               sample_dependence, excess_growth_rates
using DataFrames
using Statistics
using StatsBase
using Distributions
using HypothesisTests
using FileIO
using JLD2
using Random
using Printf
using LinearAlgebra
using Plots
using Colors
using PrettyTables

# set the random seed for reproducibility
Random.seed!(1234);
