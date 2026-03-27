# =============================================================================
# Fig-Price-Trajectories.jl
#
# Generates a 3-panel figure showing simulated price trajectories for a
# 4-asset portfolio under three dependence specifications:
#   (a) Independent marginals — each HMM simulated independently
#   (b) Single-Index Model — SPY from HMM, others via factor model
#   (c) Student-t copula — SAME values as (a), reordered by copula
#
# Panels (a) and (c) use the exact same set of simulated growth rate
# values for each asset. The ONLY difference is temporal order. This
# makes the copula's effect (synchronizing crashes) directly visible.
#
# Outputs:
#   figs/Fig-Price-Trajectories.pdf
#   paper/sections/figs/Fig-Price-Trajectories.pdf
# =============================================================================

include("Include.jl")
using JumpHMM: StudentTCopula, SingleIndexModel, PortfolioModel,
               sample_dependence

# ── constants ────────────────────────────────────────────────────────────────
const TICKERS = ["SPY", "NVDA", "JNJ", "JPM"]
const _RF_IS  = 0.043
const _DT     = 1.0 / 252.0
const _N      = 100
const _DF     = 5.0
const _P0     = 100.0
const _T_SIM  = 504     # 2 years

# ── 1. Load data and fit models ──────────────────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days = original_train["AAPL"] |> nrow
train_dataset = Dict(k => v for (k,v) in original_train if nrow(v) == max_days)

tickers_all = keys(train_dataset) |> collect |> sort
all_g = log_growth_matrix(train_dataset, tickers_all; Δt = _DT, risk_free_rate = _RF_IS)
ticker_idx = [findfirst(==(t), tickers_all) for t in TICKERS]
g_obs = all_g[1:(max_days - 1), ticker_idx]

price_matrix = hcat([train_dataset[t][!, :volume_weighted_average_price] for t in TICKERS]...)

# ── 2. Fit per-asset HMMs ────────────────────────────────────────────────────
@info "Fitting per-asset HMMs..."
models = Dict{String, JumpHiddenMarkovModel}()
for (j, ticker) in enumerate(TICKERS)
    @info "  Fitting $ticker..."
    m = JumpHMM.fit(JumpHiddenMarkovModel, price_matrix[:, j];
                    rf = _RF_IS, N = _N, ν = _DF, dt = _DT)
    m = tune(m, price_matrix[:, j];
             ϵ_range = range(1e-4, 2.5e-2, length = 20),
             λ_range = range(10.0, 160.0, length = 16),
             n_paths = 200, w_κ = 0.20, seed = 1234)
    models[ticker] = m
end

# ── 3. Fit Student-t copula to growth rates ──────────────────────────────────
@info "Fitting Student-t copula..."
copula = JumpHMM.fit(StudentTCopula, g_obs)
@info "  Copula ν = $(copula.ν)"

# ── 4. Fit SIM ───────────────────────────────────────────────────────────────
@info "Fitting SIM..."
sim_dep = JumpHMM.fit(SingleIndexModel, g_obs[:, 2:end], g_obs[:, 1];
                       market_prices = price_matrix[:, 1])
for (i, t) in enumerate(TICKERS[2:end])
    @info "  $t: α=$(round(sim_dep.α[i], digits=3)), β=$(round(sim_dep.β[i], digits=3))"
end

# ── 5. Growth rates → prices ────────────────────────────────────────────────
function growth_to_prices(G::Vector{Float64}; P0 = _P0, rf = _RF_IS, dt = _DT)
    P = Vector{Float64}(undef, length(G) + 1)
    P[1] = P0
    for t in eachindex(G)
        P[t + 1] = P[t] * exp((G[t] + rf) * dt)
    end
    return P
end

# ── 6. Find a seed with a visible jump in SPY ───────────────────────────────
@info "Searching for seed with jump event..."
best_seed = 42
for s in 42:500
    r = simulate(models["SPY"], _T_SIM; n_paths = 1, seed = s)
    if any(r.paths[1].jumps)
        global best_seed = s
        @info "  Using seed=$s ($(sum(r.paths[1].jumps)) jump steps in SPY)"
        break
    end
end

# ── 7. Simulate independent marginal values for each asset ──────────────────
@info "Simulating independent marginal paths..."
indep_G = Dict{String, Vector{Float64}}()
for (j, ticker) in enumerate(TICKERS)
    # Use different seeds per ticker so they are truly independent
    r = simulate(models[ticker], _T_SIM; n_paths = 1, seed = best_seed + j * 1000)
    indep_G[ticker] = r.paths[1].observations
