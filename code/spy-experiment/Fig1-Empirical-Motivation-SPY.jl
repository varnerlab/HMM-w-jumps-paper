# =============================================================================
# Fig1-Empirical-Motivation-SPY.jl
#
# Produces Figure 1 (2×2 layout): empirical stylized facts of SPY daily excess
# growth rates (2014–2024 in-sample window).  No model simulation is required —
# all four panels are computed directly from the observed series.
#
# Panels
#   (a) Histogram with Normal and Laplace MLE fits + excess-kurtosis annotation
#   (b) Normal Q-Q plot — fat-tail deviation at extremes
#   (c) ACF of raw excess growth rates — near-zero, consistent with market efficiency
#   (d) ACF of |excess growth rates| — slow decay, persistent volatility clustering
#
# Outputs
#   code/spy-experiment/figs/Fig1-Empirical-Motivation.pdf
#   paper/sections/figs/Fig1-Empirical-Motivation.pdf   (copy)
# =============================================================================

include("Include.jl")

# ── constants ─────────────────────────────────────────────────────────────────
const _RF_IS = 0.043        # risk-free rate used in in-sample notebook
const _DT    = 1.0 / 252.0  # daily time step (years)
const _L_ACF = 252          # max ACF lag (one trading year)

# ── 1. Load SPY in-sample excess growth rates ────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train  = original_train["AAPL"] |> nrow

train_dataset = Dict{String, DataFrame}()
for (ticker, df) ∈ original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end
tickers_train = keys(train_dataset) |> collect |> sort

all_growth_train = log_growth_matrix(train_dataset, tickers_train;
                       Δt = _DT, risk_free_rate = _RF_IS)

spy_idx = findfirst(x -> x == "SPY", tickers_train)
g_is    = all_growth_train[1:(max_days_train - 1), spy_idx]

@info "  IS observations : $(length(g_is))"
@info "  IS mean         : $(round(mean(g_is),     digits=4))"
@info "  IS std          : $(round(std(g_is),      digits=4))"
@info "  IS kurtosis     : $(round(kurtosis(g_is), digits=3))"

# ── 2. Fit marginal distributions ────────────────────────────────────────────
d_normal  = fit_mle(Normal,  g_is)
d_laplace = fit_mle(Laplace, g_is)
kurt_val  = round(kurtosis(g_is), digits=2)

@info "  Normal MLE  : μ=$(round(d_normal.μ,  digits=4))  σ=$(round(d_normal.σ,  digits=4))"
@info "  Laplace MLE : μ=$(round(d_laplace.μ, digits=4))  b=$(round(d_laplace.θ, digits=4))"

# ── 3. Compute ACFs ──────────────────────────────────────────────────────────
lag_vec = collect(1:_L_ACF)
acf_raw = autocor(g_is,       lag_vec)
acf_abs = autocor(abs.(g_is), lag_vec)
ci_band = 1.96 / sqrt(length(g_is))   # 95% CI for white-noise test

# ── 4. Build panels ──────────────────────────────────────────────────────────
bg_col   = "gray95"
col_data = colorant"#e63946"   # red    — observed data
col_norm = colorant"#457b9d"   # steel  — Normal fit
col_lap  = colorant"#1d3557"   # navy   — Laplace fit
col_acf  = colorant"#e63946"   # red    — ACF bars (raw)
col_abs  = colorant"#1d3557"   # navy   — ACF bars (absolute)

# ── Panel (a): histogram + distribution fits ──────────────────────────────────
x_grid = range(-10, 10; length = 500)

pa = histogram(g_is;
               normalize    = :pdf,
               bins         = 80,
               fillalpha    = 0.4,
               c            = :gray,
               label        = "SPY data",
               bg           = bg_col,
               background_color_outside = "white",
               framestyle   = :box,
               fg_legend    = :transparent,
               legend       = :topleft,
               bottom_margin = 12Plots.mm,
               left_margin  = 12Plots.mm,
               xlims        = (-10, 10),
               xguidefontsize = 14,
               yguidefontsize = 14,
               titlefontsize  = 13)

plot!(pa, collect(x_grid), pdf.(d_normal,  collect(x_grid));
      lw = 2.5, c = col_norm, label = "Normal MLE")
