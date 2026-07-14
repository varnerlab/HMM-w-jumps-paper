# ACF(|g|) clustering + kurtosis under the current tuned (eps,lambda) vs
# empirically-calibrated candidates. Read-only (writes nothing).
include("Include.jl")
using JLD2, Statistics, StatsBase, Random

hub      = load(joinpath(_PATH_TO_DATA, "HMM-WJ-SPY-N-100-daily-aggregate.jld2"))
model_nj = hub["model_nj"]
model_wj = hub["model_wj"]
g_is     = hub["insampledataset"]
N        = hub["number_of_states"]
T        = length(g_is)
LAGS     = 1:25

make_wj(ϵ, λ) = JumpHiddenMarkovModel(model_nj.partition, model_nj.transition,
    model_nj.emissions, model_nj.stationary,
    JumpParameters(ϵ, λ; p_neg = 0.52, N_tail = 5),
    model_nj.ν, model_nj.rf, model_nj.dt)

acf_obs = autocor(abs.(g_is), collect(LAGS))
kurt_obs = kurtosis(g_is)   # excess kurtosis
println("empirical: excess kurtosis = $(round(kurt_obs,digits=2)); ACF(|g|) lag1=$(round(acf_obs[1],digits=3)) lag5=$(round(acf_obs[5],digits=3)) lag25=$(round(acf_obs[25],digits=3))")

function eval_cfg(model; n_paths = 500, seed = 1234)
    Random.seed!(seed)
    res = simulate(model, T; n_paths = n_paths)
    acfs = zeros(length(LAGS)); ks = Float64[]; jfrac = 0
    for p in res.paths
        o = p.observations
        acfs .+= autocor(abs.(o), collect(LAGS))
        push!(ks, kurtosis(o))
        any(p.jumps) && (jfrac += 1)
    end
    acfs ./= n_paths
    acfmae = mean(abs.(acfs .- acf_obs))
    return (acfmae = acfmae, kurt = mean(ks), jfrac = jfrac / n_paths)
end

cfgs = [
    ("NJ base (no jumps)",        model_nj),
    ("WJ tuned (e=1e-4, l=90)",   make_wj(1e-4, 90.0)),
    ("emp all-runs (e=.079,l=1.34)", make_wj(0.0792, 1.34)),
    ("emp sustained>=2 (e=.0166,l=2.52)", make_wj(0.0166, 2.52)),
    ("emp sustained>=3 (e=.00478,l=3.77)", make_wj(0.00478, 3.77)),
    ("emp sustained>=5 (e=.000727,l=7)", make_wj(0.000727, 7.0)),
]
println("\n", rpad("config",38), rpad("ACF-MAE",10), rpad("kurtosis",10), "jump-path frac")
println("-"^72)
for (name, m) in cfgs
    r = eval_cfg(m)
    println(rpad(name,38), rpad(string(round(r.acfmae,digits=4)),10),
            rpad(string(round(r.kurt,digits=2)),10), round(r.jfrac,digits=3))
end
println("\n(observed excess kurtosis target = $(round(kurt_obs,digits=2)))")