end

# ── 8. Panel (a): Independent — use values as simulated ─────────────────────
indep_prices = Dict(t => growth_to_prices(indep_G[t]) for t in TICKERS)

# ── 9. Panel (c): Copula — reorder the SAME values using copula ranks ──────
@info "Applying copula reordering..."

# Sample correlated uniforms from the Student-t copula
copula_uniforms = sample_dependence(copula, _T_SIM)  # T_SIM x d matrix of uniforms

# For each asset, sort its independently simulated values to match copula ranks
copula_G = Dict{String, Vector{Float64}}()
for (j, ticker) in enumerate(TICKERS)
    vals = copy(indep_G[ticker])
    sorted_vals = sort(vals)                          # ascending values
    copula_ranks = ordinalrank(copula_uniforms[:, j]) # rank order from copula
    # Assign the k-th smallest value to the position where copula says rank=k
    reordered = Vector{Float64}(undef, _T_SIM)
    for t in 1:_T_SIM
        reordered[t] = sorted_vals[copula_ranks[t]]
    end
    copula_G[ticker] = reordered
end

copula_prices = Dict(t => growth_to_prices(copula_G[t]) for t in TICKERS)

# ── 10. Panel (b): SIM — SPY from HMM, others from factor model ────────────
@info "Simulating SIM paths..."
spy_G = indep_G["SPY"]  # use the same SPY path as panel (a)

sim_G = Dict{String, Vector{Float64}}()
sim_G["SPY"] = spy_G
for (i, ticker) in enumerate(TICKERS[2:end])
    # G_i = α + β * G_SPY + bootstrap residual
    resid = g_obs[:, i+1] .- sim_dep.α[i] .- sim_dep.β[i] .* g_obs[:, 1]
    η = resid[rand(1:length(resid), _T_SIM)]
    sim_G[ticker] = sim_dep.α[i] .+ sim_dep.β[i] .* spy_G .+ η
end

sim_prices = Dict(t => growth_to_prices(sim_G[t]) for t in TICKERS)

# ── 11. Plotting ─────────────────────────────────────────────────────────────
@info "Building figure..."

ticker_colors = Dict(
    "SPY"  => colorant"#1d3557",
    "NVDA" => colorant"#e63946",
    "JNJ"  => colorant"#2a9d8f",
    "JPM"  => colorant"#f4a261",
)

basestyle = (bg                       = "grey97",
             background_color_outside = "white",
             framestyle               = :box,
             fg_legend                = :transparent,
             xguidefontsize           = 11,
             yguidefontsize           = 11,
             titlefontsize            = 12,
             legendfontsize           = 9,
             bottom_margin            = 10Plots.mm,
             left_margin              = 12Plots.mm)

t_axis = collect(0:_T_SIM)

function make_panel(prices_dict, title_str; show_legend = false)
    p = plot(; basestyle...,
        xlabel = "Trading Days",
        ylabel = "Price (\$, normalized)",
        title = title_str,
        legend = show_legend ? :topleft : false)
    for ticker in TICKERS
        plot!(p, t_axis, prices_dict[ticker];
            lw = 2.0, c = ticker_colors[ticker], label = ticker)
    end
    return p
end

pa = make_panel(indep_prices,  "(a) Independent Marginals"; show_legend = true)
pb = make_panel(sim_prices,    "(b) Single-Index Model")
pc = make_panel(copula_prices, "(c) Student-t Copula")

# Match y-axis across panels
all_p = vcat([collect(values(d)) for d in [indep_prices, sim_prices, copula_prices]]...)
y_lo = 0.95 * minimum(minimum.(all_p))
y_hi = 1.05 * maximum(maximum.(all_p))
ylims!(pa, y_lo, y_hi); ylims!(pb, y_lo, y_hi); ylims!(pc, y_lo, y_hi)

fig = plot(pa, pb, pc; layout = (1, 3), size = (1800, 500), dpi = 150)

out_figs = joinpath(_PATH_TO_FIGS, "Fig-Price-Trajectories.pdf")
savefig(fig, out_figs)
@info "Saved → $out_figs"

paper_figs_dir = abspath(joinpath(_ROOT, "..", "..", "paper", "sections", "figs"))
mkpath(paper_figs_dir)
cp(out_figs, joinpath(paper_figs_dir, "Fig-Price-Trajectories.pdf"); force = true)
@info "Done."
