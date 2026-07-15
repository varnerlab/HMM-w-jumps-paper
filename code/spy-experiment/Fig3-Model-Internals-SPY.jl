# =============================================================================
# Fig3-Model-Internals-SPY.jl
#
# Produces Figure 3 (1×3 layout): fitted HMM-WJ model internals for SPY
# (N=100 states, in-sample 2014–2024) using JumpHMM.jl model struct.
#
# Panels
#   (a) Laplace CDF vs SPY empirical CDF with N−1=99 quantile-boundary lines
#   (b) Heatmap of empirical transition matrix T (log₁₀ colour scale)
#   (c) Self-transition probability T_{kk} vs state k, tail states highlighted
#
# Outputs
#   code/spy-experiment/figs/Fig3-Model-Internals.pdf
#   paper/sections/figs/Fig3-Model-Internals.pdf   (copy)
# =============================================================================

include("Include.jl")

# ── constants ─────────────────────────────────────────────────────────────────
const _N_TAIL  = 5
const _JLD2_IN = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")

# ── 1. Load saved artefact ───────────────────────────────────────────────────
@info "Loading HMM artefact..."
d       = load(_JLD2_IN)
g_is    = d["insampledataset"]
model   = d["model_wj"]                    # JumpHiddenMarkovModel
N       = d["number_of_states"]

@info "  N              = $N"
@info "  IS series len  = $(length(g_is))"

# ── 2. Fit Laplace MLE ───────────────────────────────────────────────────────
d_laplace = fit_mle(Laplace, g_is)
μ_L = d_laplace.μ
b_L = d_laplace.θ
@info "  Laplace MLE : μ=$(round(μ_L, digits=4))  b=$(round(b_L, digits=4))"

# ── 3. Extract transition matrix from JumpHMM model ─────────────────────────
@info "Extracting transition matrix..."
T_mat = model.transition                    # Matrix{Float64} N×N (already dense)
@info "  row-sum check (row 1): $(round(sum(T_mat[1,:]), digits=6))"

diag_T = [T_mat[k, k] for k in 1:N]
@info "  T_kk range: min=$(round(minimum(diag_T), digits=4)) max=$(round(maximum(diag_T), digits=4))"

# ── 4. Shared style ───────────────────────────────────────────────────────────
bg_col     = "gray95"
col_emp    = colorant"#e63946"
col_lap    = colorant"#1d3557"
col_mid    = colorant"#457b9d"
col_btail  = colorant"#e63946"
col_ttail  = colorant"#2a9d8f"
col_bound  = RGBA(0.3, 0.3, 0.3, 0.25)

# ── 5. Panel (a): ECDF vs Laplace CDF with quantile boundaries ───────────────
@info "Building panel (a)..."

g_sorted  = sort(g_is)
n_obs     = length(g_sorted)
ecdf_vals = collect(1:n_obs) ./ n_obs

x_lim  = 10.0
x_grid = range(-x_lim, x_lim; length = 1000)
cdf_L  = cdf.(d_laplace, collect(x_grid))

pa = plot(g_sorted, ecdf_vals;
          seriestype               = :line,
          lw                       = 2.0,
          c                        = col_emp,
          label                    = "Empirical CDF",
          xlims                    = (-x_lim, x_lim),
          ylims                    = (0.0, 1.0),
          bg                       = bg_col,
          background_color_outside = "white",
          framestyle               = :box,
          fg_legend                = :transparent,
          xguidefontsize           = 13,
          yguidefontsize           = 13,
          titlefontsize            = 13,
          bottom_margin            = 12Plots.mm,
          left_margin              = 12Plots.mm,
          legendfontsize           = 10,
          legend                   = :topleft)

plot!(pa, collect(x_grid), cdf_L;
      lw = 2.0, c = col_lap, label = "Laplace MLE", ls = :dash)

for k in 1:(N-1)
    q_k = quantile(d_laplace, k / N)
    vline!(pa, [q_k]; lw = 0.6, c = col_bound, label = "")
end

