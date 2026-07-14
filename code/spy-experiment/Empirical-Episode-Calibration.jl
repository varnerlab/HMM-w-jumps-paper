# Empirical tail-episode calibration diagnostic.
# Measures tail-episode frequency and duration on the real SPY IS series and on
# base-chain (no-jump) simulations, to calibrate (epsilon, lambda) empirically
# and check for base-chain double-counting. Read-only (writes nothing).
include("Include.jl")
using JLD2, Statistics, StatsBase, Random

hub      = load(joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2"))
model_nj = hub["model_nj"]
model_wj = hub["model_wj"]
g_is     = hub["insampledataset"]
N        = hub["number_of_states"]
N_tail   = 5
T        = length(g_is)

in_tail(s) = (s <= N_tail) || (s >= N - N_tail + 1)

function episodes(mask::AbstractVector{Bool})
    eps = Int[]; run = 0
    for m in mask
        if m; run += 1
        else; run > 0 && push!(eps, run); run = 0; end
    end
    run > 0 && push!(eps, run)
    return eps
end

println("N=$N, N_tail=$N_tail, T=$T")
println("Current tuned WJ: epsilon=$(model_wj.jump.ϵ), lambda=$(model_wj.jump.λ), p_neg=$(model_wj.jump.p_neg), N_tail=$(model_wj.jump.N_tail)")
println("epsilon*lambda (approx forced-tail fraction added) = $(round(model_wj.jump.ϵ*model_wj.jump.λ, sigdigits=3))")

# ---- EMPIRICAL (real SPY IS) ----
states_emp = JumpHMM.assign_states(model_nj.partition, g_is)
tm = in_tail.(states_emp)
ep = episodes(tm)
println("\n=== EMPIRICAL (real SPY IS) ===")
println("tail days = $(sum(tm))/$T = $(round(100*mean(tm),digits=2))%")
println("n episodes(all runs) = $(length(ep)); mean dur = $(round(mean(ep),digits=2)); median = $(median(ep)); max = $(maximum(ep))")
for L in 1:6; println("  len==$L: $(count(==(L), ep))"); end
println("  len>=2: $(count(>=(2),ep)); >=3: $(count(>=(3),ep)); >=5: $(count(>=(5),ep)); >=10: $(count(>=(10),ep))")

non_tail = T - sum(tm)
println("\n candidate A (all runs, per-step onset among non-tail steps):")
println("   epsilon = $(round(length(ep)/non_tail, sigdigits=3)); lambda = $(round(mean(ep),digits=2))")
for thr in (2,3,5)
    eps_s = filter(>=(thr), ep); d = sum(eps_s)
    if !isempty(eps_s)
        println(" candidate (sustained >= $thr-day clusters): n=$(length(eps_s)); epsilon=$(round(length(eps_s)/(T-d), sigdigits=3)); lambda(mean of those)=$(round(mean(eps_s),digits=2))")
    end
end

# ---- BASE CHAIN (model_nj, no jumps) ----
Random.seed!(1234)
res = simulate(model_nj, T; n_paths=500)
println("\nSimulationPath fields: ", fieldnames(typeof(res.paths[1])))
statef = :states in fieldnames(typeof(res.paths[1])) ? :states : fieldnames(typeof(res.paths[1]))[1]
base_eps = Int[]; base_tf = Float64[]
for p in res.paths
    st = getproperty(p, statef)
    st = length(st) == T+1 ? st[2:end] : st
    m = in_tail.(st); push!(base_tf, mean(m)); append!(base_eps, episodes(m))
end
println("\n=== BASE CHAIN (model_nj, no jumps, 500 paths) ===")
println("mean tail frac = $(round(100*mean(base_tf),digits=2))% (cf empirical $(round(100*mean(tm),digits=2))%)")
println("mean episode dur = $(round(mean(base_eps),digits=2)); max = $(maximum(base_eps))")
println("frac episodes len>=3 = $(round(mean(base_eps.>=3),digits=4)); >=5 = $(round(mean(base_eps.>=5),digits=4)); >=10 = $(round(mean(base_eps.>=10),digits=5))")
println("empirical frac episodes len>=3 = $(round(mean(ep.>=3),digits=4)); >=5 = $(round(mean(ep.>=5),digits=4)); >=10 = $(round(mean(ep.>=10),digits=4))")
