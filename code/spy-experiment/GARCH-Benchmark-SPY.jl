# =============================================================================
# GARCH-Benchmark-SPY.jl
#
# Fits a GARCH(1,1) model to SPY excess growth rates and produces the same
# statistical metrics as the HMM-NJ and HMM-WJ models.  Results populate
# Table 2 (model comparison) and the data needed for Figure 4 (head-to-head
# density / ACF / Q-Q comparison) in the paper.
#
# Outputs
#   data/GARCH-Benchmark-SPY.jld2  — metrics + simulated paths for all models
#   figs/Fig-GARCH-Comparison-*.pdf — Figure 4 panels (a), (b), (c)
# =============================================================================

include("Include.jl")

# ── constants ────────────────────────────────────────────────────────────────
const _RF_IS    = 0.043          # risk-free rate used in in-sample notebook
const _RF_OOS   = 0.0421         # risk-free rate used in OoS notebook
const _DT       = 1.0 / 252.0   # daily time step (years)
const _N_PATHS  = 1_000          # Monte Carlo paths (match HMM notebooks)
const _L_ACF    = 252            # max ACF lag (one trading year)
const _ALPHA    = 0.05           # significance level for KS / AD pass-rate
const _JLD2_HMM = joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2")
const _JLD2_OUT = joinpath(_PATH_TO_DATA, "GARCH-Benchmark-SPY.jld2")

# ── 1. Load SPY excess growth rates (mirror notebook pattern exactly) ─────────
@info "Loading training data..."
original_train = MyTrainingMarketDataSet() |> x -> x["dataset"]
max_days_train  = original_train["AAPL"] |> nrow          # full-history row count

train_dataset = Dict{String, DataFrame}()
for (ticker, df) ∈ original_train
    nrow(df) == max_days_train && (train_dataset[ticker] = df)
end
tickers_train = keys(train_dataset) |> collect |> sort

all_growth_train = log_growth_matrix(train_dataset, tickers_train;
                       Δt = _DT, risk_free_rate = _RF_IS)

spy_idx_train = findfirst(x -> x == "SPY", tickers_train)
Ri_train      = all_growth_train[:, spy_idx_train]          # full series
g_is          = Ri_train[1:(max_days_train - 1)]            # in-sample growth rates

@info "Loading testing data..."
original_test = MyTestingMarketDataSet() |> x -> x["dataset"]
max_days_test  = original_test["AAPL"] |> nrow

test_dataset = Dict{String, DataFrame}()
for (ticker, df) ∈ original_test
    nrow(df) == max_days_test && (test_dataset[ticker] = df)
end
tickers_test = keys(test_dataset) |> collect |> sort

all_growth_test = log_growth_matrix(test_dataset, tickers_test;
                      Δt = _DT, risk_free_rate = _RF_OOS)

spy_idx_test = findfirst(x -> x == "SPY", tickers_test)
Ri_test      = all_growth_test[:, spy_idx_test]
g_oos        = Ri_test[1:(max_days_test - 1)]               # OoS growth rates

@info "  IS observations  : $(length(g_is))"
@info "  OoS observations : $(length(g_oos))"
@info "  IS kurtosis      : $(round(kurtosis(g_is),  digits=3))"
@info "  OoS kurtosis     : $(round(kurtosis(g_oos), digits=3))"

# ── 2. Fit GARCH(1,1) ────────────────────────────────────────────────────────
@info "Fitting GARCH(1,1)..."
garch_fit = fit(GARCH{1, 1}, g_is)
display(garch_fit)

params = coef(garch_fit)               # [μ, ω, α, β] with Intercept mean model
ω = params[end-2]; α = params[end-1]; β = params[end]
@info "  ω=$(round(ω,sigdigits=4))  α=$(round(α,sigdigits=4))  β=$(round(β,sigdigits=4))  persistence=$(round(α+β,sigdigits=4))"

