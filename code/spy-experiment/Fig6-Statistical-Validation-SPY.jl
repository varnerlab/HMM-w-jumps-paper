# =============================================================================
# Fig6-Statistical-Validation-SPY.jl
#
# Generates the statistical validation figure (2×2 panels):
#   (a) In-sample KS p-value histogram (jump paths only, ~24% of ensemble)
#   (b) Out-of-sample KS p-value histogram (all paths)
#   (c) Out-of-sample density fan chart (all paths)
#   (d) In-sample ACF of |Gₜ| (jump paths only, showing volatility clustering)
#
# Panels (a) and (d) use IS jump-containing paths to demonstrate that the
# jump mechanism reproduces distributional fidelity and volatility clustering.
# Panels (b) and (c) use all OoS paths for honest generalization assessment.
#
# A supplemental figure (FigS-ACF-Jump-Paths.pdf) shows the IS ACF
# comparison between all paths and jump-only paths.
#
# Outputs:
#   figs/Fig6-Statistical-Validation.pdf
#   paper/sections/figs/Fig6-Statistical-Validation.pdf
#   figs/FigS-ACF-Jump-Paths.pdf
#   paper/sections/figs/FigS-ACF-Jump-Paths.pdf
# =============================================================================

include("Include.jl")
using KernelDensity

const _JLD2_HMM = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")
const _JLD2_OOS = joinpath(_PATH_TO_DATA, "OoS-Validation-SPY.jld2")
const _ALPHA    = 0.05
const _N_PATHS  = 1_000
const _L_ACF    = 252

# ── 1. Load models and data ─────────────────────────────────────────────────
@info "Loading models..."
hmm_d = load(_JLD2_HMM)
insample_obs = hmm_d["insampledataset"]
model_wj = hmm_d["model_wj"]
T_is = length(insample_obs)

@info "Loading OoS data..."
oos_d = load(_JLD2_OOS)
g_oos = oos_d["g_oos"]
T_oos = length(g_oos)

# ── 2. Simulate IS paths ────────────────────────────────────────────────────
@info "Simulating $_N_PATHS IS paths..."
is_result = simulate(model_wj, T_is; n_paths = _N_PATHS, seed = 1234)
is_jump_idx = findall(p -> any(p.jumps), is_result.paths)
is_all_paths = hcat([p.observations for p in is_result.paths]...)
is_jump_paths = is_all_paths[:, is_jump_idx]
n_is_jump = length(is_jump_idx)
@info "  IS jump paths: $n_is_jump / $_N_PATHS ($(round(100n_is_jump/_N_PATHS, digits=1))%)"

# ── 3. Simulate OoS paths (all paths) ───────────────────────────────────────
@info "Simulating $_N_PATHS OoS paths..."
oos_result = simulate(model_wj, T_oos; n_paths = _N_PATHS, seed = 1234)
oos_all_paths = hcat([p.observations for p in oos_result.paths]...)

# ── 4. Compute IS KS p-values (jump paths only) ─────────────────────────────
@info "Computing IS KS p-values (jump paths only)..."
is_ks_pvals = [pvalue(ApproximateTwoSampleKSTest(insample_obs, is_jump_paths[:, i]))
               for i in 1:n_is_jump]
is_ks_rate = mean(is_ks_pvals .> _ALPHA)
@info "  IS KS pass rate (jump paths): $(round(100is_ks_rate, digits=1))%"

# ── 5. Compute OoS KS p-values (all paths) ──────────────────────────────────
@info "Computing OoS KS p-values (all paths)..."
oos_ks_pvals = [pvalue(ApproximateTwoSampleKSTest(g_oos, oos_all_paths[:, i]))
                for i in 1:_N_PATHS]
oos_ks_rate = mean(oos_ks_pvals .> _ALPHA)
@info "  OoS KS pass rate (all paths): $(round(100oos_ks_rate, digits=1))%"

# ── 6. Compute IS ACF (jump paths only) ─────────────────────────────────────
@info "Computing IS ACF (jump paths only)..."
lags_is = collect(1:_L_ACF)
is_obs_acf = autocor(abs.(insample_obs), lags_is)

is_acf_mat = Matrix{Float64}(undef, _L_ACF, n_is_jump)
for i in 1:n_is_jump
    is_acf_mat[:, i] = autocor(abs.(is_jump_paths[:, i]), lags_is)
end

