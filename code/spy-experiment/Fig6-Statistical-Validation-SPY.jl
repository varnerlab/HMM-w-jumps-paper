# =============================================================================
# Fig6-Statistical-Validation-SPY.jl
#
# Generates Figure 6: Statistical Validation (2×2 panels)
#   (a) In-sample KS p-value histogram
#   (b) Out-of-sample KS p-value histogram
#   (c) Out-of-sample density fan chart
#   (d) Out-of-sample ACF of |Gₜ| with percentile band
#
# Prerequisites:
#   GARCH-Benchmark-SPY.jld2 — provides IS ks_pvals
#   OoS-Validation-SPY.jld2  — provides OoS ks_pvals, paths, ACF data
#     (must be regenerated after adding ks_pvals/acf_mat to compute_metrics)
#
# Outputs:
#   figs/Fig6-Statistical-Validation.pdf
#   paper/sections/figs/Fig6-Statistical-Validation.pdf
# =============================================================================

include("Include.jl")
using KernelDensity

const _JLD2_GARCH = joinpath(_PATH_TO_DATA, "GARCH-Benchmark-SPY.jld2")
const _JLD2_OOS   = joinpath(_PATH_TO_DATA, "OoS-Validation-SPY.jld2")
const _ALPHA      = 0.05

# ── 1. Load data ─────────────────────────────────────────────────────────────
@info "Loading IS data from GARCH-Benchmark-SPY.jld2..."
garch_d = load(_JLD2_GARCH)
is_ks_pvals = garch_d["hmm_wj_is_metrics"].ks_pvals
is_ks_rate  = garch_d["hmm_wj_is_metrics"].ks_pass_rate

@info "Loading OoS data from OoS-Validation-SPY.jld2..."
oos_d = load(_JLD2_OOS)
oos_ks_pvals = oos_d["hmm_wj_oos_metrics"].ks_pvals
oos_ks_rate  = oos_d["hmm_wj_oos_metrics"].ks_pass_rate
g_oos        = oos_d["g_oos"]
wj_oos_all   = oos_d["hmm_wj_oos_all"]     # T_oos × 1000
oos_acf_mat  = oos_d["hmm_wj_oos_metrics"].acf_mat
oos_obs_acf  = oos_d["hmm_wj_oos_metrics"].obs_acf

T_oos   = length(g_oos)
n_paths = size(wj_oos_all, 2)
n_lags  = size(oos_acf_mat, 1)

@info "  IS  KS pass rate: $(round(100is_ks_rate, digits=1))%"
@info "  OoS KS pass rate: $(round(100oos_ks_rate, digits=1))%"
@info "  OoS length: $T_oos days, $n_paths paths, $n_lags ACF lags"

# ── 2. Colours and style ─────────────────────────────────────────────────────
col_obs = colorant"#e63946"   # crimson
col_wj  = colorant"#1d3557"   # navy

basestyle = (bg                       = "grey97",
             background_color_outside = "white",
             framestyle               = :box,
             fg_legend                = :transparent,
             xguidefontsize           = 11,
             yguidefontsize           = 11,
             titlefontsize            = 11,
             bottom_margin            = 10Plots.mm,
             left_margin              = 12Plots.mm)

# ── 3. Panel (a): IS KS p-value histogram ───────────────────────────────────
@info "Building panel (a)..."
pa = histogram(is_ks_pvals; bins = 20, normalize = :probability,
    color = col_wj, alpha = 0.7, lw = 0.5, lc = :white,
    label = "HMM-WJ (1,000 paths)",
    legend = :topleft, legendfontsize = 8, basestyle...)
vline!(pa, [_ALPHA]; lw = 2.5, ls = :dash, c = col_obs, label = "α = 0.05")
annotate!(pa, 0.55, 0.95 * ylims(pa)[2],
    text(@sprintf("KS pass rate: %.1f%%", 100is_ks_rate), :left, 9, col_wj))
xlabel!(pa, "KS p-value")
ylabel!(pa, "Proportion")
title!(pa, "(a) In-Sample KS p-values")

# ── 4. Panel (b): OoS KS p-value histogram ──────────────────────────────────
@info "Building panel (b)..."
pb = histogram(oos_ks_pvals; bins = 20, normalize = :probability,
    color = col_wj, alpha = 0.7, lw = 0.5, lc = :white,
    label = "HMM-WJ (1,000 paths)",
    legend = :topleft, legendfontsize = 8, basestyle...)
