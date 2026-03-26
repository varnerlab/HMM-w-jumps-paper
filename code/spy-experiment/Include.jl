# setup paths -
const _ROOT = @__DIR__;
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
               ValidationReport, StudentTEmission, LaplacePartition,
               simulate, tune, decode, forward_filter, log_likelihood, validate,
               excess_growth_rates, sample_dependence,
               GaussianCopula, StudentTCopula, VineCopula, SingleIndexModel, PortfolioModel
using DataFrames
using Statistics
using StatsBase
using Plots
using Colors
using PrettyTables
using CSV
using Distributions
using FileIO
using JLD2
using HypothesisTests
using StatsPlots
using LinearAlgebra
using ARCHModels
using Random
using Printf
using KernelDensity

# set the random seed for reproducibility -
Random.seed!(1234);