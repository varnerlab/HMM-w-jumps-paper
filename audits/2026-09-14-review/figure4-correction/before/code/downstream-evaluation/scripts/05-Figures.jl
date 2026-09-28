# =============================================================================
# 05-Figures.jl
#
# Produces the paper figures from data/results.jld2.
#
# Outputs:
#   jfds-paper/figs/main/Fig06-Variance-Preservation.pdf
#   jfds-paper/figs/supplement/FigS02-Tail-Preservation.pdf
#   jfds-paper/figs/supplement/FigS06-Branch-Map.pdf
# =============================================================================

include(joinpath(@__DIR__, "..", "Include.jl"))

const _PAPER_ROOT    = abspath(joinpath(_ROOT, "..", "..", "jfds-paper"))
const _PATH_TO_MAIN_FIGS = joinpath(_PAPER_ROOT, "figs", "main")
const _PATH_TO_SUPP_FIGS = joinpath(_PAPER_ROOT, "figs", "supplement")
mkpath(_PATH_TO_MAIN_FIGS)
mkpath(_PATH_TO_SUPP_FIGS)

# paper-friendly defaults
default(
    fontfamily    = "Computer Modern",
    titlefontsize = 13,
    guidefontsize = 12,
    tickfontsize  = 10,
    legendfontsize = 10,
    foreground_color_legend = nothing,
    background_color_legend = :white,
    grid           = true,
    gridalpha      = 0.25,
    framestyle     = :box,
)

# ── 1. Load artifacts ───────────────────────────────────────────────────────
@info "Loading results + calibration..."
results_filename = get(ENV, "HMM_PAPER_RESULTS_FILE", "results.jld2")
r   = load(resolve_data_artifact(results_filename))["results"]
cal = load(resolve_data_artifact("sim-calibration.jld2"))["calibration"]
uni = load(resolve_data_artifact("universe.jld2"))

G    = uni["growth_rates"]
tks  = uni["tickers"]
σ²_m = var(G[:, findfirst(==("SPY"), tks)])

cmap_β  = Dict(zip(cal.ticker, cal.beta))
cmap_R² = Dict(zip(cal.ticker, cal.r2_real))
σ²_real = Dict(tks[j] => var(G[:, j]) for j in 1:length(tks))

r.beta_cal = [cmap_β[t]  for t in r.ticker]
r.r2_cal   = [cmap_R²[t] for t in r.ticker]

# ── 2. Per-ticker per-composer summaries ────────────────────────────────────
summary = combine(groupby(r, [:ticker, :composer]),
    :β_hat   => median => :β_hat_med,
    :R²_hat  => median => :R²_hat_med,
    :ks_p    => (p -> mean(p .> 0.05)) => :ks_pass,
    :w1      => median => :w1_med,
    :kurt    => median => :kurt_med,
    :hill_up => median => :hill_med,
    :var_g   => median => :var_med,
)
summary.beta_cal = [cmap_β[t]  for t in summary.ticker]
summary.r2_cal   = [cmap_R²[t] for t in summary.ticker]
summary.var_rel  = summary.var_med ./ [σ²_real[t] for t in summary.ticker]

function composer_frame(df::DataFrame, name::String)
    return filter(row -> row.composer == name, df)
end

# Okabe-Ito colourblind-safe palette
const OI_BLUE       = RGB(0 / 255,   114 / 255, 178 / 255)  # deep blue
const OI_ORANGE     = RGB(230 / 255, 159 / 255,   0 / 255)  # orange
const OI_VERMILLION = RGB(213 / 255,  94 / 255,   0 / 255)  # red-orange (hero)
const OI_GREEN      = RGB(0 / 255,   158 / 255, 115 / 255)  # bluish green
const OI_SKY        = RGB(86 / 255,  180 / 255, 233 / 255)  # sky blue
const OI_YELLOW     = RGB(240 / 255, 228 / 255,  66 / 255)  # yellow
const OI_PURPLE     = RGB(204 / 255, 121 / 255, 167 / 255)  # reddish purple

color_map  = Dict("naive" => OI_BLUE, "gaussian" => OI_PURPLE, "hybrid" => OI_VERMILLION)
marker_map = Dict("naive" => :circle, "gaussian" => :square,   "hybrid" => :diamond)
label_map  = Dict("naive" => "Naive", "gaussian" => "Gaussian SIM", "hybrid" => "Hybrid")

function scatter_composers!(plt, df::DataFrame, ycol::Symbol;
                            alpha::Float64 = 0.4, markersize::Real = 3.5,
                            labels::Bool = true,
                            composers = ("naive", "gaussian", "hybrid"),
                            colors = color_map)
    for c in composers
        sc = composer_frame(df, c)
        scatter!(plt, sc.beta_cal, sc[!, ycol];
                 label  = labels ? label_map[c] : nothing,
                 color  = colors[c],
                 marker = marker_map[c],
                 markersize = markersize,
                 alpha  = alpha,
                 markerstrokecolor = colors[c],
                 markerstrokewidth = 0.0)
    end
    return plt
end

