# =============================================================================
# Fig4-Replot-SPY.jl
#
# Regenerates Figure 4 using JumpHMM.jl models (no GARCH refitting).
# Scientific improvements over GARCH-Benchmark-SPY.jl:
#
#   (a) Density — annotates KS pass rates; GARCH IS failure is explicit.
#   (b) ACF of |Gₜ| — separates HMM-WJ into three layers:
#         · HMM-NJ mean (structural ≈0; no jumps → no persistent ACF)
#         · HMM-WJ all-paths mean (diluted by ~76% no-jump paths)
#         · HMM-WJ jump-containing paths (~24%): sustained ACF decay family
#   (c) Tail Q-Q — distributional tail fidelity comparison.
#
# Outputs:  figs/Fig4-Model-Comparison.pdf
#           paper/sections/figs/Fig4-Model-Comparison.pdf
# =============================================================================

include("Include.jl")

const _N_PATHS  = 1_000
const _L_ACF    = 252
const _JLD2_HMM   = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")
const _JLD2_GARCH = joinpath(_PATH_TO_DATA, "GARCH-Benchmark-SPY.jld2")

# ── 1. Load saved artefacts ───────────────────────────────────────────────────
@info "Loading data..."
garch_d = load(_JLD2_GARCH)
hmm_d   = load(_JLD2_HMM)

g_is = hmm_d["insampledataset"]
T_is = length(g_is)

# GARCH paths and metrics (precomputed)
garch_paths   = garch_d["garch_is_paths"]
garch_acf_mat = garch_d["garch_is_metrics"].acf_mat
garch_ks_rate = garch_d["garch_is_metrics"].ks_pass_rate
nj_ks_rate    = garch_d["hmm_nj_is_metrics"].ks_pass_rate
wj_ks_rate    = garch_d["hmm_wj_is_metrics"].ks_pass_rate
nj_acf_mat    = garch_d["hmm_nj_is_metrics"].acf_mat

@info @sprintf("  Pass rates: GARCH=%.1f%%  NJ=%.1f%%  WJ=%.1f%%",
               100garch_ks_rate, 100nj_ks_rate, 100wj_ks_rate)

# ── 2. Simulate HMM paths via JumpHMM ──────────────────────────────────────
model_nj = hmm_d["model_nj"]
model_wj = hmm_d["model_wj"]

@info "Simulating $_N_PATHS HMM-NJ IS paths..."
nj_result = simulate(model_nj, T_is; n_paths = _N_PATHS, seed = 1234)
hmm_nj_paths = hcat([p.observations for p in nj_result.paths]...)

@info "Simulating $_N_PATHS HMM-WJ IS paths..."
wj_result = simulate(model_wj, T_is; n_paths = _N_PATHS, seed = 1234)
wj_all = hcat([p.observations for p in wj_result.paths]...)

jump_idx   = findall(p -> any(p.jumps), wj_result.paths)
nojump_idx = findall(p -> !any(p.jumps), wj_result.paths)
n_jump     = length(jump_idx)
n_nojump   = length(nojump_idx)
@info @sprintf("  Jump paths: %d / %d  (%.1f%%)", n_jump, _N_PATHS, 100n_jump/_N_PATHS)

wj_jump = wj_all[:, jump_idx]

# ── 3. ACF computations ───────────────────────────────────────────────────────
@info "Computing ACF statistics..."
lag_vec  = collect(1:_L_ACF)
obs_acf  = autocor(abs.(g_is), lag_vec)
ci_band  = 1.96 / sqrt(T_is)

function acf_band(acf_mat)
    nlags = size(acf_mat, 1)
    mn   = [mean(acf_mat[l, :]) for l in 1:nlags]
    lo   = [quantile(acf_mat[l, :], 0.10) for l in 1:nlags]
    hi   = [quantile(acf_mat[l, :], 0.90) for l in 1:nlags]
    return mn, lo, hi
end

function build_acf_mat(paths, lags)
    mat = Matrix{Float64}(undef, length(lags), size(paths, 2))
    for i in 1:size(paths, 2)
        mat[:, i] = autocor(abs.(paths[:, i]), lags)
    end
    return mat
end

garch_acf_mn,    garch_lo,    garch_hi    = acf_band(garch_acf_mat)
nj_acf_mn,       _,           _           = acf_band(nj_acf_mat)

wj_all_acf_mat  = build_acf_mat(wj_all,  lag_vec)
wj_jump_acf_mat = build_acf_mat(wj_jump, lag_vec)

wj_all_mn,  _,          _           = acf_band(wj_all_acf_mat)
wj_jump_mn, wj_jump_lo, wj_jump_hi  = acf_band(wj_jump_acf_mat)

# ── 4. Colours and base style ─────────────────────────────────────────────────
col_obs   = colorant"#e63946"
col_garch = colorant"#f4a261"
col_nj    = colorant"#457b9d"
col_wj    = colorant"#1d3557"

basestyle = (bg                       = "grey97",
             background_color_outside = "white",
             framestyle               = :box,
             fg_legend                = :transparent,
             xguidefontsize           = 12,
             yguidefontsize           = 12,
             titlefontsize            = 12,
             bottom_margin            = 12Plots.mm,
             left_margin              = 14Plots.mm)

# ── 5. Panel (a): Marginal density ───────────────────────────────────────────
@info "Building panel (a)..."
n_fan = 40

pa = plot(; legend = :topleft, legendfontsize = 8, basestyle...)

for i in 1:min(n_fan, size(garch_paths, 2))
    density!(pa, garch_paths[:, i]; lw = 0.4, c = col_garch, alpha = 0.12, label = "")