plot!(pa, collect(x_grid), pdf.(d_laplace, collect(x_grid));
      lw = 2.5, c = col_lap,  label = "Laplace MLE")

xlabel!(pa, "Excess Growth Rate (year⁻¹)")
ylabel!(pa, "Density")
title!(pa,  "(a) Marginal Distribution")
annotate!(pa, 7.8, maximum(pdf.(d_laplace, collect(x_grid))) * 0.92,
          text("Excess kurtosis = $kurt_val", 10, :right))

# ── Panel (b): Normal Q-Q plot ────────────────────────────────────────────────
g_std = (g_is .- mean(g_is)) ./ std(g_is)

pb = qqplot(Normal(0, 1), g_std;
            bg           = bg_col,
            background_color_outside = "white",
            framestyle   = :box,
            fg_legend    = :transparent,
            legend       = false,
            bottom_margin = 12Plots.mm,
            left_margin  = 12Plots.mm,
            ms           = 3,
            mc           = col_data,
            markerstrokewidth = 0,
            xguidefontsize = 14,
            yguidefontsize = 14,
            titlefontsize  = 13)

xlabel!(pb, "Theoretical Normal Quantile")
ylabel!(pb, "Sample Quantile")
title!(pb,  "(b) Normal Q-Q Plot")

# ── Panel (c): ACF of raw excess growth rates ─────────────────────────────────
pc = plot(lag_vec, acf_raw;
          seriestype  = :sticks,
          c           = col_acf,
          lw          = 1.5,
          label       = "ACF",
         bg           = bg_col,
         background_color_outside = "white",
         framestyle   = :box,
         fg_legend    = :transparent,
         legend       = :topright,
         bottom_margin = 12Plots.mm,
         left_margin  = 12Plots.mm,
         xguidefontsize = 14,
         yguidefontsize = 14,
         titlefontsize  = 13)

hline!(pc, [ ci_band]; lw = 1.5, ls = :dash, c = :black, label = "95% CI")
hline!(pc, [-ci_band]; lw = 1.5, ls = :dash, c = :black, label = "")
xlabel!(pc, "Lag (trading days)")
ylabel!(pc, "ACF")
title!(pc,  "(c) ACF of Raw Excess Growth Rates")

# ── Panel (d): ACF of |excess growth rates| ───────────────────────────────────
pd = plot(lag_vec, acf_abs;
          seriestype  = :sticks,
          c           = col_abs,
          lw          = 1.5,
          label       = "ACF",
         bg           = bg_col,
         background_color_outside = "white",
         framestyle   = :box,
         fg_legend    = :transparent,
         legend       = :topright,
         bottom_margin = 12Plots.mm,
         left_margin  = 12Plots.mm,
         xguidefontsize = 14,
         yguidefontsize = 14,
         titlefontsize  = 13)

hline!(pd, [ ci_band]; lw = 1.5, ls = :dash, c = :black, label = "95% CI")
hline!(pd, [-ci_band]; lw = 1.5, ls = :dash, c = :black, label = "")
xlabel!(pd, "Lag (trading days)")
ylabel!(pd, "ACF of |Excess Growth Rate|")
title!(pd,  "(d) ACF of |Excess Growth Rates|")

# ── 5. Combine and save ───────────────────────────────────────────────────────
@info "Rendering Figure 1..."
fig1 = plot(pa, pb, pc, pd; layout = (2, 2), size = (1200, 900))

out_figs   = joinpath(_PATH_TO_FIGS, "Fig1-Empirical-Motivation.pdf")
paper_figs = joinpath(_ROOT, "..", "..", "paper", "sections", "figs",
                      "Fig1-Empirical-Motivation.pdf")
jfds_figs  = joinpath(_ROOT, "..", "..", "jfds-paper", "figs", "main",
                      "Fig01-Empirical-Motivation.pdf")

savefig(fig1, out_figs)
@info "Saved  Fig1 → $out_figs"

mkpath(dirname(paper_figs))
cp(out_figs, paper_figs; force = true)
@info "Copied Fig1 → $paper_figs"
mkpath(dirname(jfds_figs))
cp(out_figs, jfds_figs; force = true)
@info "Copied JFDS Fig01 → $jfds_figs"

@info "Done."
