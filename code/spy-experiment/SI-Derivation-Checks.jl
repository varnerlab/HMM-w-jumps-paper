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
# Output: printed values (transcribed into the supplementary derivation section)
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
for tau in [1, 2, 3, 5, 10, 15, 20, 25]
    println("  $tau   $(round(h(tau), digits=3))   $(round(plateau * h(tau), digits=3))   $(round(mean_acf[tau], digits=3))")
end

# ── 8. Kurtosis composition under independent centered sums ──────────────────
# Verifies kappa(X + Y) = rho^2 * kappa(X) + (1 - rho)^2 * kappa(Y) for
# independent centered X, Y with variance shares rho and 1 - rho, using
# independent generator draws for both components (SIM residual-choice
# derivation in the supplement).
Random.seed!(777)
resA = simulate(model, Tn; n_paths = 200)   # stands in for the asset draw
resB = simulate(model, Tn; n_paths = 200)   # stands in for the market path
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
end

# ── 9. Stationary-mixture skewness against the observed value ────────────────
# Backs the supplement's claim that the occupancy-weighted mixture carries the
# observed asymmetry without an explicit skewness parameter. HMM-NJ is the
# fitted model with the jump probability set to zero.
model_nj = JumpHMM.fit(JumpHiddenMarkovModel,
                       MyTrainingMarketDataSet()["dataset"]["SPY"][!, :volume_weighted_average_price];
                       rf = 0.043, N = N, ν = nu, dt = 1.0 / 252.0)
println("observed in-sample skewness = ", round(skewness(g), digits = 4))
for (name, m) in (("HMM-NJ", model_nj), ("HMM-WJ", model))
    r  = simulate(m, Tn; n_paths = 1_000, seed = 1234)
    sk = [skewness(p.observations) for p in r.paths]
    @info "$name mean simulated skewness = $(round(mean(sk), digits = 4)) (SE $(round(std(sk)/sqrt(1_000), digits = 4)))"
end
