# =============================================================================
# 10b-OoS-Table.jl
#
# Aggregate the frozen-fit 2025 evaluation, write manuscript-ready scorecard
# and VaR tables, and generate a cross-ticker holdout figure.
# =============================================================================

include(joinpath(@__DIR__, "..", "Include.jl"))

const _PAPER_ROOT = abspath(joinpath(_ROOT, "..", "..", "jfds-paper"))
const _TABLE_DIR  = joinpath(_PAPER_ROOT, "sections", "tables")
const _FIG_DIR    = joinpath(_PAPER_ROOT, "figs", "main")
mkpath(_TABLE_DIR)
mkpath(_FIG_DIR)

result_path = joinpath(_PATH_TO_DATA, "results-oos.jld2")
isfile(result_path) || error("missing $result_path — run 10-OoS-Evaluation.jl first")
r = load(result_path)["results"]

const COMPOSER_ORDER = ["naive", "gaussian", "hybrid",
                        "residual_jumphmm", "block_bootstrap", "garch_t"]
const COMPOSER_DISPLAY = Dict(
    "naive" => "Naive",
    "gaussian" => "Gaussian SIM",
    "hybrid" => "Hybrid",
    "residual_jumphmm" => "JumpHMM-on-residuals",
    "block_bootstrap" => "Block bootstrap",
    "garch_t" => "GARCH(1,1)-\$t\$",
)
const COMPOSER_SHORT = Dict(
    "naive" => "Naive", "gaussian" => "Gaussian", "hybrid" => "Hybrid",
    "residual_jumphmm" => "HMM-resid.", "block_bootstrap" => "Block",
    "garch_t" => "GARCH-t",
)

present = Set(unique(r.composer))
order = [c for c in COMPOSER_ORDER if c in present]

# Aggregate each ticker first so every asset receives equal weight even when
# composer path counts differ.
per_ticker = combine(groupby(r, [:composer, :ticker]),
    :ks_p_is_matched => (p -> 100mean(p .> 0.05)) => :ks_is_matched,
    :ks_p            => (p -> 100mean(p .> 0.05)) => :ks_oos,
    :ad_p_is_matched => (p -> 100mean(p .> 0.05)) => :ad_is_matched,
    :ad_p            => (p -> 100mean(p .> 0.05)) => :ad_oos,
    :w1              => median => :w1_oos,
    :var_ratio_oos   => median => :var_ratio_oos,
    :kurt_error_oos  => median => :kurt_error_oos,
)

summary = combine(groupby(per_ticker, :composer),
    :ticker         => length => :n_tickers,
    :ks_is_matched  => mean => :ks_is_matched,
    :ks_oos         => mean => :ks_oos,
    :ad_is_matched  => mean => :ad_is_matched,
    :ad_oos         => mean => :ad_oos,
    :w1_oos         => median => :w1_oos,
    :var_ratio_oos  => median => :var_ratio_oos,
    :kurt_error_oos => median => :kurt_error_oos,
)
summary = summary[[findfirst(==(c), summary.composer) for c in order], :]
CSV.write(joinpath(_PATH_TO_DATA, "results-oos-summary.csv"), summary)

fmt1(x) = @sprintf("%.1f", x)
fmt2(x) = @sprintf("%.2f", x)
fmt3(x) = @sprintf("%.3f", x)

scorecard_path = joinpath(_TABLE_DIR, "table6_oos_scorecard.tex")
open(scorecard_path, "w") do io
    println(io, "\\begin{tabular}{lrrrrrr}")
    println(io, "\\toprule")
    println(io, " & \\multicolumn{2}{c}{KS pass (\\%)} & \\multicolumn{2}{c}{AD pass (\\%)} & & \\\\")
    println(io, "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}")
    println(io, "Composer & matched IS & 2025 & matched IS & 2025 & \$W_1\$ (2025) & variance ratio \\\\")
    println(io, "\\midrule")
    for row in eachrow(summary)
        println(io, join([
            COMPOSER_DISPLAY[row.composer],
            fmt1(row.ks_is_matched), fmt1(row.ks_oos),
            fmt1(row.ad_is_matched), fmt1(row.ad_oos),
            fmt3(row.w1_oos), fmt2(row.var_ratio_oos),
        ], " & "), " \\\\")
    end
    println(io, "\\bottomrule")
    println(io, "\\end{tabular}")
end