vline!(pb, [_ALPHA]; lw = 2.5, ls = :dash, c = col_obs, label = "α = 0.05")
annotate!(pb, 0.55, 0.95 * ylims(pb)[2],
    text(@sprintf("KS pass rate: %.1f%%", 100oos_ks_rate), :left, 9, col_wj))
xlabel!(pb, "KS p-value")
ylabel!(pb, "Proportion")
title!(pb, "(b) Out-of-Sample KS p-values")

# ── 5. Panel (c): OoS density fan chart ─────────────────────────────────────
@info "Building panel (c)..."

# Compute KDE for observed
obs_kde = kde(g_oos)
grid    = obs_kde.x

# Compute KDE for each simulated path on the same grid
@info "  Computing KDEs for $n_paths paths..."
kde_mat = Matrix{Float64}(undef, length(grid), n_paths)
for i in 1:n_paths
    k = kde(wj_oos_all[:, i], grid)
    kde_mat[:, i] = k.density
end

kde_median = [median(kde_mat[j, :]) for j in 1:length(grid)]
kde_lo     = [quantile(kde_mat[j, :], 0.10) for j in 1:length(grid)]
kde_hi     = [quantile(kde_mat[j, :], 0.90) for j in 1:length(grid)]

pc = plot(; legend = :topleft, legendfontsize = 8, basestyle...)
plot!(pc, grid, kde_lo; fillrange = kde_hi,
      fillalpha = 0.25, lw = 0, c = col_wj, label = "10th–90th pctile")
plot!(pc, grid, kde_median; lw = 2.0, c = col_wj, label = "Simulated median")
plot!(pc, grid, obs_kde.density; lw = 2.5, c = col_obs, ls = :dash, label = "Observed")
xlims!(pc, quantile(g_oos, 0.001), quantile(g_oos, 0.999))
xlabel!(pc, "Excess Annual Growth Rate")
ylabel!(pc, "Density")
title!(pc, "(c) OoS Density Fan Chart")

# ── 6. Panel (d): OoS ACF of |Gₜ| ──────────────────────────────────────────
@info "Building panel (d)..."
lag_vec = collect(1:n_lags)
ci_band = 1.96 / sqrt(T_oos)

acf_mn = [mean(oos_acf_mat[l, :]) for l in 1:n_lags]
acf_lo = [quantile(oos_acf_mat[l, :], 0.10) for l in 1:n_lags]
acf_hi = [quantile(oos_acf_mat[l, :], 0.90) for l in 1:n_lags]

pd = plot(; legend = :topright, legendfontsize = 8, basestyle...)
plot!(pd, lag_vec, acf_lo; fillrange = acf_hi,
      fillalpha = 0.22, lw = 0, c = col_wj, label = "10th–90th pctile")
plot!(pd, lag_vec, acf_mn; lw = 2.5, c = col_wj, label = "HMM-WJ mean")
plot!(pd, lag_vec, oos_obs_acf; lw = 2.5, c = col_obs, ls = :dash, label = "Observed")
hline!(pd, [ci_band]; lw = 1, ls = :dot, c = :black, label = "95% CI")
hline!(pd, [-ci_band]; lw = 1, ls = :dot, c = :black, label = "")
xlabel!(pd, "Lag (trading days)")
ylabel!(pd, "ACF of |Excess Growth Rate|")
title!(pd, "(d) OoS Volatility Clustering — ACF of |Gₜ|")

# ── 7. Combine and save ─────────────────────────────────────────────────────
@info "Saving Figure 6..."
fig6 = plot(pa, pb, pc, pd; layout = (2, 2), size = (1200, 900), dpi = 150)

out_figs       = joinpath(_PATH_TO_FIGS, "Fig6-Statistical-Validation.pdf")
paper_figs_dir = abspath(joinpath(_ROOT, "..", "..", "paper", "sections", "figs"))
mkpath(paper_figs_dir)
paper_figs = joinpath(paper_figs_dir, "Fig6-Statistical-Validation.pdf")

savefig(fig6, out_figs)
@info "Saved  → $out_figs"
cp(out_figs, paper_figs; force = true)
@info "Copied → $paper_figs"
@info "Done — Figure 6 complete."
