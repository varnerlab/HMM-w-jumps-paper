# =============================================================================
# VaRBacktest.jl
# Per-ticker Value-at-Risk backtest utilities. Given a synthetic growth-rate
# path and a real growth-rate path, compute VaR at levels α ∈ {0.95, 0.99}
# from the synthetic sample, count how often the real path breaches that
# threshold, and report both the exceedance rate and the Kupiec unconditional
# coverage test p-value. Peer-review P2 (R3): VaR is the designated
# downstream-use validation — "does marginal fidelity translate to
# consequential VaR accuracy?"
#
# Convention: we track *left-tail* VaR on the 1-day log-return series,
# r(t) = g(t) · Δt, where g is the annualized growth rate and Δt = 1/252.
# A breach at level α occurs when r_real(t) < -VaR_α, with VaR_α estimated
# from the quantile q_{1-α}(r_synth).
# =============================================================================

"""
    one_day_returns(g, Δt) → r

Convert annualized growth rates to one-day log returns (consistent with the
paper's convention g(t) · Δt = log(P_t/P_{t-1})).
"""
one_day_returns(g::AbstractVector{<:Real}, Δt::Real) = g .* Δt

"""
    var_threshold(r_synth, α) → VaR_α

Historical-simulation VaR at level α from the synthetic one-day return
sample. Returns the negative lower-tail quantile; a breach occurs when
`r_real < -VaR_α`. Uses the (1 − α)-quantile of `r_synth`.
"""
function var_threshold(r_synth::AbstractVector{<:Real}, α::Real)
    @assert 0.5 < α < 1.0 "VaR level α must lie in (0.5, 1)"
    q = quantile(collect(r_synth), 1 - α)
    return -q   # VaR reported as positive magnitude
end

"""
    exceedance_rate(r_real, VaR) → (n_breach, rate)

Count breaches `r_real[t] < -VaR` and return both the raw count and the rate.
"""
function exceedance_rate(r_real::AbstractVector{<:Real}, VaR::Real)
    breach = r_real .< -VaR
    return sum(breach), mean(breach)
end

"""
    kupiec_pvalue(n_breach, T, α) → p

Kupiec unconditional coverage test. For `T > 0`, `0 ≤ n_breach ≤ T`, and
finite `0 < α < 1`, the expected breach probability is `1 − α`. The
likelihood-ratio statistic is:

    LR_uc = -2 log [ α^{T-n} (1-α)^n / ((1-n/T)^{T-n} (n/T)^n) ]

Use the continuous limit `0 log(0) = 0` at zero or all breaches. Returns
the upper-tail probability under the asymptotic χ²(1) reference distribution;
the test detects coverage deviations in either direction. This is not an
exact finite-sample test and does not test independence of breaches.
"""
function kupiec_pvalue(n_breach::Integer, T::Integer, α::Real)
    T > 0 || throw(ArgumentError("sample size T must be positive"))
    0 ≤ n_breach ≤ T || throw(ArgumentError("breach count must lie in [0, T]"))
    isfinite(α) && 0 < α < 1 ||
        throw(ArgumentError("coverage level α must be finite and lie in (0, 1)"))
    n = n_breach
    m = T - n
    ll_null = n * log1p(-α) + m * log(α)
    ll_alt = (n == 0 ? 0.0 : n * log(n / T)) +
             (m == 0 ? 0.0 : m * log(m / T))
    # Roundoff can make a zero likelihood ratio slightly negative.
    LR = max(0.0, 2 * (ll_alt - ll_null))
    return ccdf(Chisq(1), LR)
end

"""
    var_backtest(r_synth, r_real, α) → NamedTuple

Run the full VaR backtest for one (synthetic, real) pair at one coverage
level. Returns `(var = VaR_α, n_breach, rate, expected_rate, kupiec_p)`.
"""
function var_backtest(r_synth::AbstractVector{<:Real},
                      r_real::AbstractVector{<:Real},
                      α::Real)
    VaR = var_threshold(r_synth, α)
    n, rate = exceedance_rate(r_real, VaR)
    T = length(r_real)
    p = kupiec_pvalue(n, T, α)
    return (var = VaR, n_breach = n, rate = rate,
            expected_rate = 1 - α, kupiec_p = p)
end