xlabel!(pa, "Excess Growth Rate (year⁻¹)")
ylabel!(pa, "Cumulative Probability")
title!(pa,  "(a) Laplace CDF Partition  (N=$N bins)")

# ── 6. Panel (b): Heatmap of T (log₁₀ colour scale) ─────────────────────────
@info "Building panel (b)..."

ε_clip = 1e-10
log_T  = log10.(T_mat .+ ε_clip)
c_lo, c_hi = -5.0, 0.0

pb = heatmap(1:N, 1:N, log_T;
             color                    = :plasma,
             clims                    = (c_lo, c_hi),
             xlabel                   = "To state  j",
             ylabel                   = "From state  i",
             title                    = "(b) Transition Matrix  T  (log₁₀ scale)",
             colorbar_title           = " log₁₀(Tᵢⱼ)",
             right_margin             = 8Plots.mm,
             bg                       = bg_col,
             background_color_outside = "white",
             framestyle               = :box,
             xguidefontsize           = 13,
             yguidefontsize           = 13,
             titlefontsize            = 13,
             bottom_margin            = 12Plots.mm,
             left_margin              = 12Plots.mm)

# ── 7. Panel (c): Expected natural residence time vs state k ─────────────────
@info "Building panel (c)..."

λ_jump     = model.jump.λ                    # from fitted model
nat_res    = 1.0 ./ (1.0 .- diag_T)

state_colors = fill(col_mid, N)
for k in 1:_N_TAIL
    state_colors[k]     = col_btail
    state_colors[N-k+1] = col_ttail
end

pc = scatter(1:N, nat_res;
             mc                      = state_colors,
             ms                      = 5,
             msw                     = 0,
             label                   = "Natural residence  1/(1−T_{kk})",
             xlims                   = (0, N + 1),
             ylims                   = (0.9, λ_jump * 2.2),
             yaxis                   = :log10,
             yticks                  = ([1, 2, 5, 10, 20, 50, 100],
                                        ["1", "2", "5", "10", "20", "50", "100"]),
             bg                      = bg_col,
             background_color_outside = "white",
             framestyle              = :box,
             xguidefontsize          = 13,
             yguidefontsize          = 13,
             titlefontsize           = 13,
             bottom_margin           = 12Plots.mm,
             left_margin             = 12Plots.mm,
             legend                  = :right,
             legendfontsize          = 9)

vspan!(pc, [0.5, _N_TAIL + 0.5];
       fillalpha = 0.12, c = col_btail, label = "Bottom tail  S₋")
vspan!(pc, [N - _N_TAIL + 0.5, N + 0.5];
       fillalpha = 0.12, c = col_ttail, label = "Top tail  S₊")

hline!(pc, [λ_jump];
       lw = 2.0, ls = :dash, c = :black,
       label = "Jump duration  λ = $(Int(λ_jump)) steps")

xlabel!(pc, "State index  k")
ylabel!(pc, "Expected residence (steps, log scale)")
title!(pc,  "(c) Natural vs. Jump-Forced Residence Time")

# ── 8. Combine and save ───────────────────────────────────────────────────────
@info "Rendering Figure 3..."
fig3 = plot(pa, pb, pc;
            layout = (1, 3),
            size   = (1600, 520))

out_figs   = joinpath(_PATH_TO_FIGS, "Fig3-Model-Internals.pdf")
paper_figs = joinpath(_ROOT, "..", "..", "paper", "sections", "figs",
                      "Fig3-Model-Internals.pdf")
jfds_figs  = joinpath(_ROOT, "..", "..", "jfds-paper", "figs", "supplement",
                      "FigS05-Model-Internals.pdf")

savefig(fig3, out_figs)
@info "Saved  Fig3 → $out_figs"

mkpath(dirname(paper_figs))
cp(out_figs, paper_figs; force = true)
@info "Copied Fig3 → $paper_figs"
mkpath(dirname(jfds_figs))
cp(out_figs, jfds_figs; force = true)
@info "Copied JFDS FigS05 → $jfds_figs"

@info "Done."
