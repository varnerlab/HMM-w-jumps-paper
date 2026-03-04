# =============================================================================
# HMM-Parameter-Sweep.jl
#
# Grid search over (ε, λ) to find the jump hyperparameters that best reproduce
# the observed SPY ACF of |excess growth rates| (ARCH effect) and kurtosis.
#
# The jump simulation is implemented inline so ε and λ can be varied freely
# without rebuilding the MyHiddenMarkovModelWithJumps object each time.
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

# ── 1. Load base model from JLD2 ─────────────────────────────────────────────
@info "Loading base HMM from $(_JLD2_HMM)..."
hmm_dict     = load(_JLD2_HMM)
insample_obs = hmm_dict["insampledataset"]
T_is         = length(insample_obs)
π̄            = hmm_dict["stationary"]
decode_model = hmm_dict["decode"]
hmm_model    = hmm_dict["model"]
T_dict       = hmm_model.transition         # Dict{Int, Categorical} — one dist per state
N            = length(T_dict)

bottom_states = collect(1:_N_TAIL)
top_states    = collect((N - _N_TAIL + 1):N)

@info "  States N=$(N)  |  IS observations T=$(T_is)"

# Pre-compute observed ACF and kurtosis (targets)
obs_acf  = autocor(abs.(insample_obs), collect(1:_L_ACF))
obs_kurt = kurtosis(insample_obs)
@info "  Observed kurtosis : $(round(obs_kurt, digits=3))"

# ── 2. Inline jump simulation ─────────────────────────────────────────────────
"""
    simulate_jump_path(T_mat, π̄, decode, ε, λ, n_steps) -> (decoded, has_jump)

Simulate one path of length `n_steps` using the empirical transition matrix
`T_mat`, augmented with a Poisson jump-duration mechanism (ε, λ).
Returns the decoded excess growth rate vector and a Bool indicating whether
at least one jump event occurred.
"""
function simulate_jump_path(T_dict::Dict, π̄, decode::Dict,
                            ε::Float64, λ::Float64, n_steps::Int;
                            bottom::Vector{Int}, top::Vector{Int},
                            p_neg::Float64 = _P_NEG)
    states   = Vector{Int}(undef, n_steps)
    has_jump = false

    states[1] = rand(π̄)
    t = 2
    while t <= n_steps
        if rand() < ε
            has_jump = true
            K = rand(Poisson(λ))
            for _ in 1:K
                t > n_steps && break
                states[t] = rand() < p_neg ? rand(bottom) : rand(top)
                t += 1
            end
        else
            states[t] = rand(T_dict[states[t-1]])
            t += 1
        end
    end

    decoded = [rand(decode[s]) for s in states]
    return decoded, has_jump
end

# ── 3. Objective function J(ε, λ) ────────────────────────────────────────────
"""
    objective(ε, λ; n_paths, jump_only) -> (J, acf_mae, kurt_err, n_jump_paths)

Simulate `n_paths` paths and compute the multi-objective loss.
`jump_only=true` uses only paths containing at least one jump for ACF/kurtosis.
"""
function objective(ε::Float64, λ::Float64;
                   n_paths::Int = _N_PATHS,
                   jump_only::Bool = true)

    acf_accum  = zeros(_L_ACF)
    kurt_accum = 0.0
    n_used     = 0

    for _ in 1:n_paths
        decoded, has_jump = simulate_jump_path(T_dict, π̄, decode_model, ε, λ, T_is;
                                               bottom = bottom_states,
                                               top    = top_states)
        jump_only && !has_jump && continue   # skip non-jump paths if requested

        acf_accum  .+= autocor(abs.(decoded), collect(1:_L_ACF))
        kurt_accum  += kurtosis(decoded)
        n_used      += 1
    end

    n_used == 0 && return (Inf, Inf, Inf, 0)   # no jump paths — ε too small

    mean_acf  = acf_accum  ./ n_used
    mean_kurt = kurt_accum  / n_used

    acf_mse  = sum((obs_acf  .- mean_acf) .^ 2)
    kurt_err = (obs_kurt - mean_kurt)^2

    J = acf_mse + _W_KURT * kurt_err
    return J, sqrt(acf_mse / _L_ACF), sqrt(kurt_err), n_used
end

# ── 4. Define search grid ────────────────────────────────────────────────────
# Centre around current estimates (ε≈5e-5, λ≈67) and explore wider
ε_grid = [1e-5, 2.5e-5, 5e-5, 7.5e-5, 1e-4, 2e-4, 4e-4, 8e-4]
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

# log-scale ε axis labels
ε_labels = [@sprintf("%.0e", e) for e in ε_grid]

pJ = heatmap(λ_grid, ε_grid, log10.(J_surface);
             xlabel = "λ (mean jump duration)",
             ylabel = "ε (jump probability)",
             title  = "(a) Objective J(ε, λ)  [log₁₀ scale]",
             color  = :viridis,
             yticks = (ε_grid, ε_labels),
             bottom_margin = 12Plots.mm, left_margin = 12Plots.mm,
             colorbar_title = "log₁₀ J",
             framestyle = :box)

# Mark the optimum
scatter!(pJ, [λ_star], [ε_star];
         mc = :red, ms = 10, markershape = :star5,
         markerstrokewidth = 0, label = "Optimum (ε*,λ*)")

# ── 7. Figure 5b: ACF comparison at optimal parameters (high-path-count) ─────
@info "Simulating best-fit paths at (ε*=$(ε_star), λ*=$(λ_star)) with 500 paths..."

best_decoded_list = Vector{Float64}[]
for _ in 1:500
    decoded, has_jump = simulate_jump_path(T_dict, π̄, decode_model,
                                           ε_star, λ_star, T_is;
                                           bottom = bottom_states,
                                           top    = top_states)
    has_jump && push!(best_decoded_list, decoded)
end
@info "  Jump paths: $(length(best_decoded_list)) / 500"

best_acf_mat  = hcat([autocor(abs.(p), collect(1:_L_ACF)) for p in best_decoded_list]...)
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
@info "Saved Figure 5 to figs/"

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
