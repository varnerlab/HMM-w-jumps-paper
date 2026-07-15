# =============================================================================
# 10-OoS-Evaluation.jl
#
# Frozen-parameter 2025 evaluation of all six multi-asset composers. Fits and
# SIM calibration come exclusively from 2014--2024. Outputs per-path holdout
# metrics plus matched-length in-sample diagnostics.
# =============================================================================

include(joinpath(@__DIR__, "..", "Include.jl"))

cfg = load_config()
run_oos_composer_experiment(cfg)