function _weighted_median(y::AbstractVector, w::AbstractVector)
    idx = sortperm(y)
    ys = @view y[idx]
    ws = @view w[idx]
    cw = cumsum(ws)
    target = 0.5 * cw[end]
    return ys[searchsortedfirst(cw, target)]
end

function kernel_smooth_line!(plt, df::DataFrame, ycol::Symbol;
                             bandwidth::Real = 0.12, n_grid::Int = 80, lw::Real = 2.5,
                             composers = ("naive", "gaussian", "hybrid"),
                             colors = color_map)
    for c in composers
        sc = composer_frame(df, c)
        x = Vector{Float64}(sc.beta_cal)
        y = Vector{Float64}(sc[!, ycol])
        grid = range(minimum(x), maximum(x); length = n_grid)
        ys = [_weighted_median(y, @. exp(-((x - g)^2) / (2bandwidth^2))) for g in grid]
        plot!(plt, collect(grid), ys;
              label = nothing, color = colors[c], lw = lw)
    end
    return plt
end

function binned_median_line!(plt, df::DataFrame, ycol::Symbol;
                             n_bins::Int = 12, lw::Real = 2.5,
                             composers = ("naive", "gaussian", "hybrid"))
    for c in composers
        sc = composer_frame(df, c)
        edges = quantile(sc.beta_cal, range(0.0, 1.0; length = n_bins + 1))
        xs = Float64[]; ys = Float64[]
        for k in 1:n_bins
            lo, hi = edges[k], edges[k + 1]
            mask = (sc.beta_cal .>= lo) .& (sc.beta_cal .<= hi)
            any(mask) || continue
            push!(xs, (lo + hi) / 2)
            push!(ys, median(sc[!, ycol][mask]))
        end
        plot!(plt, xs, ys;
              label = nothing,
              color = color_map[c],
              lw    = lw)
    end
    return plt
end

# ── 3. Figure 1: KS pass rate + variance ratio ──────────────────────────────
@info "Building Figure 1: preservation headline..."

# Match Fig01-Empirical-Motivation rather than the generic defaults used by
# the supplementary diagnostics.
const FIG_BG   = colorant"#f2f2f2"
const FIG_RED  = colorant"#e63946"
const FIG_NAVY = colorant"#1d3557"
const FIG1_COLORS = Dict("naive" => FIG_NAVY, "hybrid" => FIG_RED)

p1a = plot(title = "(a) KS Pass Rate per Ticker",
           xlabel = "Calibrated \$\\beta\$",
           ylabel = "KS Pass Rate (\$\\alpha = 0.05\$)",
           ylims = (-0.02, 1.05),
           legend = :topright,
           bg = FIG_BG, background_color_outside = :white,
           framestyle = :box, fontfamily = "sans-serif",
           titlefontsize = 13, guidefontsize = 14, tickfontsize = 10,
           foreground_color_legend = :transparent)
const _FIG1_COMPOSERS = ("naive", "hybrid")
scatter_composers!(p1a, summary, :ks_pass; markersize = 3.5, alpha = 0.45,
                   composers = _FIG1_COMPOSERS, colors = FIG1_COLORS)
kernel_smooth_line!(p1a, summary, :ks_pass; composers = _FIG1_COMPOSERS,
                    colors = FIG1_COLORS, bandwidth = 0.15)

p1b = plot(title = "(b) Variance Preservation",
           xlabel = "Calibrated \$\\beta\$",
           ylabel = "\$\\mathrm{Var}(g)\\,/\\,\\sigma^2_{\\mathrm{gen}}\$",
           legend = false,
           bg = FIG_BG, background_color_outside = :white,
           framestyle = :box, fontfamily = "sans-serif",
           titlefontsize = 13, guidefontsize = 14, tickfontsize = 10)
scatter_composers!(p1b, summary, :var_rel; markersize = 3.5, alpha = 0.45, labels = false,
                   composers = _FIG1_COMPOSERS, colors = FIG1_COLORS)
βs_dense = range(0.0, maximum(summary.beta_cal) * 1.02; length = 200)
σ²_gen_med = median(values(σ²_real))
naive_ref = 1.0 .+ βs_dense.^2 .* σ²_m / σ²_gen_med
plot!(p1b, βs_dense, naive_ref;
      label = nothing, color = FIG_NAVY, ls = :dot, lw = 2)
hline!(p1b, [1.0]; label = nothing, color = FIG_RED, ls = :dash, lw = 2)
annotate!(p1b, βs_dense[end-10], naive_ref[end-10] * 1.02,
          text("naive theory \$1+\\rho\$", FIG_NAVY, 9, :right))
annotate!(p1b, 0.05, 1.03, text("hybrid target", FIG_RED, 9, :left))

fig1 = plot(p1a, p1b;
            layout = (1, 2), size = (1200, 450),
            left_margin = 12Plots.mm, right_margin = 3Plots.mm,
            bottom_margin = 12Plots.mm, top_margin = 3Plots.mm)
savefig(fig1, joinpath(_PATH_TO_MAIN_FIGS, "Fig06-Variance-Preservation.pdf"))
@info "Wrote main/Fig06-Variance-Preservation.pdf"

