# Isolated inventory and paired sensitivity for the emission fallback policy.
include(joinpath(@__DIR__,"..","src","TrainingSetup.jl"))
include(joinpath(_PATH_TO_SRC,"FallbackDiagnostic.jl"))
isempty(ARGS) || error("Usage: 16-Fallback-Diagnostic.jl")
run_fallback_diagnostic()