end
density!(pa, garch_paths[:, 1]; lw = 2.5, c = col_garch,
         label = @sprintf("GARCH(1,1) — KS pass %.0f%%", 100garch_ks_rate))

for i in 1:min(n_fan, size(hmm_nj_paths, 2))
    density!(pa, hmm_nj_paths[:, i]; lw = 0.4, c = col_nj, alpha = 0.12, label = "")
end
density!(pa, hmm_nj_paths[:, 1]; lw = 2.5, c = col_nj,
         label = @sprintf("HMM-NJ — KS pass %.0f%%", 100nj_ks_rate))

for i in 1:min(n_fan, size(wj_jump, 2))
    density!(pa, wj_jump[:, i]; lw = 0.4, c = col_wj, alpha = 0.12, label = "")
end
density!(pa, wj_jump[:, 1]; lw = 2.5, c = col_wj,
         label = @sprintf("HMM-WJ — KS pass %.0f%%", 100wj_ks_rate))

density!(pa, g_is; lw = 3.0, c = col_obs, ls = :dash, label = "SPY Observed")

xlims!(pa, -8, 8)
xlabel!(pa, "Excess Annual Growth Rate")
ylabel!(pa, "Density")
title!(pa, "(a) Marginal Distributions (IS)")

# ── 6. Panel (b): ACF of |Gₜ| ────────────────────────────────────────────────
@info "Building panel (b)..."

pb = plot(; legend = :topright, legendfontsize = 8, basestyle...)

plot!(pb, lag_vec, garch_lo; fillrange = garch_hi,
      fillalpha = 0.18, lw = 0, c = col_garch, label = "")
plot!(pb, lag_vec, garch_acf_mn; lw = 2.0, c = col_garch, label = "GARCH(1,1)")

plot!(pb, lag_vec, nj_acf_mn;
      lw = 1.5, c = col_nj, ls = :dot,
      label = "HMM-NJ (ACF → 0 without jumps)")

plot!(pb, lag_vec, wj_all_mn;
      lw = 1.5, c = col_wj, ls = :dash,
      label = @sprintf("HMM-WJ all paths (~%.0f%% no jump)", 100n_nojump/_N_PATHS))

plot!(pb, lag_vec, wj_jump_lo; fillrange = wj_jump_hi,
      fillalpha = 0.22, lw = 0, c = col_wj, label = "")
plot!(pb, lag_vec, wj_jump_mn;
      lw = 2.5, c = col_wj,
      label = @sprintf("HMM-WJ jump paths (~%.0f%% of ensemble)", 100n_jump/_N_PATHS))

plot!(pb, lag_vec, obs_acf; lw = 3.0, c = col_obs, ls = :dash, label = "SPY Observed")

hline!(pb, [ci_band]; lw = 1, ls = :dot, c = :black, label = "95% CI")
hline!(pb, [-ci_band]; lw = 1, ls = :dot, c = :black, label = "")

xlabel!(pb, "Lag (trading days)")
ylabel!(pb, "ACF of |Excess Growth Rate|")
title!(pb, "(b) Volatility Clustering — ACF of |Gₜ|")

# ── 7. Panel (c): Tail Q-Q ────────────────────────────────────────────────────
@info "Building panel (c)..."

tail_p  = [0.001, 0.005, 0.01, 0.025, 0.05, 0.95, 0.975, 0.99, 0.995, 0.999]
obs_q   = quantile(g_is, tail_p)

function mean_q(paths, probs)
    [mean(quantile(paths[:, i], p) for i in 1:size(paths, 2)) for p in probs]
end

garch_q = mean_q(garch_paths,  tail_p)
nj_q    = mean_q(hmm_nj_paths, tail_p)
wj_q    = mean_q(wj_all,       tail_p)

all_vals = vcat(obs_q, garch_q, nj_q, wj_q)
ax_lo = minimum(all_vals) * 1.12
ax_hi = maximum(all_vals) * 1.12

pc = plot(; legend = :topleft, legendfontsize = 8, basestyle...)

plot!(pc, [ax_lo, ax_hi], [ax_lo, ax_hi]; lw = 2, ls = :dash, c = col_obs, label = "45° (perfect)")
scatter!(pc, obs_q, garch_q; ms = 7, mc = col_garch, msw = 0, label = "GARCH(1,1)")
scatter!(pc, obs_q, nj_q;    ms = 7, mc = col_nj,    msw = 0, label = "HMM-NJ")
scatter!(pc, obs_q, wj_q;    ms = 7, mc = col_wj,    msw = 0, label = "HMM-WJ")

xlims!(pc, ax_lo, ax_hi)
ylims!(pc, ax_lo, ax_hi)
xlabel!(pc, "Observed Quantile (year⁻¹)")
ylabel!(pc, "Mean Simulated Quantile (year⁻¹)")
title!(pc, "(c) Tail Q-Q (0.1th – 99.9th percentile)")

# ── 8. Combine and save ───────────────────────────────────────────────────────
@info "Saving Figure 4..."
fig4 = plot(pa, pb, pc; layout = (1, 3), size = (1800, 560), dpi = 150)

out_figs       = joinpath(_PATH_TO_FIGS, "Fig4-Model-Comparison.pdf")
paper_figs_dir = abspath(joinpath(_ROOT, "..", "..", "paper", "sections", "figs"))
mkpath(paper_figs_dir)
paper_figs = joinpath(paper_figs_dir, "Fig4-Model-Comparison.pdf")

savefig(fig4, out_figs)
@info "Saved  → $out_figs"
cp(out_figs, paper_figs; force = true)
@info "Copied → $paper_figs"
@info "Done — Figure 4 complete."