# ── 4. Figure 2: kurtosis (clipped) and Hill index ──────────────────────────
#
# Caption caveat (for paper): the "real data" reference line on the left panel
# is the median empirical excess kurtosis across the universe. The hybrid
# median (~7) sits below it (~13) because the JumpHMM marginal is fit to
# preserve the generator's *own* heavy-tailed marginal, which tracks each
# asset's distributional shape but does not replicate the extreme empirical
# 4th moment exactly. The point of the panel is that hybrid tracks the naive
# composition (both inherit the generator tails) while Gaussian SIM collapses
# to κ ≈ 1 regardless of β.
@info "Building Figure 2: tails and kurtosis..."

# real-data reference median
summary.kurt_real = [kurtosis(G[:, findfirst(==(t), tks)]) for t in summary.ticker]
real_kurt_med = median(summary.kurt_real)

p2a = plot(title = "Excess kurtosis vs \$\\beta\$",
           xlabel = "calibrated \$\\beta\$",
           ylabel = "excess kurtosis",
           ylims = (-2, 20),
           legend = :topright)
scatter_composers!(p2a, summary, :kurt_med; markersize = 3.5, alpha = 0.5)
kernel_smooth_line!(p2a, summary, :kurt_med; bandwidth = 0.15)
hline!(p2a, [real_kurt_med];
       label = "real data (median)",
       color = :black, lw = 2, ls = :dash)

p2b = plot(title = "Hill tail index vs \$\\beta\$",
           xlabel = "calibrated \$\\beta\$",
           ylabel = "Hill index, upper 5 pct tail",
           legend = false)
scatter_composers!(p2b, summary, :hill_med; markersize = 3.5, alpha = 0.5, labels = false)
kernel_smooth_line!(p2b, summary, :hill_med; bandwidth = 0.15)

fig2 = plot(p2a, p2b;
            layout = (1, 2), size = (1200, 450),
            left_margin = 6Plots.mm, bottom_margin = 5Plots.mm,
            top_margin = 3Plots.mm)
savefig(fig2, joinpath(_PATH_TO_SUPP_FIGS, "FigS02-Tail-Preservation.pdf"))
@info "Wrote supplement/FigS02-Tail-Preservation.pdf"

# ── 5. Figure 3: branch map in (β, R²) space ────────────────────────────────
@info "Building Figure 3: branch map..."
hyb_summary = composer_frame(summary, "hybrid")
flag_by_ticker = combine(groupby(filter(row -> row.composer == "hybrid", r), :ticker),
    :flag => first => :flag)
flag_lookup = Dict(zip(flag_by_ticker.ticker, flag_by_ticker.flag))
hyb_summary.flag = [flag_lookup[t] for t in hyb_summary.ticker]

p3 = plot(title = "Branch selection in \$(\\beta,\\, R^2_{\\mathrm{real}})\$ space",
          xlabel = "calibrated \$\\beta\$",
          ylabel = "calibrated \$R^2_{\\mathrm{real}}\$",
          ylims = (-0.02, 1.05),
          legend = :topleft, size = (900, 500),
          left_margin = 6Plots.mm, bottom_margin = 5Plots.mm)

flag_color  = Dict("HYBRID" => OI_VERMILLION, "HYBRID_CLIPPED" => OI_YELLOW, "R2_PRESERVE" => OI_GREEN)
flag_label  = Dict("HYBRID" => "hybrid (variance-preserving)",
                   "HYBRID_CLIPPED" => "hybrid-clipped",
                   "R2_PRESERVE" => "\$R^2\$-preserving")
flag_marker = Dict("HYBRID" => :circle, "HYBRID_CLIPPED" => :xcross, "R2_PRESERVE" => :star5)
flag_size   = Dict("HYBRID" => 4, "HYBRID_CLIPPED" => 6, "R2_PRESERVE" => 8)

for flg in ("HYBRID", "HYBRID_CLIPPED", "R2_PRESERVE")
    sub = filter(row -> row.flag == flg, hyb_summary)
    isempty(sub) && continue
    scatter!(p3, sub.beta_cal, sub.r2_cal;
             label  = "$(flag_label[flg]) (\$n=$(nrow(sub))\$)",
             color  = flag_color[flg],
             marker = flag_marker[flg],
             markersize = flag_size[flg],
             alpha = 0.55,
             markerstrokecolor = flag_color[flg],
             markerstrokewidth = 0.0)
end
hline!(p3, [0.80]; label = "\$R^2_{\\mathrm{preserve}} = 0.80\$",
       lw = 2, ls = :dash, color = :black)

# label the two trackers
for row in eachrow(filter(r -> r.flag == "R2_PRESERVE", hyb_summary))
    annotate!(p3, row.beta_cal + 0.02, row.r2_cal,
              text(row.ticker, OI_GREEN, 10, :left))
end

savefig(p3, joinpath(_PATH_TO_SUPP_FIGS, "FigS06-Branch-Map.pdf"))
@info "Wrote supplement/FigS06-Branch-Map.pdf"

@info "All figures written to $_PAPER_ROOT/figs/{main,supplement}"
