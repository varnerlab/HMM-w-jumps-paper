# =============================================================================
# 04b-VaR-Table.jl
#
# Emits the JFDS-paper VaR-backtest table (table5_var_backtest.tex) from
# data/var-backtest-summary.csv produced by scripts/06-VaR-Backtest.jl.
#
# The summary CSV holds per-(composer, α_level) aggregates:
#   composer, alpha_level, mean_rate, sd_rate, mean_kupiec_p, kupiec_pass_rate
#
# Inputs:
#   data/var-backtest-summary.csv
#
# Outputs:
#   <jfds-paper>/sections/tables/table5_var_backtest.tex
# =============================================================================

include(joinpath(@__DIR__, "..", "Include.jl"))

const _PAPER_ROOT     = abspath(joinpath(_ROOT, "..", "..", "jfds-paper"))
const _PATH_TO_TABLES = joinpath(_PAPER_ROOT, "sections", "tables")
isdir(_PATH_TO_TABLES) || mkpath(_PATH_TO_TABLES)

summary_csv = joinpath(_PATH_TO_DATA, "var-backtest-summary.csv")
isfile(summary_csv) || error("missing $summary_csv — run scripts/06-VaR-Backtest.jl first")

df = CSV.read(summary_csv, DataFrame)

const _COMPOSER_LABELS = [
    ("naive",            "Naive"),
    ("gaussian",         "Gaussian SIM"),
    ("hybrid",           "Hybrid"),
    ("residual_jumphmm", "JumpHMM-on-residuals"),
    ("block_bootstrap",  "Block bootstrap"),
    ("garch_t",          "GARCH(1,1)-\$t\$"),
]

function row_for(composer_key::AbstractString, label::AbstractString)
    r95 = first(df[(df.composer .== composer_key) .& (df.alpha_level .== 0.95), :])
    r99 = first(df[(df.composer .== composer_key) .& (df.alpha_level .== 0.99), :])
    @sprintf("%-22s & %.2f & %.2f & %.1f & %.2f & %.2f & %.1f \\\\\n",
        label,
        100r95.mean_rate, 100r95.sd_rate, 100r95.kupiec_pass_rate,
        100r99.mean_rate, 100r99.sd_rate, 100r99.kupiec_pass_rate)
end

io = IOBuffer()
println(io, "\\begin{tabular}{lrrrrrr}")
println(io, "\\toprule")
println(io, " & \\multicolumn{3}{c}{\$\\alpha = 0.95\$} & \\multicolumn{3}{c}{\$\\alpha = 0.99\$} \\\\")
println(io, "\\cmidrule(lr){2-4} \\cmidrule(lr){5-7}")
println(io, "Composer & rate (\\%) & SD (pp) & Kupiec pass (\\%) & rate (\\%) & SD (pp) & Kupiec pass (\\%) \\\\")
println(io, "\\midrule")
for (key, label) in _COMPOSER_LABELS
    print(io, row_for(key, label))
end
println(io, "\\bottomrule")
println(io, "\\end{tabular}")

out_path = joinpath(_PATH_TO_TABLES, "table5_var_backtest.tex")
open(out_path, "w") do f
    write(f, String(take!(io)))
end
@info "Wrote $out_path"
