# =============================================================================
# Fig-Price-Trajectories.jl
#
# Generates a 3-panel figure showing simulated price trajectories for a
# 4-asset portfolio under three dependence specifications:
#   (a) Independent marginals — each HMM simulated independently
#   (b) Single-Index Model — SPY from HMM, others via factor model
#   (c) Student-t copula — each HMM independent, then reordered by copula
#
# All tickers start at $100 (normalized). Prices reconstructed via
#   P_t = P_{t-1} * exp((G_t + r_f) * dt)
#
# Outputs:
#   figs/Fig-Price-Trajectories.pdf
#   paper/sections/figs/Fig-Price-Trajectories.pdf
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const TICKERS = ["SPY", "NVDA", "JNJ", "JPM"]
const _RF_IS  = 0.043
const _DT     = 1.0 / 252.0
const _N      = 100
const _DF     = 5.0
const _P0     = 100.0   # normalized starting price
const _T_SIM  = 504     # 2 years of trading days (easier to see structure)

# ── 1. Load data and fit models ──────────────────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days = original_train["AAPL"] |> nrow
train_dataset = Dict(k => v for (k,v) in original_train if nrow(v) == max_days)

# Extract prices and growth rates
tickers_all = keys(train_dataset) |> collect |> sort
all_g = log_growth_matrix(train_dataset, tickers_all; Δt = _DT, risk_free_rate = _RF_IS)
ticker_idx = [findfirst(==(t), tickers_all) for t in TICKERS]
g_obs = all_g[1:(max_days - 1), ticker_idx]

price_matrix = hcat([train_dataset[t][!, :volume_weighted_average_price] for t in TICKERS]...)

# ── 2. Fit per-asset HMM marginals and tune ──────────────────────────────────
@info "Fitting per-asset HMMs..."
marginal_models = Dict{String, JumpHiddenMarkovModel}()
for (j, ticker) in enumerate(TICKERS)
    @info "  Fitting $ticker..."
    m = JumpHMM.fit(JumpHiddenMarkovModel, price_matrix[:, j];
                    rf = _RF_IS, N = _N, ν = _DF, dt = _DT)
    m = tune(m, price_matrix[:, j];
             ϵ_range = range(1e-4, 2.5e-2, length = 20),
             λ_range = range(10.0, 160.0, length = 16),
             n_paths = 200, w_κ = 0.20, seed = 1234)
    marginal_models[ticker] = m
    @info "    ε=$(m.jump.ϵ), λ=$(m.jump.λ)"
end

# ── 3. Fit dependence models ─────────────────────────────────────────────────
@info "Fitting Student-t copula portfolio..."
portfolio_copula = JumpHMM.fit(PortfolioModel, TICKERS, price_matrix;
                               dependence = StudentTCopula,
                               market = "SPY", rf = _RF_IS, N = _N, ν = _DF)
portfolio_copula = tune(portfolio_copula, price_matrix)

@info "Fitting SIM portfolio..."
portfolio_sim = JumpHMM.fit(PortfolioModel, TICKERS, price_matrix;
                            dependence = SingleIndexModel,
                            market = "SPY", rf = _RF_IS, N = _N, ν = _DF)
portfolio_sim = tune(portfolio_sim, price_matrix)

# ── 4. Helper: growth rates → prices ────────────────────────────────────────
function growth_to_prices(G::Vector{Float64}; P0 = _P0, rf = _RF_IS, dt = _DT)
    T = length(G)
    P = Vector{Float64}(undef, T + 1)
    P[1] = P0
    for t in 1:T
        P[t + 1] = P[t] * exp((G[t] + rf) * dt)
    end
    return P
end

# ── 5. Find a seed with a jump event ─────────────────────────────────────────
@info "Searching for a seed with visible jump events..."
good_seed = 1234
for seed_candidate in 1234:1300
    test_result = simulate(marginal_models["SPY"], _T_SIM; n_paths = 1, seed = seed_candidate)
    if any(test_result.paths[1].jumps)
        global good_seed = seed_candidate
        n_jumps = sum(test_result.paths[1].jumps)
        @info "  Found seed=$good_seed with $n_jumps jump steps in SPY"
        break
    end
end

