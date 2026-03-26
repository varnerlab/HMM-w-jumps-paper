# =============================================================================
# Vine-Analysis.jl
#
# Inspects the C-vine copula structure fitted to the 4-asset portfolio
# (SPY, NVDA, JNJ, JPM). For each edge in the vine tree, reports:
#   - Which bivariate family was selected (Gaussian, Student-t, Clayton,
#     Gumbel, Frank) via AIC
#   - Fitted parameters (ρ, θ, ν)
#   - Interpretation: tail dependence type per asset pair
#
# This reveals the asymmetric dependence structure in equity returns,
# e.g., whether crash co-movements (lower tail) differ from rally
# co-movements (upper tail).
# =============================================================================

include("Include.jl")
using JumpHMM: VineEdge, GaussianBiCopula, StudentTBiCopula,
               ClaytonBiCopula, GumbelBiCopula, FrankBiCopula

# ── constants ────────────────────────────────────────────────────────────────
const TICKERS = ["SPY", "NVDA", "JNJ", "JPM"]
const _RF_IS  = 0.043
const _DT     = 1.0 / 252.0

# ── 1. Load data and compute growth rates ────────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days = original_train["AAPL"] |> nrow
train_dataset = Dict(k => v for (k,v) in original_train if nrow(v) == max_days)

tickers_all = keys(train_dataset) |> collect |> sort
all_g = log_growth_matrix(train_dataset, tickers_all; Δt=_DT, risk_free_rate=_RF_IS)
idx = [findfirst(==(t), tickers_all) for t in TICKERS]
g_obs = all_g[1:(max_days-1), idx]
T_is = size(g_obs, 1)

@info "  $T_is observations, $(length(TICKERS)) tickers"

# ── 2. Fit vine copula directly to growth rates ─────────────────────────────
@info "Fitting VineCopula to growth rate matrix..."
vc = JumpHMM.fit(VineCopula, g_obs)

# ── 3. Report vine structure ─────────────────────────────────────────────────
println("\n" * "="^80)
println("  C-VINE COPULA STRUCTURE — $(join(TICKERS, ", "))")
println("="^80)

println("\n  Variable ordering (most connected first):")
println("    ", join([TICKERS[i] for i in vc.order], " → "))
println("    (Ordering based on sum of |Kendall's τ|)")

# Helper: describe copula family and its tail dependence
function describe_copula(cop)
    if isa(cop, GaussianBiCopula)
        return ("Gaussian", @sprintf("ρ = %.4f", cop.ρ), "none")
    elseif isa(cop, StudentTBiCopula)
        return ("Student-t", @sprintf("ρ = %.4f, ν = %.1f", cop.ρ, cop.ν), "symmetric (both tails)")
    elseif isa(cop, ClaytonBiCopula)
        return ("Clayton", @sprintf("θ = %.4f", cop.θ), "LOWER tail only")
    elseif isa(cop, GumbelBiCopula)
        return ("Gumbel", @sprintf("θ = %.4f", cop.θ), "UPPER tail only")
    elseif isa(cop, FrankBiCopula)
        return ("Frank", @sprintf("θ = %.4f", cop.θ), "none")
    else
        return ("Unknown", "", "unknown")
    end
end

# Print tree-by-tree
for k in 1:length(vc.edges)
    println("\n  ── Tree $k ──────────────────────────────────────────────────────")
    for (j, edge) in enumerate(vc.edges[k])
        var1_name = TICKERS[vc.order[edge.var1]]
        var2_name = TICKERS[vc.order[edge.var2]]

        cond_names = [TICKERS[vc.order[c]] for c in edge.conditioned]
        cond_str = isempty(cond_names) ? "" : " | " * join(cond_names, ", ")

        family, params, tail_dep = describe_copula(edge.copula)

        @printf("    Edge %d: %s — %s%s\n", j, var1_name, var2_name, cond_str)
        @printf("      Family:          %s\n", family)
        @printf("      Parameters:      %s\n", params)
        @printf("      Tail dependence: %s\n", tail_dep)
    end
end

# ── 4. Summary table ────────────────────────────────────────────────────────
println("\n" * "="^80)
println("  SUMMARY: Bivariate Family Selection")
println("="^80)
@printf("\n  %-6s  %-6s  %-12s  %-10s  %-20s  %-25s\n",
    "Var1", "Var2", "Conditioned", "Family", "Parameters", "Tail Dependence")
println("  " * "-"^85)

for k in 1:length(vc.edges)
    for edge in vc.edges[k]
        var1_name = TICKERS[vc.order[edge.var1]]
        var2_name = TICKERS[vc.order[edge.var2]]
        cond_names = [TICKERS[vc.order[c]] for c in edge.conditioned]
        cond_str = isempty(cond_names) ? "—" : join(cond_names, ",")
        family, params, tail_dep = describe_copula(edge.copula)
        @printf("  %-6s  %-6s  %-12s  %-10s  %-20s  %-25s\n",
            var1_name, var2_name, cond_str, family, params, tail_dep)
    end
end

# ── 5. Compute Kendall's τ for context ──────────────────────────────────────
println("\n  Empirical Kendall's τ matrix:")
n = length(TICKERS)
τ_mat = zeros(n, n)
for i in 1:n
    for j in 1:n
        if i == j
            τ_mat[i,j] = 1.0
        else
            τ_mat[i,j] = corkendall(g_obs[:, i], g_obs[:, j])
        end
    end
end

@printf("  %8s", "")
for t in TICKERS; @printf("  %8s", t); end
println()
for (i, t) in enumerate(TICKERS)
    @printf("  %8s", t)
    for j in 1:n
        @printf("  %8.3f", τ_mat[i, j])
    end
    println()
end

# Sum of |τ| per variable (explains ordering)
println("\n  Sum of |Kendall's τ| (determines vine ordering):")
for (i, t) in enumerate(TICKERS)
    s = sum(abs(τ_mat[i, j]) for j in 1:n if j != i)
    @printf("    %-6s: %.3f\n", t, s)
end

println("\n" * "="^80)
@info "Done."
