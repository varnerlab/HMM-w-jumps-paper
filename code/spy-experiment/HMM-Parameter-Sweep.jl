# =============================================================================
# HMM-Parameter-Sweep.jl
#
# Grid search over (ε, λ) to find the jump hyperparameters that best reproduce
# the observed SPY ACF of |excess growth rates| (ARCH effect) and kurtosis.
#
# Uses JumpHMM.jl model struct. For each grid point, constructs a new
# JumpHiddenMarkovModel with the candidate jump parameters and simulates
# via JumpHMM.simulate().
#
# Outputs
#   data/HMM-Parameter-Sweep-SPY.jld2   — full J(ε,λ) surface + optimal params
#   figs/Fig5-Grid-Search-Contour.pdf   — Figure 5: contour plot of J(ε,λ)
#   figs/Fig5-Best-Fit-ACF.pdf          — ACF comparison at optimal parameters
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const _JLD2_HMM   = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")
const _JLD2_OUT   = joinpath(_PATH_TO_DATA, "HMM-Parameter-Sweep-SPY.jld2")
const _L_ACF      = 252        # max ACF lag
const _N_PATHS    = 200        # paths per grid point (fast sweep)
const _N_TAIL     = 5          # number of tail states on each side
const _P_NEG      = 0.52       # bias toward negative tail
const _W_KURT     = 0.20       # kurtosis penalty weight (matches paper)

# ── 1. Load JumpHMM model from JLD2 ────────────────────────────────────────
@info "Loading JumpHMM model from $(_JLD2_HMM)..."
hmm_dict     = load(_JLD2_HMM)
insample_obs = hmm_dict["insampledataset"]
model_nj     = hmm_dict["model_nj"]   # JumpHiddenMarkovModel with ε=0 (no jumps)
T_is         = length(insample_obs)
N            = length(model_nj.emissions)

@info "  States N=$(N)  |  IS observations T=$(T_is)"

# Pre-compute observed ACF and kurtosis (targets)
obs_acf  = autocor(abs.(insample_obs), collect(1:_L_ACF))
obs_kurt = kurtosis(insample_obs)
@info "  Observed kurtosis : $(round(obs_kurt, digits=3))"

# ── 2. Helper: build model with candidate jump parameters ───────────────────
function make_jump_model(base::JumpHiddenMarkovModel, ε::Float64, λ::Float64)
    jp = JumpParameters(ε, λ; p_neg = _P_NEG, N_tail = _N_TAIL)
    return JumpHiddenMarkovModel(
        base.partition, base.transition, base.emissions,
        base.stationary, jp, base.ν, base.rf, base.dt
    )
end

# ── 3. Objective function J(ε, λ) ────────────────────────────────────────────
function objective(ε::Float64, λ::Float64)
    model = make_jump_model(model_nj, ε, λ)
    result = simulate(model, T_is; n_paths = _N_PATHS)

    # Only use paths with at least one jump
    acf_accum  = zeros(_L_ACF)
    kurt_accum = 0.0
    n_used     = 0

    for path in result.paths
        any(path.jumps) || continue
        acf_accum  .+= autocor(abs.(path.observations), collect(1:_L_ACF))
        kurt_accum  += kurtosis(path.observations)
        n_used      += 1
    end

    n_used == 0 && return (Inf, Inf, Inf, 0)

    mean_acf  = acf_accum  ./ n_used
    mean_kurt = kurt_accum  / n_used

    acf_mse  = sum((obs_acf  .- mean_acf) .^ 2)
    kurt_err = (obs_kurt - mean_kurt)^2

    J = acf_mse + _W_KURT * kurt_err
    return J, sqrt(acf_mse / _L_ACF), sqrt(kurt_err), n_used
end

# ── 4. Define search grid ────────────────────────────────────────────────────
ε_grid = [1e-4, 2.5e-4, 5e-4, 1e-3, 2.5e-3, 5e-3, 1e-2, 2.5e-2]
λ_grid = [10.0, 25.0, 40.0, 55.0, 70.0, 85.0, 100.0, 130.0, 160.0]

n_ε = length(ε_grid)
n_λ = length(λ_grid)

J_surface       = fill(Inf, n_ε, n_λ)
acf_mae_surface = fill(Inf, n_ε, n_λ)
kurt_err_surface= fill(Inf, n_ε, n_λ)
n_jump_surface  = zeros(Int, n_ε, n_λ)

@info "Starting grid search: $(n_ε) × $(n_λ) = $(n_ε*n_λ) points, $(_N_PATHS) paths each..."

for (i, ε) in enumerate(ε_grid)
    for (j, λ) in enumerate(λ_grid)
        J, acf_mae, kurt_err, n_used = objective(ε, λ)
        J_surface[i, j]        = J
        acf_mae_surface[i, j]  = acf_mae
        kurt_err_surface[i, j] = kurt_err
        n_jump_surface[i, j]   = n_used
        @info "  ε=$(ε)  λ=$(λ)  →  J=$(round(J, sigdigits=4))  ACF-MAE=$(round(acf_mae, sigdigits=3))  n_jump=$(n_used)"
    end
