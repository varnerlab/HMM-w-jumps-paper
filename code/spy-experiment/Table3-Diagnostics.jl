# =============================================================================
# Table3-Diagnostics.jl
#
# Diagnostic script: for each N, report how many states have 0, 1, or few
# observations after encoding, how many transition matrix rows are zero,
# and how many decoder distributions use the global fallback.
# =============================================================================

include("Include.jl")

const _RF_IS = 0.043
const _DT    = 1.0 / 252.0

# ── Load SPY data ────────────────────────────────────────────────────────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train = original_train["AAPL"] |> nrow

train_dataset = Dict{String,DataFrame}()
for (ticker, df) ∈ original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end
tickers_train = keys(train_dataset) |> collect |> sort

all_growth_train = log_growth_matrix(train_dataset, tickers_train;
                       Δt = _DT, risk_free_rate = _RF_IS)

spy_idx = findfirst(x -> x == "SPY", tickers_train)
Rᵢ      = all_growth_train[:, spy_idx]
g_is    = Rᵢ[1:(max_days_train - 1)]
T_is    = length(g_is)

@info "  IS observations (g_is): $T_is"
@info "  Full series (Rᵢ):       $(length(Rᵢ))"

# ── Diagnostics for each N ───────────────────────────────────────────────────
N_values = [30, 60, 90, 100, 150, 200, 300, 500]

println("\n" * "="^90)
@printf("  %-6s  %6s  %8s  %8s  %8s  %8s  %8s  %8s\n",
    "N", "T/N", "0-obs", "1-obs", "≤5-obs", "0-trans", "fallback", "min-cnt")
println("="^90)

for N in N_values
    states = collect(1:N)

    # Laplace fit + quantile bins
    d = fit_mle(Laplace, Rᵢ)
    pct = range(0.0, 1.0, length = N + 1) |> collect
    bounds = Array{Float64,2}(undef, N, 2)
    for s in states
        bounds[s, 1] = quantile(d, pct[s])
        bounds[s, 2] = quantile(d, pct[s + 1])
    end

    # Encode g_is
    encoded = Vector{Int}(undef, T_is)
    for i in eachindex(g_is)
        v = g_is[i]
        encoded[i] = 1
        for s in states
            if bounds[s, 1] ≤ v < bounds[s, 2]
                encoded[i] = s
                break
            end
        end
    end

    # Count observations per state
    state_counts = zeros(Int, N)
    for s in encoded
        state_counts[s] += 1
    end

    n_zero  = count(==(0), state_counts)
    n_one   = count(==(1), state_counts)
    n_few   = count(x -> x ≤ 5, state_counts)
    min_cnt = minimum(state_counts)

    # Count transition matrix rows
    P = zeros(N, N)
    for i in 2:T_is
        P[encoded[i-1], encoded[i]] += 1.0
    end
    zero_rows = count(row -> sum(P[row, :]) == 0, 1:N)

    # Count decoder fallbacks (states with < 2 obs)
    fallbacks = count(s -> count(==(s), encoded) < 2, states)

    @printf("  %-6d  %6.1f  %8d  %8d  %8d  %8d  %8d  %8d\n",
        N, T_is / N, n_zero, n_one, n_few, zero_rows, fallbacks, min_cnt)

    # Show which specific states have 0 obs (for small lists)
    if n_zero > 0 && n_zero <= 20
        zero_states = findall(==(0), state_counts)
        println("         └─ zero-obs states: $zero_states")
    elseif n_zero > 20
        zero_states = findall(==(0), state_counts)
        println("         └─ zero-obs states (first 20): $(zero_states[1:20])...")
    end
end

println("="^90)

# ── Detailed histogram for N=100 and N=200 ──────────────────────────────────
for N in [100, 200]
    states = collect(1:N)
    d = fit_mle(Laplace, Rᵢ)
    pct = range(0.0, 1.0, length = N + 1) |> collect
    bounds = Array{Float64,2}(undef, N, 2)
    for s in states
        bounds[s, 1] = quantile(d, pct[s])
        bounds[s, 2] = quantile(d, pct[s + 1])
    end

    encoded = Vector{Int}(undef, T_is)
    for i in eachindex(g_is)
        v = g_is[i]
        encoded[i] = 1
        for s in states
            if bounds[s, 1] ≤ v < bounds[s, 2]
                encoded[i] = s
                break
            end
        end
    end

    state_counts = [count(==(s), encoded) for s in states]

    println("\n── N=$N: state occupancy histogram (bottom 10 and top 10 states) ──")
    println("  Bottom states (1–10):")
    for s in 1:10
        bar = repeat("█", min(state_counts[s], 50))
        @printf("    state %3d: %4d obs  %s\n", s, state_counts[s], bar)
    end
    println("  ...")
    println("  Top states ($(N-9)–$N):")
    for s in (N-9):N
        bar = repeat("█", min(state_counts[s], 50))
        @printf("    state %3d: %4d obs  %s\n", s, state_counts[s], bar)
    end
    println("  Summary: min=$(minimum(state_counts)), max=$(maximum(state_counts)), median=$(median(state_counts)), mean=$(round(mean(state_counts), digits=1))")
end

@info "Done."
