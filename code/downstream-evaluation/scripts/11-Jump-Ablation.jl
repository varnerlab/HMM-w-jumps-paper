# Run the three jump settings with both naive and corrected composition.
# --smoke uses three assets and 20 paths per window in a separate output folder.
include(joinpath(@__DIR__, "..", "Include.jl"))
include(joinpath(_PATH_TO_SRC, "JumpAblation.jl"))

if abspath(PROGRAM_FILE) == @__FILE__
    settings = TOML.parsefile(joinpath(_ROOT,"jump-ablation.toml"))
    run_jump_ablation(settings; smoke="--smoke" in ARGS)
end