# ── 6. Simulate: (a) Independent marginals ──────────────────────────────────
@info "Simulating independent marginals (seed=$good_seed)..."
indep_prices = Dict{String, Vector{Float64}}()
for ticker in TICKERS
    result = simulate(marginal_models[ticker], _T_SIM; n_paths = 1, seed = good_seed)
    G = result.paths[1].observations
    indep_prices[ticker] = growth_to_prices(G)
end

# ── 7. Simulate: (b) SIM ────────────────────────────────────────────────────
@info "Simulating SIM portfolio (seed=$good_seed)..."
sim_result = simulate(portfolio_sim, _T_SIM; n_paths = 1, seed = good_seed)
sim_prices = Dict{String, Vector{Float64}}()
for ticker in TICKERS
    if haskey(sim_result.results, ticker)
        G = sim_result.results[ticker].paths[1].observations
        sim_prices[ticker] = growth_to_prices(G)
    end
end
# SIM excludes market ticker; simulate SPY separately
if !haskey(sim_prices, "SPY")
    spy_result = simulate(marginal_models["SPY"], _T_SIM; n_paths = 1, seed = good_seed)
    sim_prices["SPY"] = growth_to_prices(spy_result.paths[1].observations)
end

# ── 8. Simulate: (c) Student-t copula ───────────────────────────────────────
@info "Simulating Student-t copula portfolio (seed=$good_seed)..."
copula_result = simulate(portfolio_copula, _T_SIM; n_paths = 1, seed = good_seed)
copula_prices = Dict{String, Vector{Float64}}()
for ticker in TICKERS
    if haskey(copula_result.results, ticker)
        G = copula_result.results[ticker].paths[1].observations
        copula_prices[ticker] = growth_to_prices(G)
    end
end

# ── 9. Plotting ──────────────────────────────────────────────────────────────
@info "Building figure..."

ticker_colors = Dict(
    "SPY"  => colorant"#1d3557",
    "NVDA" => colorant"#e63946",
    "JNJ"  => colorant"#2a9d8f",
    "JPM"  => colorant"#f4a261",
)

ticker_styles = Dict(
    "SPY"  => :solid,
    "NVDA" => :solid,
    "JNJ"  => :solid,
    "JPM"  => :solid,
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

t_axis = collect(0:_T_SIM)  # trading days from start

function make_panel(prices_dict, title_str; show_legend = false)
    p = plot(; basestyle...,
        xlabel = "Trading Days",
        ylabel = "Price (\$, normalized)",
        title = title_str,
        legend = show_legend ? :topleft : false)

    for ticker in TICKERS
        if haskey(prices_dict, ticker)
            plot!(p, t_axis, prices_dict[ticker];
                lw = 2.0, c = ticker_colors[ticker],
                ls = ticker_styles[ticker],
                label = ticker)
        end
    end
    return p
end

pa = make_panel(indep_prices,  "(a) Independent Marginals"; show_legend = true)
pb = make_panel(sim_prices,    "(b) Single-Index Model")
pc = make_panel(copula_prices, "(c) Student-t Copula")

# Match y-axis limits across all panels
all_prices = vcat(
    [indep_prices[t] for t in TICKERS]...,
    [sim_prices[t] for t in TICKERS if haskey(sim_prices, t)]...,
    [copula_prices[t] for t in TICKERS if haskey(copula_prices, t)]...
)
y_lo = 0.95 * minimum(all_prices)
y_hi = 1.05 * maximum(all_prices)
ylims!(pa, y_lo, y_hi)
ylims!(pb, y_lo, y_hi)
ylims!(pc, y_lo, y_hi)

# ── 10. Combine and save ────────────────────────────────────────────────────
fig = plot(pa, pb, pc; layout = (1, 3), size = (1800, 500), dpi = 150)

out_figs = joinpath(_PATH_TO_FIGS, "Fig-Price-Trajectories.pdf")
savefig(fig, out_figs)
@info "Saved → $out_figs"

paper_figs_dir = abspath(joinpath(_ROOT, "..", "..", "paper", "sections", "figs"))
mkpath(paper_figs_dir)
paper_figs = joinpath(paper_figs_dir, "Fig-Price-Trajectories.pdf")
cp(out_figs, paper_figs; force = true)
@info "Copied → $paper_figs"
@info "Done."
