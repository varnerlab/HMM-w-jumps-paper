# =============================================================================
# Table4-Multi-Asset-Stats.jl
#
# Loads pre-computed SIM multi-asset results (IS and OoS) and prints
# LaTeX-ready rows for Table 4 (cross-sectional summary statistics).
#
# Prerequisites:
#   data/SIM-Multi-Asset-Results.jld2      — in-sample (424 assets)
#   data/SIM-Multi-Asset-Results-OoS.jld2  — out-of-sample (217 assets)
#
# Usage:
#   cd code/sim-experiment && julia Table4-Multi-Asset-Stats.jl
# =============================================================================

const _PATH_TO_DATA = joinpath(@__DIR__, "data")

using JLD2
using FileIO
using Statistics
using Printf

# ── Helper: compute summary stats, filtering NaN ─────────────────────────────
function summary_stats(x::Vector{Float64})
    v = filter(!isnan, x)
    isempty(v) && return (mean=NaN, median=NaN, p5=NaN, p95=NaN, n=0)
    return (
        mean   = mean(v),
        median = median(v),
        p5     = quantile(v, 0.05),
        p95    = quantile(v, 0.95),
        n      = length(v),
    )
end

function latex_row_pct(label::String, x::Vector{Float64})
    s = summary_stats(x)
    return @sprintf("%s & %.1f & %.1f & %.1f & %.1f \\\\",
        label, s.mean, s.median, s.p5, s.p95)
end

function latex_row_f3(label::String, x::Vector{Float64})
    s = summary_stats(x)
    return @sprintf("%s & %.3f & %.3f & %.3f & %.3f \\\\",
        label, s.mean, s.median, s.p5, s.p95)
end

function latex_row_f4(label::String, x::Vector{Float64})
    s = summary_stats(x)
    return @sprintf("%s & %.4f & %.4f & %.4f & %.4f \\\\",
        label, s.mean, s.median, s.p5, s.p95)
end

# ── 1. Load IS results ──────────────────────────────────────────────────────
@info "Loading in-sample results..."
is_d = load(joinpath(_PATH_TO_DATA, "SIM-Multi-Asset-Results.jld2"))
is_tickers   = is_d["tickers"]
is_betas     = is_d["betas"]
is_alphas    = is_d["alphas"]
is_r2        = is_d["r_squared"]
is_ks        = is_d["ks_pass_rates"]
n_is = length(is_tickers)
@info "  IS assets: $n_is"

# ── 2. Load OoS results ─────────────────────────────────────────────────────
@info "Loading out-of-sample results..."
oos_d = load(joinpath(_PATH_TO_DATA, "SIM-Multi-Asset-Results-OoS.jld2"))
oos_tickers   = oos_d["tickers"]
oos_betas     = oos_d["betas"]
oos_alphas    = oos_d["alphas"]
oos_r2        = oos_d["r_squared"]
oos_ks        = oos_d["ks_pass_rates"]
n_oos = length(oos_tickers)
@info "  OoS assets: $n_oos"

# ── 3. Print summary ────────────────────────────────────────────────────────
println("\n" * "="^80)
println("TABLE 4 — Multi-Asset SIM Extension: Cross-Sectional Summary Statistics")
println("="^80)

println("\n--- In-sample ($n_is assets) ---")
for (label, data) in [("KS pass rate", is_ks .* 100),
                       ("R²", is_r2),
                       ("β", is_betas),
                       ("α", is_alphas)]
    s = summary_stats(data)
    @info @sprintf("  %-16s  Mean=%.4f  Median=%.4f  5th=%.4f  95th=%.4f  (n=%d)",
        label, s.mean, s.median, s.p5, s.p95, s.n)
end

println("\n--- Out-of-sample ($n_oos assets) ---")
for (label, data) in [("KS pass rate", oos_ks .* 100),
                       ("R²", oos_r2),
                       ("β", oos_betas),
                       ("α", oos_alphas)]
    s = summary_stats(data)
    @info @sprintf("  %-16s  Mean=%.4f  Median=%.4f  5th=%.4f  95th=%.4f  (n=%d)",
        label, s.mean, s.median, s.p5, s.p95, s.n)
end

# ── 4. Print LaTeX rows ─────────────────────────────────────────────────────
println("\n" * "="^80)
println("LaTeX rows for Table 4:")
println("="^80)

println("\n% In-sample rows:")
println(latex_row_pct("KS pass rate (\\%)", is_ks .* 100))
println(latex_row_f3("SIM \$R^2\$", is_r2))
println(latex_row_f3("\$\\hat{\\beta}\$ (factor loading)", is_betas))
println(latex_row_f4("\$\\hat{\\alpha}\$ (intercept)", is_alphas))

println("\n% Out-of-sample rows:")
println(latex_row_pct("KS pass rate (\\%)", oos_ks .* 100))
println(latex_row_f3("SIM \$R^2\$", oos_r2))
println(latex_row_f3("\$\\hat{\\beta}\$ (factor loading)", oos_betas))
println(latex_row_f4("\$\\hat{\\alpha}\$ (intercept)", oos_alphas))

println("\nDone.")
