# =============================================================================
# Fig7-Multi-Asset-SIM.jl
#
# Generates Figure 7: Multi-Asset SIM Extension (5 panels composed as 2×3)
#   (a) Scatter of β̂ᵢ vs R²ᵢ colored by GICS sector
#   (b) Histogram of KS pass rates across 424 assets
#   (c₁–c₃) Density comparisons for 3 representative assets
#
# Prerequisites:
#   data/SIM-Multi-Asset-Results.jld2 — from SIM-Multi-Asset-KS.jl
#   data/SP500-GICS-Sectors.csv       — GICS sector mapping
#   data/SIMs-SP500-01-03-14-to-12-31-24.jld2 — SIM parameters
#
# Outputs:
#   figs/Fig7-Multi-Asset-SIM.pdf
#   paper/sections/figs/Fig7-Multi-Asset-SIM.pdf
# =============================================================================

include(joinpath(@__DIR__, "Include.jl"))

const _ALPHA = 0.05
const _DT    = 1.0 / 252.0

# ── 1. Load data ─────────────────────────────────────────────────────────────
@info "Loading multi-asset results..."
results = load(joinpath(_PATH_TO_DATA, "SIM-Multi-Asset-Results.jld2"))
tickers       = results["tickers"]
betas         = results["betas"]
alphas        = results["alphas"]
r_squared     = results["r_squared"]
ks_pass_rates = results["ks_pass_rates"]
spy_sim_paths = results["spy_sim_paths"]
n_assets      = length(tickers)
T_is          = size(spy_sim_paths, 1)
n_spy_paths   = size(spy_sim_paths, 2)

@info "Loading GICS sector mapping..."
gics_df = CSV.read(joinpath(_PATH_TO_DATA, "SP500-GICS-Sectors.csv"), DataFrame)
gics_map = Dict(row.Ticker => row.Sector for row in eachrow(gics_df))

@info "Loading SIM parameters..."
sim_data = load(joinpath(_PATH_TO_DATA, "SIMs-SP500-01-03-14-to-12-31-24.jld2"))["data"]

@info "Loading training data for observed growth rates..."
original_dataset = MyTrainingMarketDataSet() |> x -> x["dataset"]
maximum_trading_days = original_dataset["AAPL"] |> nrow
dataset = Dict{String,DataFrame}()
for (ticker, data) in original_dataset
    if nrow(data) == maximum_trading_days
        dataset[ticker] = data
    end
end
list_of_tickers = keys(dataset) |> collect |> sort
growth_rate_array = log_growth_matrix(dataset, list_of_tickers,
    Δt = _DT, risk_free_rate = 0.0)

# ── 2. Map tickers to sectors ────────────────────────────────────────────────
sectors = [get(gics_map, t, "Other") for t in tickers]
unique_sectors = sort(unique(sectors))
@info "  $(length(unique_sectors)) unique sectors: $(join(unique_sectors, ", "))"

# ── 3. Colours and style ────────────────────────────────────────────────────
col_obs = colorant"#e63946"   # crimson
col_wj  = colorant"#1d3557"   # navy

basestyle = (bg                       = "grey97",
             background_color_outside = "white",
             framestyle               = :box,
             fg_legend                = :transparent,
             xguidefontsize           = 10,
             yguidefontsize           = 10,
             titlefontsize            = 11,
             bottom_margin            = 10Plots.mm,
             left_margin              = 12Plots.mm)

# Sector color palette (12 distinct colors)
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
pa = plot(; legend = :outertopright, legendfontsize = 7, basestyle...)

for sec in unique_sectors
    idx = findall(sectors .== sec)
    if isempty(idx)
        continue
    end
    sc = get(sector_colors, sec, colorant"#808080")
    mk = get(sector_markers, sec, :circle)
    scatter!(pa, betas[idx], r_squared[idx];
        ms = 4.5, mc = sc, msc = sc, msw = 0.3, alpha = 0.8,
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
    legend = :topleft, legendfontsize = 8, basestyle...)
vline!(pb, [100 * (1 - _ALPHA)]; lw = 2.5, ls = :dash, c = col_obs,
    label = "95% threshold")
annotate!(pb, 50, 0.92 * ylims(pb)[2],
    text(@sprintf("Median: %.1f%%\nMean: %.1f%%",
        100median(ks_valid), 100mean(ks_valid)), :left, 9, col_wj))
