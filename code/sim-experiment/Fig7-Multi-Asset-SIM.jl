# =============================================================================
# Fig7-Multi-Asset-SIM.jl
#
# Generates Figure 5 (in compiled PDF): Multi-Asset SIM Extension (2 panels)
#   (a) Scatter of β̂ᵢ vs R²ᵢ colored by GICS sector
#   (b) Histogram of KS pass rates across 424 assets
#
# Prerequisites:
#   data/SIM-Multi-Asset-Results.jld2 — from SIM-Multi-Asset-KS.jl
#   data/SP500-GICS-Sectors.csv       — GICS sector mapping
#
# Outputs:
#   figs/Fig7-Multi-Asset-SIM.pdf
#   paper/sections/figs/Fig7-Multi-Asset-SIM.pdf
# =============================================================================

include(joinpath(@__DIR__, "Include.jl"))

const _ALPHA = 0.05

# ── 1. Load data ─────────────────────────────────────────────────────────────
@info "Loading multi-asset results..."
results = load(joinpath(_PATH_TO_DATA, "SIM-Multi-Asset-Results.jld2"))
tickers       = results["tickers"]
betas         = results["betas"]
r_squared     = results["r_squared"]
ks_pass_rates = results["ks_pass_rates"]
n_assets      = length(tickers)

@info "Loading GICS sector mapping..."
gics_df = CSV.read(joinpath(_PATH_TO_DATA, "SP500-GICS-Sectors.csv"), DataFrame)
gics_map = Dict(row.Ticker => row.Sector for row in eachrow(gics_df))

# ── 2. Map tickers to sectors ────────────────────────────────────────────────
sectors = [get(gics_map, t, "Other") for t in tickers]
unique_sectors = sort(unique(sectors))

# ── 3. Colours and style ────────────────────────────────────────────────────
col_obs = colorant"#e63946"
col_wj  = colorant"#1d3557"

basestyle = (bg                       = "grey97",
             background_color_outside = "white",
             framestyle               = :box,
             fg_legend                = :transparent,
             xguidefontsize           = 12,
             yguidefontsize           = 12,
             titlefontsize            = 13,
             bottom_margin            = 12Plots.mm,
             left_margin              = 14Plots.mm)

sector_colors = Dict(
    "Communication Services"  => colorant"#e6194b",
    "Consumer Discretionary"  => colorant"#3cb44b",
    "Consumer Staples"        => colorant"#ffe119",
    "Energy"                  => colorant"#4363d8",
    "Financials"              => colorant"#f58231",
    "Health Care"             => colorant"#911eb4",
    "Industrials"             => colorant"#42d4f4",
    "Information Technology"  => colorant"#f032e6",
    "Materials"               => colorant"#bfef45",
    "Real Estate"             => colorant"#469990",
    "Utilities"               => colorant"#9a6324",
    "Other"                   => colorant"#808080",
)

sector_markers = Dict(
    "Communication Services"  => :circle,
    "Consumer Discretionary"  => :diamond,
    "Consumer Staples"        => :utriangle,
    "Energy"                  => :square,
    "Financials"              => :pentagon,
    "Health Care"             => :hexagon,
    "Industrials"             => :star5,
    "Information Technology"  => :dtriangle,
    "Materials"               => :cross,
    "Real Estate"             => :xcross,
    "Utilities"               => :rtriangle,
    "Other"                   => :star4,
)

# ── 4. Panel (a): β̂ᵢ vs R²ᵢ scatter by GICS sector ─────────────────────────
@info "Building panel (a)..."
pa = plot(; legend = :outertopright, legendfontsize = 8, basestyle...)

for sec in unique_sectors
    idx = findall(sectors .== sec)
    isempty(idx) && continue
    sc = get(sector_colors, sec, colorant"#808080")
    mk = get(sector_markers, sec, :circle)
    scatter!(pa, betas[idx], r_squared[idx];
        ms = 5, mc = sc, msc = sc, msw = 0.3, alpha = 0.8,
        marker = mk, label = sec)
end

xlabel!(pa, "β̂ᵢ (Systematic Risk)")
ylabel!(pa, "R²ᵢ (SIM Fit)")
title!(pa, "(a) SIM Fit Quality by GICS Sector")

# ── 5. Panel (b): KS pass rate histogram ────────────────────────────────────
@info "Building panel (b)..."
valid = .!isnan.(ks_pass_rates)
ks_valid = ks_pass_rates[valid]

pb = histogram(100 .* ks_valid; bins = 20, normalize = :probability,
    color = col_wj, alpha = 0.7, lw = 0.5, lc = :white,
    label = "424 Assets",
    legend = :topleft, legendfontsize = 9, basestyle...)
vline!(pb, [100 * (1 - _ALPHA)]; lw = 2.5, ls = :dash, c = col_obs,
    label = "95% threshold")
annotate!(pb, 50, 0.92 * ylims(pb)[2],
    text(@sprintf("Median: %.1f%%\nMean: %.1f%%",
        100median(ks_valid), 100mean(ks_valid)), :left, 10, col_wj))
xlabel!(pb, "KS Pass Rate (%)")
ylabel!(pb, "Proportion")
title!(pb, "(b) KS Pass Rates Across 424 Assets")

# ── 6. Combine and save ─────────────────────────────────────────────────────
@info "Saving Figure..."
fig = plot(pa, pb; layout = (1, 2), size = (1400, 480), dpi = 150)

out_figs       = joinpath(_PATH_TO_FIGS, "Fig7-Multi-Asset-SIM.pdf")
paper_figs_dir = abspath(joinpath(_ROOT, "..", "..", "paper", "sections", "figs"))
mkpath(paper_figs_dir)
paper_figs = joinpath(paper_figs_dir, "Fig7-Multi-Asset-SIM.pdf")

savefig(fig, out_figs)
@info "Saved  → $out_figs"
cp(out_figs, paper_figs; force = true)
@info "Copied → $paper_figs"
@info "Done."
