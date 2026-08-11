# =============================================================================
# Historical entry point retained for reproducibility.
#
# The paper's multi-asset construction now centers each full-return generator
# draw before scaling it as a SIM residual. The pinned JumpHMM.jl release is
# used for marginal generation; the authoritative centered composition and its
# regression tests live under code/downstream-evaluation.
#
# Run from the repository root with:
#
#   julia --project=code/downstream-evaluation \
#     jfds-paper/code/test/check_jumphmm_agreement.jl
# =============================================================================

include(joinpath(@__DIR__, "..", "..", "..", "code",
                 "downstream-evaluation", "test", "runtests.jl"))
