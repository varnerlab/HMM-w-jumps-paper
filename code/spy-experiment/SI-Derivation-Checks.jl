# =============================================================================
# SI-Derivation-Checks.jl
#
# Evaluates every closed-form quantity stated in the supplementary section
# "Derivation of the single-asset generator" at the fitted SPY model
# (N = 100, in-sample 2014-2024), and verifies the renewal-theory ACF
# prediction against simulation.
#
# Quantities computed:
#   1. State occupancy vs stationary distribution (fixed-point identity)
#   2. Second eigenvalue modulus of T and the implied HMM-NJ |G| ACF decay
#   3. Stationary mean / variance / excess kurtosis of the emission mixture
#      (Student-t nu=5 vs Gaussian), and the within-bin variance share
#   4. Sup-distance between the model stationary CDF and the empirical CDF,
#      compared with the two-sample KS critical value
#   5. Jump renewal arithmetic: forced-step fraction rho, episodes per path,
#      jump-path probability, forced-step moments
#   6. Predicted jump-path |G| ACF (episode-overlap formula) vs the mean
#      simulated jump-path ACF
#
# Input : data/HMM-WJ-SPY-N-100-daily-aggregate.jld2
# Output: printed values, plus the LaTeX table bodies
#         sections/tables/tableS_generator_quantities.tex,
#         sections/tables/tableS_acf_prediction.tex, and
#         sections/tables/tableS_kurt_composition.tex written to both
#         manuscript trees (arxiv-paper first, then jfds-paper).
# =============================================================================

include("Include.jl")

