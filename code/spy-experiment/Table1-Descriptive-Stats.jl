# =============================================================================
# Table1-Descriptive-Stats.jl
#
# Computes descriptive statistics and stylized-facts tests for SPY daily excess
# growth rates (in-sample 2014–2024 and out-of-sample 2025).
# Output populates Table 1 in paper/sections/tables.tex.
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const _RF_IS  = 0.043
const _RF_OOS = 0.0421
const _DT     = 1.0 / 252.0
const _LB_LAG = 20

# ── 1. Load SPY excess growth rates ─────────────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train = original_train["AAPL"] |> nrow

train_dataset = Dict{String, DataFrame}()
for (ticker, df) ∈ original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end
tickers_train = keys(train_dataset) |> collect |> sort

all_growth_train = log_growth_matrix(train_dataset, tickers_train;
                       Δt = _DT, risk_free_rate = _RF_IS)
spy_idx_train = findfirst(x -> x == "SPY", tickers_train)
g_is = all_growth_train[1:(max_days_train - 1), spy_idx_train]

@info "Loading testing data..."
original_test = MyTestingMarketDataSet() |> x -> x["dataset"]
max_days_test = original_test["AAPL"] |> nrow

test_dataset = Dict{String, DataFrame}()
for (ticker, df) ∈ original_test
    nrow(df) == max_days_test && (test_dataset[ticker] = df)
end
tickers_test = keys(test_dataset) |> collect |> sort

all_growth_test = log_growth_matrix(test_dataset, tickers_test;
                      Δt = _DT, risk_free_rate = _RF_OOS)
spy_idx_test = findfirst(x -> x == "SPY", tickers_test)
g_oos = all_growth_test[1:(max_days_test - 1), spy_idx_test]

T_is  = length(g_is)
T_oos = length(g_oos)
@info "  IS observations  : $T_is"
@info "  OoS observations : $T_oos"

# ── 2. Compute descriptive statistics ────────────────────────────────────────
function descriptive_stats(g::Vector{Float64}, label::String)
    μ  = mean(g)
    σ  = std(g)
    sk = skewness(g)
    ek = kurtosis(g)

    # Jarque-Bera test
    jb      = JarqueBeraTest(g)
    jb_pval = pvalue(jb)

    # Ljung-Box on G_t (serial correlation)
    lb_g      = LjungBoxTest(g, _LB_LAG)
    lb_g_pval = pvalue(lb_g)

    # Ljung-Box on |G_t| (ARCH effect / volatility clustering)
    lb_abs      = LjungBoxTest(abs.(g), _LB_LAG)
    lb_abs_pval = pvalue(lb_abs)

    println("\n── $label (T=$( length(g))) ──")
    @printf("Mean (annualized, %%)       : %10.2f\n", μ * 100)
    @printf("Std Dev (annualized, %%)    : %10.2f\n", σ * 100)
    @printf("Skewness                    : %10.3f\n", sk)
    @printf("Excess Kurtosis             : %10.3f\n", ek)
    @printf("JB test p-value             : %10.4e  %s\n", jb_pval, jb_pval < 0.05 ? "reject*" : "fail to reject")
    @printf("LB on G_t (lag %d) p-value : %10.4e  %s\n", _LB_LAG, lb_g_pval, lb_g_pval < 0.05 ? "reject*" : "fail to reject")
    @printf("LB on |G_t| (lag %d) p-val : %10.4e  %s\n", _LB_LAG, lb_abs_pval, lb_abs_pval < 0.05 ? "reject*" : "fail to reject")

    return (μ=μ, σ=σ, sk=sk, ek=ek, jb_pval=jb_pval, lb_g_pval=lb_g_pval, lb_abs_pval=lb_abs_pval)
end

is_stats  = descriptive_stats(g_is,  "In-Sample (2014–2024)")
oos_stats = descriptive_stats(g_oos, "Out-of-Sample (2025)")

# ── 3. Reference distributions (fitted to IS data) ──────────────────────────
gauss_fit   = fit(Normal, g_is)
laplace_fit = fit(Laplace, g_is)

println("\n── Reference Distribution Parameters ──")
@printf("Gaussian:  μ = %.4f,  σ = %.4f\n", gauss_fit.μ, gauss_fit.σ)
@printf("Laplace:   μ = %.4f,  b = %.4f\n", laplace_fit.μ, laplace_fit.θ)
@printf("Laplace std = %.4f  (b√2)\n", laplace_fit.θ * sqrt(2))

# ── 4. Print LaTeX-ready output ──────────────────────────────────────────────
function fmt_pval(pval)
    if pval < 0.001
        return @sprintf("(p<0.001)")
    else
        return @sprintf("(p=%.3f)", pval)
    end
end

function test_result(pval)
    pval < 0.05 ? "reject\$^\\ast\$" : "fail to reject"
end

println("\n" * "="^80)
println("  LaTeX Table 1 rows")
println("="^80)
@printf("Mean (annualized, %%)       & %.2f & %.2f & %.2f & %.2f \\\\\n",
    is_stats.μ*100, oos_stats.μ*100, gauss_fit.μ*100, laplace_fit.μ*100)
@printf("Std Dev (annualized, %%)    & %.2f & %.2f & %.2f & %.2f \\\\\n",
    is_stats.σ*100, oos_stats.σ*100, gauss_fit.σ*100, laplace_fit.θ*sqrt(2)*100)
@printf("Skewness                    & %.3f & %.3f & 0 & 0 \\\\\n",
    is_stats.sk, oos_stats.sk)
@printf("Excess Kurtosis             & %.3f & %.3f & 0 & 3 \\\\\n",
    is_stats.ek, oos_stats.ek)
@printf("JB normality test           & %s %s & %s %s & --- & --- \\\\\n",
    test_result(is_stats.jb_pval), fmt_pval(is_stats.jb_pval),
    test_result(oos_stats.jb_pval), fmt_pval(oos_stats.jb_pval))
@printf("LB test on G_t (lag 20)     & %s %s & %s %s & --- & --- \\\\\n",
    test_result(is_stats.lb_g_pval), fmt_pval(is_stats.lb_g_pval),
    test_result(oos_stats.lb_g_pval), fmt_pval(oos_stats.lb_g_pval))
@printf("LB test on |G_t| (lag 20)   & %s %s & %s %s & --- & --- \\\\\n",
    test_result(is_stats.lb_abs_pval), fmt_pval(is_stats.lb_abs_pval),
    test_result(oos_stats.lb_abs_pval), fmt_pval(oos_stats.lb_abs_pval))

@info "Done. Copy the LaTeX rows above into paper/sections/tables.tex Table 1."
