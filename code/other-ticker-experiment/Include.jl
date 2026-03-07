# setup paths
const _ROOT = @__DIR__
const _PATH_TO_DATA = joinpath(_ROOT, "data")
const _PATH_TO_FIGS = joinpath(_ROOT, "figs")

# make sure all is up to date
using Pkg
Pkg.activate(_ROOT)
if !isfile(joinpath(_ROOT, "Manifest.toml"))
    Pkg.add(path="https://github.com/varnerlab/VLQuantitativeFinancePackage.jl.git")
    Pkg.resolve(); Pkg.instantiate(); Pkg.update();
end

# load external packages
using VLQuantitativeFinancePackage
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
