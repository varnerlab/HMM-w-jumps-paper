# Replay only the full-return draws needed to recover Figure 4 denominators.
# This verifies paired composed variances against the frozen training cache.
include(joinpath(@__DIR__,"..","src","TrainingSetup.jl"))
include(joinpath(_PATH_TO_SRC,"VarianceDiagnostic.jl"))
isempty(ARGS) || error("Usage: 15-Variance-Diagnostic.jl")
run_variance_diagnostic()