# Also compute ACF for ALL IS paths (for supplemental comparison)
is_acf_mat_all = Matrix{Float64}(undef, _L_ACF, _N_PATHS)
for i in 1:_N_PATHS
    is_acf_mat_all[:, i] = autocor(abs.(is_all_paths[:, i]), lags_is)
end

# ── 7. Colours and style ────────────────────────────────────────────────────
col_obs = colorant"#e63946"
col_wj  = colorant"#1d3557"
col_all = colorant"#457b9d"  # steel for all-paths in supplement

basestyle = (bg                       = "grey97",
             background_color_outside = "white",
             framestyle               = :box,
             fg_legend                = :transparent,
             xguidefontsize           = 11,
             yguidefontsize           = 11,
             titlefontsize            = 11,
             bottom_margin            = 10Plots.mm,
             left_margin              = 12Plots.mm)

# ── 8. Panel (a): IS KS p-value histogram (jump paths) ─────────────────────
@info "Building panel (a)..."
pa = histogram(is_ks_pvals; bins = 20, normalize = :probability,
    color = col_wj, alpha = 0.7, lw = 0.5, lc = :white,
    label = "Jump paths ($n_is_jump / $_N_PATHS)",
    legend = :topleft, legendfontsize = 8, basestyle...)
vline!(pa, [_ALPHA]; lw = 2.5, ls = :dash, c = col_obs, label = "α = 0.05")
annotate!(pa, 0.55, 0.95 * ylims(pa)[2],
    text(@sprintf("KS pass rate: %.1f%%", 100is_ks_rate), :left, 9, col_wj))
xlabel!(pa, "KS p-value")
ylabel!(pa, "Proportion")
title!(pa, "(a) In-Sample KS p-values (jump paths)")

# ── 9. Panel (b): OoS KS p-value histogram (all paths) ─────────────────────
@info "Building panel (b)..."
pb = histogram(oos_ks_pvals; bins = 20, normalize = :probability,
    color = col_wj, alpha = 0.7, lw = 0.5, lc = :white,
    label = "All paths ($_N_PATHS)",
    legend = :topleft, legendfontsize = 8, basestyle...)
vline!(pb, [_ALPHA]; lw = 2.5, ls = :dash, c = col_obs, label = "α = 0.05")
annotate!(pb, 0.55, 0.95 * ylims(pb)[2],
    text(@sprintf("KS pass rate: %.1f%%", 100oos_ks_rate), :left, 9, col_wj))
xlabel!(pb, "KS p-value")
ylabel!(pb, "Proportion")
title!(pb, "(b) Out-of-Sample KS p-values (all paths)")

# ── 10. Panel (c): OoS density fan chart (all paths) ────────────────────────
@info "Building panel (c)..."
obs_kde = kde(g_oos)
grid = obs_kde.x

kde_mat = Matrix{Float64}(undef, length(grid), _N_PATHS)
for i in 1:_N_PATHS
    k = kde(oos_all_paths[:, i], grid)
    kde_mat[:, i] = k.density
end

kde_median = [median(kde_mat[j, :]) for j in 1:length(grid)]
kde_lo     = [quantile(kde_mat[j, :], 0.10) for j in 1:length(grid)]
kde_hi     = [quantile(kde_mat[j, :], 0.90) for j in 1:length(grid)]

pc = plot(; legend = :topleft, legendfontsize = 8, basestyle...)
plot!(pc, grid, kde_lo; fillrange = kde_hi,
      fillalpha = 0.25, lw = 0, c = col_wj, label = "10th-90th pctile")
plot!(pc, grid, kde_median; lw = 2.0, c = col_wj, label = "Simulated median")
plot!(pc, grid, obs_kde.density; lw = 2.5, c = col_obs, ls = :dash, label = "Observed")
xlims!(pc, quantile(g_oos, 0.001), quantile(g_oos, 0.999))
xlabel!(pc, "Excess Annual Growth Rate")
ylabel!(pc, "Density")
title!(pc, "(c) OoS Density Fan Chart (all paths)")

# ── 11. Panel (d): IS ACF of |Gₜ| (jump paths only) ────────────────────────
@info "Building panel (d)..."
ci_band_is = 1.96 / sqrt(T_is)

acf_mn = [mean(is_acf_mat[l, :]) for l in 1:_L_ACF]
acf_lo = [quantile(is_acf_mat[l, :], 0.10) for l in 1:_L_ACF]
acf_hi = [quantile(is_acf_mat[l, :], 0.90) for l in 1:_L_ACF]

