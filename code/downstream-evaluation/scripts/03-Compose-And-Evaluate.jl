# =============================================================================
# 03-Compose-And-Evaluate.jl
#
# Canonical training evaluation using the production composition order:
# the single-seed default evaluation: all six composers, real SPY market
# path, floor and threshold from config.toml. Outputs to
# data/results.jld2, results.csv, results-summary.csv, and results-metadata.toml.
#
# All fitted caches are required. Asset checkpoints resume only with matching
# provenance. Use --restart to recompute them; canonical files are installed
# only after the complete six-method run passes its checks.
#
# For multi-seed uncertainty quantification see scripts/03c-Seed-Sweep.jl.
# For sensitivity sweeps (R² threshold, floor f) see scripts/03d-Sensitivity-Sweep.jl.
# For the clipping stress test see scripts/03b-Stress-Eval.jl.
# =============================================================================

include(joinpath(@__DIR__, "..", "src", "TrainingSetup.jl"))

cfg = load_config()
all(arg -> arg == "--restart", ARGS) || error("Usage: 03-Compose-And-Evaluate.jl [--restart]")
run_canonical_training(cfg; resume=!("--restart" in ARGS))