# ── 3. Metric helper ─────────────────────────────────────────────────────────
"""
    compute_metrics(obs, paths, α, L) -> NamedTuple

Given a vector of observed growth rates `obs` and an (T × N_paths) matrix of
simulated paths, compute KS pass rate, AD pass rate, kurtosis statistics, and
ACF-MAE at selected lags.
"""
function compute_metrics(obs::Vector{Float64},
                         paths::Matrix{Float64},
                         alpha::Float64 = _ALPHA,
                         L::Int = _L_ACF)

    n_paths   = size(paths, 2)
    L         = min(L, length(obs) - 1)   # cap at sample length
    lags      = collect(1:L)
    obs_acf   = autocor(abs.(obs), lags)
    obs_kurt  = kurtosis(obs)

    ks_pvals  = Vector{Float64}(undef, n_paths)
    ad_pvals  = Vector{Float64}(undef, n_paths)
    kurt_vals = Vector{Float64}(undef, n_paths)
    acf_mat   = Matrix{Float64}(undef, L, n_paths)

    Threads.@threads for i in 1:n_paths
        sim = paths[:, i]
        ks_pvals[i]    = pvalue(ApproximateTwoSampleKSTest(obs, sim))
        ad_pvals[i]    = pvalue(KSampleADTest(obs, sim))
        kurt_vals[i]   = kurtosis(sim)
        acf_mat[:, i]  = autocor(abs.(sim), lags)
    end

    mean_acf     = vec(mean(acf_mat, dims = 2))
    acf_mae_full = mean(abs.(obs_acf .- mean_acf))
    acf_mae_lags = abs.(obs_acf .- mean_acf)        # per-lag MAE vector

    return (
        ks_pass_rate  = mean(ks_pvals  .> alpha),
        ad_pass_rate  = mean(ad_pvals  .> alpha),
        ks_pvals      = ks_pvals,
        ad_pvals      = ad_pvals,
        kurt_obs      = obs_kurt,
        kurt_mean     = mean(kurt_vals),
        kurt_std      = std(kurt_vals),
        kurt_vals     = kurt_vals,
        acf_mae       = acf_mae_full,
        acf_mae_lag1  = L >= 1   ? acf_mae_lags[1]   : NaN,
        acf_mae_lag5  = L >= 5   ? acf_mae_lags[5]   : NaN,
        acf_mae_lag20 = L >= 20  ? acf_mae_lags[20]  : NaN,
        acf_mae_lag252= L >= 252 ? acf_mae_lags[252] : NaN,
        mean_acf      = mean_acf,
        obs_acf       = obs_acf,
        acf_mat       = acf_mat,
    )
end

# ── 4. Simulate GARCH paths ───────────────────────────────────────────────────
@info "Simulating $_N_PATHS in-sample GARCH(1,1) paths (length=$(length(g_is)))..."
garch_is_paths = Matrix{Float64}(undef, length(g_is), _N_PATHS)
for i in 1:_N_PATHS
    garch_is_paths[:, i] = simulate(garch_fit, length(g_is)).data
end

@info "Simulating $_N_PATHS out-of-sample GARCH(1,1) paths (length=$(length(g_oos)))..."
garch_oos_paths = Matrix{Float64}(undef, length(g_oos), _N_PATHS)
for i in 1:_N_PATHS
    garch_oos_paths[:, i] = simulate(garch_fit, length(g_oos)).data
end

# ── 5. Compute GARCH metrics ─────────────────────────────────────────────────
@info "Computing GARCH in-sample metrics..."
garch_is_metrics  = compute_metrics(g_is,  garch_is_paths)

@info "Computing GARCH out-of-sample metrics..."
garch_oos_metrics = compute_metrics(g_oos, garch_oos_paths)

# ── 6. Load HMM-NJ and HMM-WJ paths + metrics from saved JLD2 ────────────────
@info "Loading HMM results from $(_JLD2_HMM)..."
hmm_dict = load(_JLD2_HMM)

hmm_is_nj_paths  = hmm_dict["in_sample_decoded_archive"]           # T × 1000
hmm_is_wj_paths  = hmm_dict["in_sample_decoded_archive_with_jumps"] # T × 1000
insample_obs      = hmm_dict["insampledataset"]                     # observed IS series

# Trim paths to same length as observed (notebooks may store T+1 rows)
T_is = length(insample_obs)
hmm_is_nj_paths  = hmm_is_nj_paths[1:T_is, 1:min(_N_PATHS, end)]
hmm_is_wj_paths  = hmm_is_wj_paths[1:T_is, 1:min(_N_PATHS, end)]

@info "Computing HMM-NJ in-sample metrics..."
hmm_nj_is_metrics = compute_metrics(insample_obs, hmm_is_nj_paths)

@info "Computing HMM-WJ in-sample metrics..."
hmm_wj_is_metrics = compute_metrics(insample_obs, hmm_is_wj_paths)

# ── 7. Print comparison table ─────────────────────────────────────────────────
println("\n" * "="^72)
println("  Model Comparison — SPY Excess Growth Rate — In-Sample")
println("="^72)