# VaR: aggregate replications within ticker first, then summarize across
# tickers. This makes the reported SD genuinely cross-ticker.
var_long = vcat(
    select(r, :composer, :ticker, :rep,
           :var95_rate => :rate, :var95_kupiec_p => :kupiec_p,
           :var95_rate => ByRow(_ -> 0.95) => :alpha_level),
    select(r, :composer, :ticker, :rep,
           :var99_rate => :rate, :var99_kupiec_p => :kupiec_p,
           :var99_rate => ByRow(_ -> 0.99) => :alpha_level),
)
var_ticker = combine(groupby(var_long, [:composer, :alpha_level, :ticker]),
    :rate => mean => :rate,
    :kupiec_p => (p -> mean(p .> 0.05)) => :kupiec_pass,
)
var_summary = combine(groupby(var_ticker, [:composer, :alpha_level]),
    :rate => mean => :mean_rate,
    :rate => std => :sd_rate,
    :kupiec_pass => mean => :kupiec_pass_rate,
)
CSV.write(joinpath(_PATH_TO_DATA, "var-backtest-oos-summary.csv"), var_summary)

function var_row(composer)
    r95 = only(eachrow(var_summary[(var_summary.composer .== composer) .&
                                   (var_summary.alpha_level .== 0.95), :]))
    r99 = only(eachrow(var_summary[(var_summary.composer .== composer) .&
                                   (var_summary.alpha_level .== 0.99), :]))
    return [COMPOSER_DISPLAY[composer],
            fmt2(100r95.mean_rate), fmt2(100r95.sd_rate), fmt1(100r95.kupiec_pass_rate),
            fmt2(100r99.mean_rate), fmt2(100r99.sd_rate), fmt1(100r99.kupiec_pass_rate)]
end

var_table_path = joinpath(_TABLE_DIR, "table5_var_backtest_oos.tex")
open(var_table_path, "w") do io
    println(io, "\\begin{tabular}{lrrrrrr}")
    println(io, "\\toprule")
    println(io, " & \\multicolumn{3}{c}{\$\\alpha = 0.95\$} & \\multicolumn{3}{c}{\$\\alpha = 0.99\$} \\\\")
    println(io, "\\cmidrule(lr){2-4} \\cmidrule(lr){5-7}")
    println(io, "Composer & rate (\\%) & SD (pp) & Kupiec pass (\\%) & rate (\\%) & SD (pp) & Kupiec pass (\\%) \\\\")
    println(io, "\\midrule")
    for composer in order
        println(io, join(var_row(composer), " & "), " \\\\")
    end
    println(io, "\\bottomrule")
    println(io, "\\end{tabular}")
end

# Figure: cross-ticker OoS pass-rate distributions and the matched-length
# comparison for the proposed hybrid method.
plot_df = copy(per_ticker)
plot_df.method = [COMPOSER_SHORT[c] for c in plot_df.composer]

# Match the visual system established by Fig01-Empirical-Motivation:
# light-gray panels, boxed axes, sans-serif type, and the red/navy palette.
const FIG_BG   = colorant"#f2f2f2"
const FIG_RED  = colorant"#e63946"
const FIG_NAVY = colorant"#1d3557"

p1 = @df plot_df boxplot(:method, :ks_oos;
    legend=false, outliers=false, color=FIG_NAVY, fillalpha=0.62,
    linecolor=FIG_NAVY, linewidth=1.25,
    ylabel="2025 KS Pass Rate (%)", xlabel="", ylims=(0, 102),
    xrotation=25, title="(a) Cross-Ticker Holdout Distribution",
    bg=FIG_BG, background_color_outside=:white, framestyle=:box,
    fontfamily="sans-serif", titlefontsize=13, guidefontsize=14,
    tickfontsize=10, bottom_margin=12Plots.mm, left_margin=12Plots.mm)
hline!(p1, [95.0]; color=:black, linestyle=:dash, linewidth=1.5, label="")

hyb = filter(row -> row.composer == "hybrid", per_ticker)
p2 = scatter(hyb.ks_is_matched, hyb.ks_oos;
    markercolor=FIG_RED, markerstrokewidth=0, markersize=3.5,
    alpha=0.65, legend=false, xlims=(0, 102), ylims=(0, 102),
    xlabel="Matched-Length IS KS Pass Rate (%)",
    ylabel="2025 KS Pass Rate (%)",
    title="(b) Hybrid: Matched IS vs. Holdout",
    bg=FIG_BG, background_color_outside=:white, framestyle=:box,
    fontfamily="sans-serif", titlefontsize=13, guidefontsize=14,
    tickfontsize=10, bottom_margin=12Plots.mm, left_margin=12Plots.mm)
plot!(p2, [0, 100], [0, 100]; color=:black, linestyle=:dash, linewidth=1.5)

fig = plot(p1, p2; layout=(1, 2), size=(1200, 450),
           right_margin=3Plots.mm, top_margin=3Plots.mm)
fig_path = joinpath(_FIG_DIR, "Fig05-OoS-Composition.pdf")
savefig(fig, fig_path)

@info "OoS artifacts written" scorecard=scorecard_path var_table=var_table_path figure=fig_path
println("\nOoS scorecard:")
show(summary, allcols=true, allrows=true); println()
println("\nOoS VaR summary:")
show(var_summary, allcols=true, allrows=true); println()