pd = plot(; legend = :topright, legendfontsize = 8, basestyle...)
plot!(pd, lags_is, acf_lo; fillrange = acf_hi,
      fillalpha = 0.22, lw = 0, c = col_wj, label = "10th-90th pctile")
plot!(pd, lags_is, acf_mn; lw = 2.5, c = col_wj, label = "HMM-WJ mean (jump paths)")
plot!(pd, lags_is, is_obs_acf; lw = 2.5, c = col_obs, ls = :dash, label = "Observed")
hline!(pd, [ci_band_is]; lw = 1, ls = :dot, c = :black, label = "95% CI")
hline!(pd, [-ci_band_is]; lw = 1, ls = :dot, c = :black, label = "")
xlabel!(pd, "Lag (trading days)")
ylabel!(pd, "ACF of |Excess Growth Rate|")
title!(pd, "(d) IS Volatility Clustering (jump paths)")

# ── 12. Combine and save main figure ─────────────────────────────────────────
@info "Saving main figure..."
fig6 = plot(pa, pb, pc, pd; layout = (2, 2), size = (1200, 900), dpi = 150)

out_figs       = joinpath(_PATH_TO_FIGS, "Fig6-Statistical-Validation.pdf")
paper_figs_dir = abspath(joinpath(_ROOT, "..", "..", "paper", "sections", "figs"))
mkpath(paper_figs_dir)
paper_figs = joinpath(paper_figs_dir, "Fig6-Statistical-Validation.pdf")

savefig(fig6, out_figs)
@info "Saved  → $out_figs"
cp(out_figs, paper_figs; force = true)
@info "Copied → $paper_figs"

# ── 13. Supplemental figure: IS ACF comparison (all paths vs jump paths) ────
@info "Building supplemental ACF comparison..."

acf_mn_all = [mean(is_acf_mat_all[l, :]) for l in 1:_L_ACF]
acf_lo_all = [quantile(is_acf_mat_all[l, :], 0.10) for l in 1:_L_ACF]
acf_hi_all = [quantile(is_acf_mat_all[l, :], 0.90) for l in 1:_L_ACF]

ps = plot(; legend = :topright, legendfontsize = 9,
    bg = "grey97", background_color_outside = "white",
    framestyle = :box, fg_legend = :transparent,
    xguidefontsize = 13, yguidefontsize = 13, titlefontsize = 14,
    bottom_margin = 12Plots.mm, left_margin = 14Plots.mm,
    size = (900, 500))

# All paths (diluted)
plot!(ps, lags_is, acf_lo_all; fillrange = acf_hi_all,
      fillalpha = 0.15, lw = 0, c = col_all, label = "")
plot!(ps, lags_is, acf_mn_all; lw = 2.0, c = col_all, ls = :dash,
      label = @sprintf("All paths (%d), ACF-MAE = %.3f",
          _N_PATHS, mean(abs.(is_obs_acf .- acf_mn_all))))

# Jump paths
plot!(ps, lags_is, acf_lo; fillrange = acf_hi,
      fillalpha = 0.20, lw = 0, c = col_wj, label = "")
plot!(ps, lags_is, acf_mn; lw = 2.5, c = col_wj,
      label = @sprintf("Jump paths (%d), ACF-MAE = %.3f",
          n_is_jump, mean(abs.(is_obs_acf .- acf_mn))))

# Observed
plot!(ps, lags_is, is_obs_acf; lw = 3.0, c = col_obs, ls = :dash, label = "SPY Observed")
hline!(ps, [ci_band_is]; lw = 1, ls = :dot, c = :black, label = "95% CI")
hline!(ps, [-ci_band_is]; lw = 1, ls = :dot, c = :black, label = "")

xlabel!(ps, "Lag (trading days)")
ylabel!(ps, "ACF of |Excess Growth Rate|")
title!(ps, "In-Sample ACF of |Gₜ|: All Paths vs. Jump-Containing Paths")

out_supp = joinpath(_PATH_TO_FIGS, "FigS-ACF-Jump-Paths.pdf")
savefig(ps, out_supp)
cp(out_supp, joinpath(paper_figs_dir, "FigS-ACF-Jump-Paths.pdf"); force = true)
@info "Saved supplemental → $out_supp"

@info "Done."
