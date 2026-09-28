# Verify the corrected cache against the original and exercise both evaluators.
using CSV, DataFrames, JLD2, Random, Statistics, TOML, LinearAlgebra
using StatsBase, HypothesisTests, Distributions, VLQuantitativeFinancePackage
import JumpHMM
using JumpHMM: JumpHiddenMarkovModel, SingleIndexModel, HybridSingleIndexModel, simulate, fit
const _ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "code", "downstream-evaluation"))
const _PATH_TO_DATA = joinpath(_ROOT, "data")
const _PATH_TO_CONFIG = joinpath(_ROOT, "config.toml")
# Load the production evaluators without plotting or Pkg activation; the
# command already selects the pinned project, and the depot can be read-only.
for file in ("Composers.jl", "Metrics.jl", "GARCHFit.jl", "Pipeline.jl", "SyntheticMarket.jl", "VaRBacktest.jl")
    include(joinpath(_ROOT, "src", file))
end

old = load(joinpath(@__DIR__, "original-models.jld2"), "models")
fresh = load_validated_garch_models(joinpath(_PATH_TO_DATA, "garch-t-models.jld2"); trial_length=2766)
@assert Set(keys(old)) == Set(keys(fresh))
original_skipped = CSV.read(joinpath(@__DIR__, "original-skipped.csv"), DataFrame)
diagnostics = CSV.read(joinpath(_PATH_TO_DATA, "garch-t-diagnostics.csv"), DataFrame)
@assert Set(original_skipped.ticker) == Set(filter(r->!r.accepted, diagnostics).ticker)
@assert nrow(diagnostics) == 423 && all(diagnostics.converged)
for (i, ticker) in enumerate(sort(collect(keys(old))))
    @assert ARCHModels.coef(old[ticker]) == ARCHModels.coef(fresh[ticker])
    @assert old[ticker].data == fresh[ticker].data
    for horizon in (249, 2766)
        reference = ARCHModels.simulate(old[ticker], horizon; rng=MersenneTwister(1234+i)).data
        corrected = simulate_garch_residual(fresh[ticker], horizon; rng=MersenneTwister(1234+i))
        @assert reference == corrected
    end
end
println("All 393 model coefficients, training inputs, and paired draws at both horizons matched exactly.")
flush(stdout)

# The two-replication smoke run checks integration, coverage, and finite scores.
# It is not used to replace the manuscript's 100-replication summaries.
cfg = load_config()
cfg["simulation"]["n_paths"] = 2
training = run_composer_experiment(cfg; include_composers=Set(["garch_t"]), persist=false)
holdout = run_oos_composer_experiment(cfg; include_composers=Set(["garch_t"]), persist=false)
@assert nrow(training) == 2*393 && length(unique(training.ticker)) == 393
@assert nrow(holdout) == 2*386 && length(unique(holdout.ticker)) == 386
@assert all(isfinite, training.ks_p) && all(isfinite, training.w1)
@assert all(isfinite, holdout.ks_p) && all(isfinite, holdout.w1)
CSV.write(joinpath(@__DIR__, "training-smoke.csv"), training)
CSV.write(joinpath(@__DIR__, "holdout-smoke.csv"), holdout)
open(joinpath(@__DIR__, "pipeline-checks.toml"), "w") do io
    TOML.print(io, Dict("eligible_training_assets"=>393, "eligible_holdout_assets"=>386,
        "excluded_assets"=>30, "all_423_optimizers_converged"=>true,
        "accepted_coefficients_identical"=>true, "accepted_training_inputs_identical"=>true,
        "paired_draws_identical_at_both_horizons"=>true, "training_smoke_paths"=>nrow(training),
        "holdout_smoke_paths"=>nrow(holdout), "smoke_scores_finite"=>true); sorted=true)
end
println("Training and holdout GARCH evaluators completed: 786 and 772 paths, respectively.")