# ── 1. Load fitted model and in-sample growth rates ──────────────────────────
d     = load(joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2"))
g     = d["insampledataset"]
model = d["model_wj"]
N     = d["number_of_states"]

Tm    = model.transition
pibar = model.stationary
em    = model.emissions
eps_j = model.jump.ϵ
lam   = model.jump.λ
pneg  = model.jump.p_neg
Ntail = model.jump.N_tail
nu    = model.ν
Tn    = length(g)
@info "Fitted model: eps=$eps_j lambda=$lam p_neg=$pneg N_tail=$Ntail nu=$nu T=$Tn"

muk  = [e.μ for e in em]
sigk = [e.σ for e in em]
vf   = nu / (nu - 2)                       # E[X^2] for standard t_nu
EX4  = 3 * nu^2 / ((nu - 2) * (nu - 4))    # E[X^4] for standard t_nu

# ── 2. Occupancy vs stationary distribution ──────────────────────────────────
states = JumpHMM.assign_states(model.partition, g)
counts = [count(==(k), states) for k in 1:N]
pihat  = counts ./ Tn
@info "Bin counts: min=$(minimum(counts)) max=$(maximum(counts)); fallbacks=$(count(e -> e.is_fallback, em))"
@info "max_k |pibar - pihat| = $(maximum(abs.(pibar .- pihat)))"

# ── 3. Spectral gap of T ─────────────────────────────────────────────────────
mods = sort(abs.(eigvals(Tm)), rev = true)
lam2 = mods[2]
@info "Second eigenvalue modulus |lambda_2| = $(round(lam2, digits=4))"
@info "Smallest lag with lam2^tau < 0.01  : $(ceil(Int, log(0.01) / log(lam2)))"

# ── 4. Stationary moments of the emission mixture ────────────────────────────
m1   = sum(pibar .* muk)
m2_t = sum(pibar .* (muk .^ 2 .+ vf .* sigk .^ 2)) - m1^2
m2_g = sum(pibar .* (muk .^ 2 .+ sigk .^ 2)) - m1^2
@info "Mean    : model=$(round(m1, digits=4))  sample=$(round(mean(g), digits=4))"
@info "Variance: t(nu=5)=$(round(m2_t, digits=3))  Gaussian=$(round(m2_g, digits=3))  sample=$(round(var(g), digits=3))"

Vw = sum(pibar .* sigk .^ 2)                 # appendix definition (stationary weights)
within_emp = sum(pihat[k] * var(g[states .== k]) for k in 1:N if counts[k] >= 2)
@info "V_w (pibar-weighted) = $(round(Vw, digits=4)); empirical within = $(round(within_emp, digits=4)) (share $(round(within_emp / var(g), digits=4)))"

delta = muk .- m1
mu4_t = sum(pibar .* (delta .^ 4 .+ 6 .* delta .^ 2 .* sigk .^ 2 .* vf .+ sigk .^ 4 .* EX4))
mu4_g = sum(pibar .* (delta .^ 4 .+ 6 .* delta .^ 2 .* sigk .^ 2 .+ 3 .* sigk .^ 4))
@info "Excess kurtosis: t(nu=5)=$(round(mu4_t / m2_t^2 - 3, digits=2))  Gaussian=$(round(mu4_g / m2_g^2 - 3, digits=2))  sample=$(round(kurtosis(g), digits=2))"

# ── 5. Model stationary CDF vs empirical CDF (sup distance) ──────────────────
tdist = TDist(nu)
Fmodel(x) = sum(pibar[k] * cdf(tdist, (x - muk[k]) / sigk[k]) for k in 1:N)
gs = sort(g)
Fm = [Fmodel(x) for x in gs]
Femp_hi = collect(1:Tn) ./ Tn          # ECDF just above each data point
Femp_lo = collect(0:(Tn - 1)) ./ Tn    # ECDF just below each data point
Delta = max(maximum(abs.(Fm .- Femp_hi)), maximum(abs.(Fm .- Femp_lo)))
ks_crit = 1.358 * sqrt(2 / Tn)         # two-sample KS critical value, alpha=0.05, m=n
@info "sup |F_model - F_emp| = $(round(Delta, digits=4)) vs two-sample KS critical value $(round(ks_crit, digits=4))"

# ── 6. Jump renewal arithmetic ───────────────────────────────────────────────
p_eff = eps_j * (1 - exp(-lam))              # episode-start prob per free step
EL    = lam / (1 - exp(-lam))                # mean episode length given K >= 1
rho   = EL / ((1 - p_eff) / p_eff + EL)      # long-run forced-step fraction
@info "rho = $(round(rho, digits=5)) (approx eps*lam/(1+eps*lam) = $(round(eps_j * lam / (1 + eps_j * lam), digits=5)))"
cycle = (1 - p_eff) / p_eff + EL             # expected renewal cycle length (steps)
n_ep  = (Tn - 1) / cycle                     # expected episodes per path
p_jump = 1 - (1 - p_eff)^(Tn - 1)            # exact: no episode iff all T-1 trials fail
@info "Expected episodes/path = $(round(n_ep, digits=3)); P(>=1 episode) = $(round(p_jump, digits=4))"
@info "Per-jump-path forced fraction lambda/T = $(round(lam / Tn, digits=4))"

q = zeros(N)
q[1:Ntail]           .= pneg / Ntail
q[(N - Ntail + 1):N] .= (1 - pneg) / Ntail
muJ  = sum(q .* muk)
EG2J = sum(q .* (muk .^ 2 .+ vf .* sigk .^ 2))
@info "Forced-step sd = $(round(sqrt(EG2J - muJ^2), digits=3)) vs free-step sd = $(round(sqrt(m2_t), digits=3))"

# per-jump-path population excess kurtosis (two-regime mixture, single episode)
rho_p  = lam / Tn
mcomb  = (1 - rho_p) * m1 + rho_p * muJ
EG2free = sum(pibar .* (muk .^ 2 .+ vf .* sigk .^ 2))
dfree = muk .- mcomb
mu4f  = sum(pibar .* (dfree .^ 4 .+ 6 .* dfree .^ 2 .* sigk .^ 2 .* vf .+ sigk .^ 4 .* EX4))
mu4J  = sum(q .* (dfree .^ 4 .+ 6 .* dfree .^ 2 .* sigk .^ 2 .* vf .+ sigk .^ 4 .* EX4))
vcomb = (1 - rho_p) * (EG2free - 2 * mcomb * m1 + mcomb^2) +
        rho_p * (EG2J - 2 * mcomb * muJ + mcomb^2)
kap_wj = ((1 - rho_p) * mu4f + rho_p * mu4J) / vcomb^2 - 3
@info "Population excess kurtosis: jump path = $(round(kap_wj, digits=2)) vs no-jump = $(round(mu4_t / m2_t^2 - 3, digits=2))"

# ── 7. Predicted vs simulated jump-path |G| ACF ──────────────────────────────
Random.seed!(2024)
x  = rand(TDist(nu), 2_000_000)              # common random numbers for E|G| per state
a  = [mean(abs.(muk[k] .+ sigk[k] .* x)) for k in 1:N]
a0 = sum(pibar .* a)
aJ = sum(q .* a)

# No-jump |G| ACF, Eq. (supp-acf-nj): (sum_jk pibar_j (T^tau)_jk a_j a_k - abar^2) / Var|G|
varAbs_nj = EG2free - a0^2
acf_nj(tau) = (let Tt = Tm^tau; sum(pibar[j] * Tt[j, k] * a[j] * a[k] for j in 1:N, k in 1:N) end - a0^2) / varAbs_nj
obs_acf = autocor(abs.(g), collect(1:25))
acf_lags = [1, 2, 3, 4, 5, 10, 25]
acf_nj_vals = Dict(tau => acf_nj(tau) for tau in acf_lags)
println("tau   no-jump model |G| ACF   observed |G| ACF")
for tau in acf_lags
    println("  $tau   $(round(acf_nj_vals[tau], digits=3))   $(round(obs_acf[tau], digits=3))")
end

EA      = (1 - rho_p) * a0 + rho_p * aJ
EA2     = (1 - rho_p) * (sum(pibar .* (muk .^ 2 .+ vf .* sigk .^ 2))) + rho_p * EG2J
varA    = EA2 - EA^2
plateau = rho_p * (aJ - a0)^2 / varA
@info "E|G|: forced=$(round(aJ, digits=3)) free=$(round(a0, digits=3)); predicted plateau=$(round(plateau, digits=4))"

P  = Poisson(lam)
h(tau) = sum((l - tau) * pdf(P, l) for l in (tau + 1):round(Int, lam + 10 * sqrt(lam))) /
         (1 - exp(-lam)) / EL                # same-episode survival E[(L-tau)_+]/E[L]

Random.seed!(1234)
res        = simulate(model, Tn; n_paths = 400)
jump_paths = [p for p in res.paths if any(p.jumps)]
@info "Jump paths: $(length(jump_paths))/400; mean forced fraction = $(round(mean([mean(p.jumps) for p in jump_paths]), digits=4))"
@info "Unconditional forced fraction = $(round(mean([mean(p.jumps) for p in res.paths]), digits=5))"

acfs     = [autocor(abs.(p.observations), collect(1:25)) for p in jump_paths]
mean_acf = reduce(+, acfs) ./ length(acfs)
println("tau   h(tau)   predicted   simulated")
acf_pred_lags = [1, 2, 3, 5, 10, 15, 20, 25]
acf_pred_rows = [(tau, h(tau), plateau * h(tau), mean_acf[tau]) for tau in acf_pred_lags]
for (tau, hv, pv, sv) in acf_pred_rows
    println("  $tau   $(round(hv, digits=3))   $(round(pv, digits=3))   $(round(sv, digits=3))")
end
jump_forced_frac   = mean([mean(p.jumps) for p in jump_paths])
uncond_forced_frac = mean([mean(p.jumps) for p in res.paths])
n_jump_paths       = length(jump_paths)

# ── 8. Kurtosis composition under independent centered sums ──────────────────
# Verifies kappa(X + Y) = rho^2 * kappa(X) + (1 - rho)^2 * kappa(Y) for
# independent centered X, Y with variance shares rho and 1 - rho, using
# independent generator draws for both components (SIM residual-choice
# derivation in the supplement).
Random.seed!(777)
resA = simulate(model, Tn; n_paths = 200)   # stands in for the asset draw
resB = simulate(model, Tn; n_paths = 200)   # stands in for the market path
kurt_comp_rows = NTuple{3, Float64}[]
for rho_test in [0.1, 0.3, 0.5]
    kap_pred = Float64[]; kap_meas = Float64[]
    for p in 1:200
        x = resB.paths[p].observations; x = (x .- mean(x)) ./ std(x)
        y = resA.paths[p].observations; y = (y .- mean(y)) ./ std(y)
        z = sqrt(rho_test) .* x .+ sqrt(1 - rho_test) .* y
        push!(kap_pred, rho_test^2 * kurtosis(x) + (1 - rho_test)^2 * kurtosis(y))
        push!(kap_meas, kurtosis(z))
    end
    @info "rho=$(rho_test): mean predicted kappa = $(round(mean(kap_pred), digits=3)) vs measured = $(round(mean(kap_meas), digits=3))"
    push!(kurt_comp_rows, (rho_test, mean(kap_pred), mean(kap_meas)))
end

# ── 9. Stationary-mixture skewness against the observed value ────────────────
# Backs the supplement's claim that the occupancy-weighted mixture carries the
# observed asymmetry without an explicit skewness parameter. HMM-NJ is the
# fitted model with the jump probability set to zero.
model_nj = JumpHMM.fit(JumpHiddenMarkovModel,
                       MyTrainingMarketDataSet()["dataset"]["SPY"][!, :volume_weighted_average_price];
                       rf = 0.043, N = N, ν = nu, dt = 1.0 / 252.0)
println("observed in-sample skewness = ", round(skewness(g), digits = 4))
sim_skew = Dict{String, Float64}()
for (name, m) in (("HMM-NJ", model_nj), ("HMM-WJ", model))
    r  = simulate(m, Tn; n_paths = 1_000, seed = 1234)
    sk = [skewness(p.observations) for p in r.paths]
    sim_skew[name] = mean(sk)
    @info "$name mean simulated skewness = $(round(mean(sk), digits = 4)) (SE $(round(std(sk)/sqrt(1_000), digits = 4)))"
end

# ── 10. Write the SI table bodies (anchors for every number quoted in S4) ────
using Printf
f2(x)  = @sprintf("%.2f", x)
f3(x)  = @sprintf("%.3f", x)
f4(x)  = @sprintf("%.4f", x)
facf(x) = abs(x) < 0.0005 ? "<\\!0.001" : f3(x)   # tiny ACF values print as a bound
fT(n)  = n >= 1000 ? string(n ÷ 1000, "{,}", lpad(n % 1000, 3, "0")) : string(n)
kurt_t = mu4_t / m2_t^2 - 3
kurt_g = mu4_g / m2_g^2 - 3
lag01  = ceil(Int, log(0.01) / log(lam2))
var_infl = vcomb / m2_t - 1
@info "Var(A_t) single-episode = $(round(varA, digits=3)); variance inflation from forced steps = $(round(100 * var_infl, digits=1))%"

quant = String[]
push!(quant, raw"% Generated by code/spy-experiment/SI-Derivation-Checks.jl; do not edit numbers manually.")
push!(quant, raw"\begin{tabular}{@{}lcc@{}}")
push!(quant, raw"\toprule")
push!(quant, raw"\textbf{Quantity} & \textbf{Closed form at the fit} & \textbf{Sample or simulation} \\ \midrule")
push!(quant, raw"\multicolumn{3}{@{}l}{\textit{Stationary law and moments}} \\[2pt]")
push!(quant, "State occupancy count, smallest and largest (of \$T = $(fT(Tn))\$) & -- & \$$(minimum(counts))\$, \$$(maximum(counts))\$ \\\\")
push!(quant, "Occupancy frequency \$\\hat\\pi_k\$, smallest and largest & -- & \$$(f4(minimum(pihat)))\$, \$$(f3(maximum(pihat)))\$ \\\\")
push!(quant, "\$\\max_k |\\bar\\pi_k - \\hat\\pi_k|\$ & \$$(@sprintf("%.1f", maximum(abs.(pibar .- pihat)) * 1e4)) \\times 10^{-4}\$ & -- \\\\")
push!(quant, "Mean (\$\\mathrm{yr}^{-1}\$) & \$$(f4(m1))\$ & \$$(f4(mean(g)))\$ \\\\")
push!(quant, "\$\\sup_x |F_{\\rm mix}(x) - \\widehat F_T(x)|\$ & \$$(f4(Delta))\$ & -- \\\\")
push!(quant, "Within-state variance \$V_{\\rm w}\$ (\$\\mathrm{yr}^{-2}\$), share of sample variance & \$$(f2(Vw))\$, \$$(@sprintf("%.1f", 100 * Vw / var(g)))\\%\$ & -- \\\\")
push!(quant, "Variance (\$\\mathrm{yr}^{-2}\$), Student-\$t\$ emissions & \$$(f2(m2_t))\$ & \$$(f2(var(g)))\$ \\\\")
push!(quant, "Variance (\$\\mathrm{yr}^{-2}\$), Gaussian emissions & \$$(f2(m2_g))\$ & \$$(f2(var(g)))\$ \\\\")
push!(quant, "Standard deviation (\$\\mathrm{yr}^{-1}\$), Student-\$t\$ emissions & \$$(f2(sqrt(m2_t)))\$ & \$$(f2(std(g)))\$ \\\\")
push!(quant, "Excess kurtosis, Student-\$t\$ emissions & \$$(f2(kurt_t))\$ & \$$(f2(kurtosis(g)))\$ \\\\")
push!(quant, "Excess kurtosis, Gaussian emissions & \$$(f2(kurt_g))\$ & \$$(f2(kurtosis(g)))\$ \\\\")
push!(quant, "Skewness, HMM-NJ (\$1{,}000\$ simulated paths) & -- & \$$(f2(sim_skew["HMM-NJ"]))\$ \\\\")
push!(quant, "Skewness, HMM-WJ (\$1{,}000\$ simulated paths) & -- & \$$(f2(sim_skew["HMM-WJ"]))\$ \\\\[4pt]")
push!(quant, raw"\multicolumn{3}{@{}l}{\textit{Dependence without jumps}} \\[2pt]")
push!(quant, "\$|\\theta_2|\$, smallest lag with \$|\\theta_2|^\\tau < 0.01\$ & \$$(f3(lam2))\$, lag \$$(lag01)\$ & -- \\\\")
push!(quant, "ACF of \$|G_t|\$ at lag \$1\$, no jumps & \$$(f2(acf_nj_vals[1]))\$ & \$$(f2(obs_acf[1]))\$ (observed) \\\\")
push!(quant, "ACF of \$|G_t|\$ at lag \$3\$, no jumps & \$$(f3(acf_nj_vals[3]))\$ & \$$(f2(obs_acf[3]))\$ (observed) \\\\")
push!(quant, "ACF of \$|G_t|\$ at lag \$5\$, no jumps & \$$(facf(acf_nj_vals[5]))\$ & \$$(f2(obs_acf[5]))\$ (observed) \\\\")
push!(quant, "ACF of \$|G_t|\$ at lag \$25\$, no jumps & \$$(facf(acf_nj_vals[25]))\$ & \$$(f2(obs_acf[25]))\$ (observed) \\\\[4pt]")
push!(quant, raw"\multicolumn{3}{@{}l}{\textit{Jump-episode arithmetic}} \\[2pt]")
push!(quant, "Forced-step fraction \$\\pi_J\$ & \$$(f4(rho))\$ & \$$(f4(uncond_forced_frac))\$ (\$400\$ paths) \\\\")
push!(quant, "Jump-path probability & \$$(@sprintf("%.1f", 100 * p_jump))\\%\$ & \$$(@sprintf("%.1f", 100 * n_jump_paths / 400))\\%\$ (\$$(n_jump_paths)\$ of \$400\$) \\\\")
push!(quant, "Forced fraction within a jump path & \$$(@sprintf("%.1f", 100 * lam / Tn))\\%\$ (\$\\lambda / T\$) & \$$(@sprintf("%.1f", 100 * jump_forced_frac))\\%\$ \\\\")
push!(quant, "Forced-step standard deviation (\$\\mathrm{yr}^{-1}\$) & \$$(f2(sqrt(EG2J - muJ^2)))\$ & -- \\\\")
push!(quant, "Mean absolute return, forced \$\\bar a_J\$ and free \$\\bar a\$ (\$\\mathrm{yr}^{-1}\$) & \$$(f2(aJ))\$, \$$(f2(a0))\$ & -- \\\\")
push!(quant, "\$\\Var(A_t)\$, single-episode conditioning & \$$(f2(varA))\$ & -- \\\\")
push!(quant, "Predicted jump-path ACF plateau & \$$(f2(plateau))\$ & -- \\\\")
push!(quant, "Excess kurtosis, single-episode jump path & \$$(f2(kap_wj))\$ & -- \\\\")
push!(quant, "Variance inflation from forced steps, single-episode jump path & \$$(@sprintf("%.0f", 100 * var_infl))\\%\$ & -- \\\\")
push!(quant, raw"\bottomrule")
push!(quant, raw"\end{tabular}")

acft = String[]
push!(acft, raw"% Generated by code/spy-experiment/SI-Derivation-Checks.jl; do not edit numbers manually.")
push!(acft, raw"\begin{tabular}{@{}rccc@{}}")
push!(acft, raw"\toprule")
push!(acft, raw"\textbf{Lag $\tau$} & \textbf{$h(\tau)$} & \textbf{Predicted ACF} & \textbf{Simulated ACF} \\ \midrule")
for (tau, hv, pv, sv) in acf_pred_rows
    push!(acft, "\$$(tau)\$ & \$$(f3(hv))\$ & \$$(f3(pv))\$ & \$$(f3(sv))\$ \\\\")
end
push!(acft, raw"\bottomrule")
push!(acft, raw"\end{tabular}")

kct = String[]
push!(kct, raw"% Generated by code/spy-experiment/SI-Derivation-Checks.jl; do not edit numbers manually.")
push!(kct, raw"\begin{tabular}{@{}ccc@{}}")
push!(kct, raw"\toprule")
push!(kct, raw"$\rho_i$ & \textbf{Predicted $\kappa$} & \textbf{Simulated $\kappa$} \\ \midrule")
for (rt, kp, km) in kurt_comp_rows
    push!(kct, "\$$(@sprintf("%.1f", rt))\$ & \$$(f2(kp))\$ & \$$(f2(km))\$ \\\\")
end
push!(kct, raw"\bottomrule")
push!(kct, raw"\end{tabular}")

repo_root = dirname(dirname(_ROOT))
for tree in ("arxiv-paper", "jfds-paper")   # preprint tree first, then JFDS
    tdir = joinpath(repo_root, tree, "sections", "tables")
    write(joinpath(tdir, "tableS_generator_quantities.tex"), join(quant, "\n") * "\n")
    write(joinpath(tdir, "tableS_acf_prediction.tex"), join(acft, "\n") * "\n")
    write(joinpath(tdir, "tableS_kurt_composition.tex"), join(kct, "\n") * "\n")
    @info "Wrote SI table bodies to $tdir"
end