end

# ── 5. Find optimal parameters ───────────────────────────────────────────────
best_idx  = argmin(J_surface)
ε_star    = ε_grid[best_idx[1]]
λ_star    = λ_grid[best_idx[2]]
J_star    = J_surface[best_idx]

println("\n" * "="^60)
println("  Optimal parameters")
println("="^60)
println("  ε* = $(ε_star)")
println("  λ* = $(λ_star)")
println("  J* = $(round(J_star, sigdigits=4))")
println("  ACF-MAE* = $(round(acf_mae_surface[best_idx], sigdigits=4))")
println("="^60)

# ── 6. Figure 5a: contour plot of J(ε, λ) ────────────────────────────────────
@info "Generating Figure 5 (grid search landscape)..."

log_ε_grid  = log10.(ε_grid)
ε_labels    = [@sprintf("%.0e", e) for e in ε_grid]

pJ = heatmap(λ_grid, log_ε_grid, log10.(J_surface);
             xlabel = "λ (mean jump duration)",
             ylabel = "ε (jump probability)",
             title  = "(a) Objective J(ε, λ)  [log₁₀ scale]",
             color  = :viridis,
             yticks = (log_ε_grid, ε_labels),
             bottom_margin = 12Plots.mm, left_margin = 12Plots.mm,
             colorbar_title = "log₁₀ J",
             framestyle = :box)

scatter!(pJ, [λ_star], [log10(ε_star)];
         mc = :red, ms = 10, markershape = :star5,
         markerstrokewidth = 0, label = "Optimum (ε*,λ*)")

# ── 7. Figure 5b: ACF comparison at optimal parameters ───────────────────────
@info "Simulating best-fit paths at (ε*=$(ε_star), λ*=$(λ_star)) with 500 paths..."

best_model  = make_jump_model(model_nj, ε_star, λ_star)
best_result = simulate(best_model, T_is; n_paths = 500, seed = 1234)

# Keep only paths with jumps
best_obs_list = [p.observations for p in best_result.paths if any(p.jumps)]
@info "  Jump paths: $(length(best_obs_list)) / 500"

best_acf_mat  = hcat([autocor(abs.(p), collect(1:_L_ACF)) for p in best_obs_list]...)
mean_best_acf = vec(mean(best_acf_mat, dims = 2))
lo_best_acf   = [quantile(best_acf_mat[l, :], 0.10) for l in 1:_L_ACF]
hi_best_acf   = [quantile(best_acf_mat[l, :], 0.90) for l in 1:_L_ACF]
lag_vec       = collect(1:_L_ACF)
ci_band       = 1.96 / sqrt(T_is)

pACF = plot(bg = "gray95", background_color_outside = "white",
            framestyle = :box, fg_legend = :transparent, legend = :topright,
            bottom_margin = 12Plots.mm, left_margin = 12Plots.mm)

plot!(pACF, lag_vec, lo_best_acf;
      fillrange = hi_best_acf, fillalpha = 0.2, lw = 0, c = :navy, label = "")
plot!(pACF, lag_vec, mean_best_acf; lw = 2.5, c = :navy,
      label = "HMM-WJ  ε*=$(ε_star)  λ*=$(λ_star)")
plot!(pACF, lag_vec, obs_acf; lw = 3.0, c = :red, ls = :dash, label = "SPY Observed")
hline!(pACF, [ci_band]; lw = 1, ls = :dot, c = :black, label = "95% CI")

plot!(pACF; xguidefontsize = 14, yguidefontsize = 14, titlefontsize = 14,
           xlabel = "Lag (trading days)",
           ylabel = "ACF of |Excess Growth Rate|",
           title  = "(b) Best-Fit ACF at Optimal Parameters")

# ── 8. Save figures ───────────────────────────────────────────────────────────
savefig(pJ,   joinpath(_PATH_TO_FIGS, "Fig5-Grid-Search-Contour.pdf"))
savefig(pACF, joinpath(_PATH_TO_FIGS, "Fig5-Best-Fit-ACF.pdf"))

fig5 = plot(pJ, pACF; layout = (1, 2), size = (1400, 560))
savefig(fig5, joinpath(_PATH_TO_FIGS, "Fig5-Parameter-Sweep.pdf"))
savefig(fig5, joinpath(_ROOT, "..", "..", "paper", "sections", "figs", "Fig5-Parameter-Sweep.pdf"))
@info "Saved Figure 5 to figs/ and paper/sections/figs/"

# ── 9. Save results ───────────────────────────────────────────────────────────
save(_JLD2_OUT,
    "epsilon_grid",     ε_grid,
    "lambda_grid",      λ_grid,
    "J_surface",        J_surface,
    "acf_mae_surface",  acf_mae_surface,
    "kurt_err_surface", kurt_err_surface,
    "n_jump_surface",   n_jump_surface,
    "epsilon_star",     ε_star,
    "lambda_star",      λ_star,
    "J_star",           J_star,
)

@info "Done. Optimal: ε*=$(ε_star)  λ*=$(λ_star)  J*=$(round(J_star, sigdigits=4))"
