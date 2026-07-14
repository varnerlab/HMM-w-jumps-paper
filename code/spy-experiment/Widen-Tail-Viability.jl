# Viability check for "widen the tail": for a range of N_tail band widths,
# (1) does the empirical band-episode duration grow, and does the no-jump base
# chain UNDERSHOOT it (a gap jumps could fill)?  (2) at empirically-calibrated
# (eps,lambda) for the wider band, does the model beat base ACF-MAE without
# wrecking kurtosis?  Read-only.
include("Include.jl")
using JLD2, Statistics, StatsBase, Random

hub      = load(joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2"))
model_nj = hub["model_nj"]; model_wj = hub["model_wj"]
g_is     = hub["insampledataset"]; N = hub["number_of_states"]; T = length(g_is)
LAGS     = 1:25
acf_obs  = autocor(abs.(g_is), collect(LAGS)); kurt_obs = kurtosis(g_is)

in_band(s, nt) = (s <= nt) || (s >= N - nt + 1)
function episodes(mask)
    e = Int[]; r = 0
    for m in mask; m ? (r += 1) : (r > 0 && (push!(e, r); r = 0)); end
    r > 0 && push!(e, r); return e
end
states_emp = JumpHMM.assign_states(model_nj.partition, g_is)

Random.seed!(1234)
res_nj = simulate(model_nj, T; n_paths = 500)
base_states = [ length(p.states) == T + 1 ? p.states[2:end] : p.states for p in res_nj.paths ]

println("=== PART 1: episode-duration gap (empirical vs no-jump base) by tail width ===")
println(rpad("N_tail",7), rpad("band%",8), rpad("occ_emp",9), rpad("occ_base",10),
        rpad("dur_emp",9), rpad("dur_base",10), rpad("max_emp",9), "n_ep_emp")
for nt in [5,10,15,20,25,30]
    me = in_band.(states_emp, nt); ee = episodes(me)
    durs_b = Int[]; occ_b = Float64[]
    for st in base_states; m = in_band.(st, nt); push!(occ_b, mean(m)); append!(durs_b, episodes(m)); end
    println(rpad(nt,7), rpad("$(2*nt)%",8),
            rpad("$(round(100*mean(me),digits=1))%",9),
            rpad("$(round(100*mean(occ_b),digits=1))%",10),
            rpad(round(mean(ee),digits=2),9),
            rpad(round(mean(durs_b),digits=2),10),
            rpad(maximum(ee),9), length(ee))
end

make_wj(ϵ,λ,nt) = JumpHiddenMarkovModel(model_nj.partition, model_nj.transition,
    model_nj.emissions, model_nj.stationary, JumpParameters(ϵ,λ; p_neg=0.52, N_tail=nt),
    model_nj.ν, model_nj.rf, model_nj.dt)
function eval_cfg(m; n_paths=500, seed=1234)
    Random.seed!(seed); res = simulate(m, T; n_paths=n_paths)
    a = zeros(length(LAGS)); ks = Float64[]
    for p in res.paths; a .+= autocor(abs.(p.observations), collect(LAGS)); push!(ks, kurtosis(p.observations)); end
    a ./= n_paths; (acfmae = mean(abs.(a .- acf_obs)), kurt = mean(ks))
end

println("\n=== PART 2: ACF-MAE + kurtosis at empirical (eps,lambda) per width ===")
println("(target: ACF-MAE < base 0.20, kurtosis near $(round(kurt_obs,digits=2)))")
rb = eval_cfg(model_nj); println("REF base NJ            : ACF-MAE=$(round(rb.acfmae,digits=4)) kurt=$(round(rb.kurt,digits=2))")
rw = eval_cfg(model_wj); println("REF tuned WJ(nt5,l90)  : ACF-MAE=$(round(rw.acfmae,digits=4)) kurt=$(round(rw.kurt,digits=2))")
for nt in [10,15,20,30]
    me = in_band.(states_emp, nt); ee = episodes(me)
    λe = mean(ee); nb = T - sum(me); εe = length(ee)/nb
    for mult in (0.5, 1.0, 2.0)
        ε = εe*mult; r = eval_cfg(make_wj(ε, λe, nt))
        println("nt=$(rpad(nt,2)) ε=$(rpad(round(ε,sigdigits=2),8)) λ=$(rpad(round(λe,digits=1),5)) (ε·λ=$(rpad(round(ε*λe,digits=3),6))): ACF-MAE=$(round(r.acfmae,digits=4)) kurt=$(round(r.kurt,digits=2))")
    end
end