xlabel!(pb, "KS Pass Rate (%)")
ylabel!(pb, "Proportion")
title!(pb, "(b) KS Pass Rates Across 424 Assets")

# ── 6. Panel (c): Representative density comparisons ────────────────────────
@info "Building panels (c₁–c₃)..."

# Select 3 representative tickers
rep_tickers = ["NVDA", "JNJ", "QQQ"]
# Verify they exist
for t in rep_tickers
    @assert t in tickers "Ticker $t not found in results"
end

function make_density_panel(ticker, panel_label; basestyle=basestyle)
    # Get SIM parameters — NamedTuple with fields: alpha, beta, training_variance, etc.
    params_i = sim_data[ticker]
    α_i = params_i.alpha
    β_i = params_i.beta
    # Get observed growth rates and compute empirical residuals
    ti_idx = findfirst(==(ticker), list_of_tickers)
    g_obs = growth_rate_array[:, ti_idx]

    # SPY observed growth rates for residual computation
    spy_obs_idx = findfirst(==("SPY"), list_of_tickers)
    G_spy_obs = growth_rate_array[:, spy_obs_idx]
    resid_i = g_obs .- (α_i .+ β_i .* G_spy_obs)  # empirical residuals

    # Generate 1000 SIM paths using saved SPY paths
    n_paths = size(spy_sim_paths, 2)
    T = size(spy_sim_paths, 1)

    # Compute KDE for observed
    obs_kde = kde(g_obs)
    grid = obs_kde.x

    # Compute KDE for each simulated path (empirical residual bootstrap)
    kde_mat = Matrix{Float64}(undef, length(grid), n_paths)
    for j in 1:n_paths
        η_hat = resid_i[rand(1:T, T)]  # resample with replacement
        G_hat = α_i .+ β_i .* spy_sim_paths[:, j] .+ η_hat
        k = kde(G_hat, grid)
        kde_mat[:, j] = k.density
    end

    kde_median = [median(kde_mat[r, :]) for r in 1:length(grid)]
    kde_lo     = [quantile(kde_mat[r, :], 0.10) for r in 1:length(grid)]
    kde_hi     = [quantile(kde_mat[r, :], 0.90) for r in 1:length(grid)]

    # Get KS pass rate for annotation
    t_idx = findfirst(==(ticker), tickers)
    ks_rate = ks_pass_rates[t_idx]

    p = plot(; legend = :topright, legendfontsize = 7, basestyle...)
    plot!(p, grid, kde_lo; fillrange = kde_hi,
          fillalpha = 0.25, lw = 0, c = col_wj, label = "10th–90th pctile")
    plot!(p, grid, kde_median; lw = 2.0, c = col_wj, label = "Simulated median")
    plot!(p, grid, obs_kde.density; lw = 2.5, c = col_obs, ls = :dash, label = "Observed")
    xlims!(p, quantile(g_obs, 0.001), quantile(g_obs, 0.999))
    xlabel!(p, "Excess Annual Growth Rate")
    ylabel!(p, "Density")
    title!(p, @sprintf("%s %s (β̂=%.2f, KS=%.0f%%)", panel_label, ticker, β_i, 100ks_rate))

    return p
end

pc1 = make_density_panel("NVDA", "(c₁)")
pc2 = make_density_panel("JNJ",  "(c₂)")
pc3 = make_density_panel("QQQ",  "(c₃)")

# ── 7. Combine and save ─────────────────────────────────────────────────────
@info "Saving Figure 7..."
fig7 = plot(pa, pb, pc1, pc2, pc3;
    layout = @layout([a b; c1 c2 c3]),
    size = (1500, 900), dpi = 150)

out_figs       = joinpath(_PATH_TO_FIGS, "Fig7-Multi-Asset-SIM.pdf")
paper_figs_dir = abspath(joinpath(_ROOT, "..", "..", "paper", "sections", "figs"))
mkpath(paper_figs_dir)
paper_figs = joinpath(paper_figs_dir, "Fig7-Multi-Asset-SIM.pdf")

savefig(fig7, out_figs)
@info "Saved  → $out_figs"
cp(out_figs, paper_figs; force = true)
@info "Copied → $paper_figs"
@info "Done — Figure 7 complete."