header = ["Metric", "GARCH(1,1)", "HMM-NJ (N=90)", "HMM-WJ (N=90)"]
table_data = [
    "KS Pass Rate (%)"    100*garch_is_metrics.ks_pass_rate   100*hmm_nj_is_metrics.ks_pass_rate   100*hmm_wj_is_metrics.ks_pass_rate;
    "AD Pass Rate (%)"    100*garch_is_metrics.ad_pass_rate   100*hmm_nj_is_metrics.ad_pass_rate   100*hmm_wj_is_metrics.ad_pass_rate;
    "Kurt observed"       garch_is_metrics.kurt_obs           hmm_nj_is_metrics.kurt_obs           hmm_wj_is_metrics.kurt_obs;
    "Kurt sim (mean)"     garch_is_metrics.kurt_mean          hmm_nj_is_metrics.kurt_mean          hmm_wj_is_metrics.kurt_mean;
    "Kurt sim (std)"      garch_is_metrics.kurt_std           hmm_nj_is_metrics.kurt_std           hmm_wj_is_metrics.kurt_std;
    "ACF-MAE lag 1"       garch_is_metrics.acf_mae_lag1       hmm_nj_is_metrics.acf_mae_lag1       hmm_wj_is_metrics.acf_mae_lag1;
    "ACF-MAE lag 5"       garch_is_metrics.acf_mae_lag5       hmm_nj_is_metrics.acf_mae_lag5       hmm_wj_is_metrics.acf_mae_lag5;
    "ACF-MAE lag 20"      garch_is_metrics.acf_mae_lag20      hmm_nj_is_metrics.acf_mae_lag20      hmm_wj_is_metrics.acf_mae_lag20;
    "ACF-MAE lag 252"     garch_is_metrics.acf_mae_lag252     hmm_nj_is_metrics.acf_mae_lag252     hmm_wj_is_metrics.acf_mae_lag252;
    "ACF-MAE (1–252)"     garch_is_metrics.acf_mae            hmm_nj_is_metrics.acf_mae            hmm_wj_is_metrics.acf_mae;
]
pretty_table(table_data; column_labels = header)

println("\n" * "="^72)
println("  Model Comparison — SPY Excess Growth Rate — Out-of-Sample (GARCH)")
println("="^72)
oos_header = ["Metric", "GARCH(1,1) OoS"]
oos_data = [
    "KS Pass Rate (%)"    100*garch_oos_metrics.ks_pass_rate;
    "AD Pass Rate (%)"    100*garch_oos_metrics.ad_pass_rate;
    "Kurt observed"       garch_oos_metrics.kurt_obs;
    "Kurt sim (mean)"     garch_oos_metrics.kurt_mean;
    "Kurt sim (std)"      garch_oos_metrics.kurt_std;
    "ACF-MAE (1–252)"     garch_oos_metrics.acf_mae;
]
pretty_table(oos_data; column_labels = oos_header)

# ── 8. Generate Figure 4: head-to-head comparison ────────────────────────────
@info "Generating Figure 4..."

lag_vec = collect(1:_L_ACF)

# colour palette (consistent with notebook style)
col_obs   = colorant"#e63946"       # red    — observed
col_garch = colorant"#f4a261"       # orange — GARCH
col_nj    = colorant"#457b9d"       # steel  — HMM-NJ
col_wj    = colorant"#1d3557"       # navy   — HMM-WJ

# ── Panel (a): density overlay ────────────────────────────────────────────────
pa = plot(bg = "gray95", background_color_outside = "white",
          framestyle = :box, fg_legend = :transparent, legend = :topleft)

n_hmm_paths = size(hmm_is_wj_paths, 2)   # may be < _N_PATHS if JLD2 has fewer paths

# GARCH paths (faint)
for i in 1:_N_PATHS
    density!(pa, garch_is_paths[:, i]; lw = 0.3, c = col_garch, label = "")
end
# HMM-WJ paths (faint)
for i in 1:n_hmm_paths
    density!(pa, hmm_is_wj_paths[:, i]; lw = 0.3, c = col_wj, label = "")
end
# Mean lines + observed
density!(pa, vec(mean(garch_is_paths,  dims = 2)); lw = 2.5, c = col_garch, label = "GARCH(1,1)")
density!(pa, vec(mean(hmm_is_nj_paths, dims = 2)); lw = 2.5, c = col_nj,   label = "HMM-NJ (N=90)")
density!(pa, vec(mean(hmm_is_wj_paths, dims = 2)); lw = 2.5, c = col_wj,   label = "HMM-WJ (N=90)")
density!(pa, insample_obs;                          lw = 3.0, c = col_obs,  label = "SPY Observed", ls = :dash)
xlabel!(pa, "Excess Growth Rate (year⁻¹)")
ylabel!(pa, "Density")
title!(pa,  "(a) Marginal Distributions")

# ── Panel (b): ACF of |G_t| ───────────────────────────────────────────────────
ci_band = 1.96 / sqrt(length(insample_obs))   # 95% CI for white-noise ACF

pb = plot(bg = "gray95", background_color_outside = "white",
          framestyle = :box, fg_legend = :transparent, legend = :topright)

# Shaded confidence band for HMM-WJ ensemble
acf_lo = [quantile(garch_is_metrics.acf_mat[l, :], 0.10) for l in 1:_L_ACF]
acf_hi = [quantile(garch_is_metrics.acf_mat[l, :], 0.90) for l in 1:_L_ACF]
plot!(pb, lag_vec, acf_lo; fillrange = acf_hi, fillalpha = 0.15, lw = 0,
      c = col_garch, label = "")

