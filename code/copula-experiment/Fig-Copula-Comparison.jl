# =============================================================================
# Fig-Copula-Comparison.jl
#
# Generates the copula comparison figure (2 panels):
#   (a) Grouped bar chart: per-ticker KS pass rates for 4 dependence models
#   (b) Correlation heatmaps: observed vs Student-t copula (best model)
#
# Prerequisites:
#   data/Copula-Comparison-Results.jld2 — from Copula-Comparison.jl
#
# Outputs:
#   figs/Fig-Copula-Comparison.pdf
#   paper/sections/figs/Fig-Copula-Comparison.pdf
# =============================================================================

include("Include.jl")

# ── 1. Load results ──────────────────────────────────────────────────────────
@info "Loading copula comparison results..."
d = load(joinpath(_PATH_TO_DATA, "Copula-Comparison-Results.jld2"))
results  = d["results"]
TICKERS  = d["tickers"]
obs_corr = d["obs_corr"]

dep_names = ["SingleIndexModel", "GaussianCopula", "StudentTCopula", "VineCopula"]
display_names = ["SIM", "Gaussian", "Student-t", "Vine"]

# ── 2. Colours ───────────────────────────────────────────────────────────────
col_sim   = colorant"#808080"   # gray
col_gauss = colorant"#457b9d"   # steel
col_studt = colorant"#1d3557"   # navy
col_vine  = colorant"#2a9d8f"   # teal
model_colors = [col_sim, col_gauss, col_studt, col_vine]

basestyle = (bg                       = "grey97",
             background_color_outside = "white",
             framestyle               = :box,
             fg_legend                = :transparent,
             xguidefontsize           = 12,
             yguidefontsize           = 12,
             titlefontsize            = 13,
             bottom_margin            = 12Plots.mm,
             left_margin              = 14Plots.mm)

# ── 3. Panel (a): Grouped bar chart of KS pass rates ────────────────────────
@info "Building panel (a)..."

# Collect KS pass rates per ticker per model
n_tickers = length(TICKERS)
n_models  = length(dep_names)
ks_matrix = zeros(n_tickers, n_models)  # tickers x models
se_matrix = zeros(n_tickers, n_models)

for (j, name) in enumerate(dep_names)
    r = results[name]
    for (i, ticker) in enumerate(TICKERS)
        if haskey(r.marginal, ticker)
            ks_matrix[i, j] = r.marginal[ticker].ks_pass
            se_matrix[i, j] = r.marginal[ticker].ks_se
        else
            ks_matrix[i, j] = NaN  # SPY missing from SIM
            se_matrix[i, j] = NaN
        end
    end
end

# Build grouped bar chart manually
bar_width = 0.18
pa = plot(; legend = :bottomleft, legendfontsize = 9, basestyle...,
          ylims = (0, 110), ylabel = "KS Pass Rate (%)",
          title = "(a) Marginal Fidelity by Dependence Model")

for (j, (name, col)) in enumerate(zip(display_names, model_colors))
    x_offsets = collect(1:n_tickers) .+ (j - (n_models+1)/2) * bar_width
    vals = ks_matrix[:, j]
    # Replace NaN with 0 for plotting, mark with annotation
    plot_vals = replace(vals, NaN => 0.0)
    bar!(pa, x_offsets, plot_vals;
         bar_width = bar_width, color = col, alpha = 0.85,
         lw = 0.5, lc = :white, label = name)
end

# Add 95% threshold line
hline!(pa, [95.0]; lw = 2, ls = :dash, c = colorant"#e63946", label = "95% threshold")

# N/A annotation for SIM-SPY
sim_spy_x = 1 + (1 - (n_models+1)/2) * bar_width
annotate!(pa, sim_spy_x, 5, text("N/A", :center, 7, col_sim))

# Ticker labels on x-axis
plot!(pa; xticks = (1:n_tickers, TICKERS), xrotation = 0)

# ── 4. Panel (b): Correlation heatmaps ──────────────────────────────────────
@info "Building panel (b)..."

# Get Student-t copula simulated correlation (the winner)
studt_corr = results["StudentTCopula"].sim_corr

# Compute correlation error matrix
corr_err = obs_corr .- studt_corr

# Build a single heatmap showing observed (lower triangle) and simulated (upper triangle)
# with the error annotated
n = length(TICKERS)
combined = zeros(n, n)
for i in 1:n
    for j in 1:n
        if i == j
            combined[i, j] = 1.0
        elseif i > j
            combined[i, j] = obs_corr[i, j]      # lower triangle: observed
        else
            combined[i, j] = studt_corr[i, j]     # upper triangle: simulated
        end
    end
end

pb = heatmap(1:n, 1:n, combined;
    color = :RdBu, clims = (-0.2, 1.0),
    xticks = (1:n, TICKERS), yticks = (1:n, TICKERS),
    xrotation = 0,
    colorbar_title = "Correlation",
    title = "(b) Observed (lower) vs Student-t Copula (upper)",
    basestyle...)

# Annotate cells with values
for i in 1:n
    for j in 1:n
        val = combined[i, j]
        txt_col = abs(val) > 0.5 ? :white : :black
        annotate!(pb, j, i, text(@sprintf("%.2f", val), :center, 9, txt_col))
    end
end

# Add dividing line annotations
for i in 1:n
    annotate!(pb, i, i, text("1.00", :center, 9, :white))
end

# ── 5. Combine and save ─────────────────────────────────────────────────────
@info "Saving copula comparison figure..."
fig = plot(pa, pb; layout = (1, 2), size = (1400, 500), dpi = 150)

out_figs = joinpath(_PATH_TO_FIGS, "Fig-Copula-Comparison.pdf")
savefig(fig, out_figs)
@info "Saved  → $out_figs"

paper_figs_dir = abspath(joinpath(_ROOT, "..", "..", "paper", "sections", "figs"))
mkpath(paper_figs_dir)
paper_figs = joinpath(paper_figs_dir, "Fig-Copula-Comparison.pdf")
cp(out_figs, paper_figs; force = true)
@info "Copied → $paper_figs"
@info "Done."