acf_lo_wj = [quantile(hmm_wj_is_metrics.acf_mat[l, :], 0.10) for l in 1:_L_ACF]
acf_hi_wj = [quantile(hmm_wj_is_metrics.acf_mat[l, :], 0.90) for l in 1:_L_ACF]
plot!(pb, lag_vec, acf_lo_wj; fillrange = acf_hi_wj, fillalpha = 0.15, lw = 0,
      c = col_wj, label = "")

# Mean ACF lines
plot!(pb, lag_vec, garch_is_metrics.mean_acf;  lw = 2, c = col_garch, label = "GARCH(1,1)")
plot!(pb, lag_vec, hmm_nj_is_metrics.mean_acf; lw = 2, c = col_nj,   label = "HMM-NJ")
plot!(pb, lag_vec, hmm_wj_is_metrics.mean_acf; lw = 2, c = col_wj,   label = "HMM-WJ")
plot!(pb, lag_vec, garch_is_metrics.obs_acf;   lw = 3, c = col_obs,  label = "SPY Observed", ls = :dash)
hline!(pb, [ci_band, -ci_band]; lw = 1, ls = :dot, c = :black, label = "95% CI (white noise)")
xlabel!(pb, "Lag (trading days)")
ylabel!(pb, "ACF of |Excess Growth Rate|")
title!(pb,  "(b) Volatility Clustering (ARCH Effect)")

# ── Panel (c): Q-Q tails (empirical quantiles of simulated vs. observed) ──────
# Use the mean simulated distribution across all paths
garch_mean_sim = vec(mean(garch_is_paths,  dims = 2))
wj_mean_sim    = vec(mean(hmm_is_wj_paths, dims = 2))

tail_probs = [0.001, 0.005, 0.01, 0.025, 0.05, 0.95, 0.975, 0.99, 0.995, 0.999]
obs_q      = quantile(insample_obs,    tail_probs)
garch_q    = quantile(garch_mean_sim,  tail_probs)
nj_q       = quantile(vec(mean(hmm_is_nj_paths, dims=2)), tail_probs)
wj_q       = quantile(wj_mean_sim,     tail_probs)

pc = plot(bg = "gray95", background_color_outside = "white",
          framestyle = :box, fg_legend = :transparent, legend = :topleft)
plot!(pc, obs_q, garch_q; seriestype = :scatter, ms = 6, mc = col_garch,
      markerstrokewidth = 0, label = "GARCH(1,1)")
plot!(pc, obs_q, nj_q;    seriestype = :scatter, ms = 6, mc = col_nj,
      markerstrokewidth = 0, label = "HMM-NJ")
plot!(pc, obs_q, wj_q;    seriestype = :scatter, ms = 6, mc = col_wj,
      markerstrokewidth = 0, label = "HMM-WJ")
min_q, max_q = extrema(obs_q)
plot!(pc, [min_q, max_q], [min_q, max_q]; lw = 2, ls = :dash, c = col_obs, label = "45° line")
xlabel!(pc, "Observed Quantile (year⁻¹)")
ylabel!(pc, "Simulated Quantile (year⁻¹)")
title!(pc,  "(c) Tail Q-Q Plot")

# ── Save figure panels individually ───────────────────────────────────────────
savefig(pa, joinpath(_PATH_TO_FIGS, "Fig-GARCH-Comparison-a-Density.pdf"))
savefig(pb, joinpath(_PATH_TO_FIGS, "Fig-GARCH-Comparison-b-ACF.pdf"))
savefig(pc, joinpath(_PATH_TO_FIGS, "Fig-GARCH-Comparison-c-QQ.pdf"))

# Combined 3-panel layout
fig4 = plot(pa, pb, pc; layout = (1, 3), size = (1600, 480), margin = 5Plots.mm)
savefig(fig4, joinpath(_PATH_TO_FIGS, "Fig4-Model-Comparison.pdf"))
@info "Saved Figure 4 to figs/"

# ── 9. Save all results ───────────────────────────────────────────────────────
@info "Saving results to $(_JLD2_OUT)..."
save(_JLD2_OUT,
    "garch_fit",           garch_fit,
    "g_is",                g_is,
    "g_oos",               g_oos,
    "garch_is_paths",      garch_is_paths,
    "garch_oos_paths",     garch_oos_paths,
    "garch_is_metrics",    garch_is_metrics,
    "garch_oos_metrics",   garch_oos_metrics,
    "hmm_nj_is_metrics",   hmm_nj_is_metrics,
    "hmm_wj_is_metrics",   hmm_wj_is_metrics,
)

@info "Done.  Results written to $(basename(_JLD2_OUT))"
