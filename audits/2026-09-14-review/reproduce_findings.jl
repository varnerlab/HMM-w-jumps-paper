# Independent review probes. Does not modify manuscript or experiment outputs.
# Run from the repository root:
# julia --project=code/downstream-evaluation audits/2026-09-14-review/reproduce_findings.jl
using Random, Statistics, LinearAlgebra, StatsBase, Distributions
using JLD2, DataFrames, HypothesisTests, Printf, Test, TOML
import JumpHMM

const repo = normpath(joinpath(@__DIR__, "..", ".."))
const src = joinpath(repo, "code", "downstream-evaluation", "src")
include(joinpath(src, "Composers.jl"))
include(joinpath(src, "Metrics.jl"))
include(joinpath(src, "VaRBacktest.jl"))

println("Julia: ", VERSION)
println("JumpHMM: ", pathof(JumpHMM))

function reference_kupiec(n, T, alpha)
    p = 1-alpha
    q = n/T
    null = n*log(p) + (T-n)*log1p(-p)
    alt = (n==0 ? 0.0 : n*log(q)) + (n==T ? 0.0 : (T-n)*log1p(-q))
    return ccdf(Chisq(1), -2*(null-alt))
end

println("\nKupiec boundary checks (implementation versus likelihood limit):")
for (n,T,a) in ((0,100,0.99),(0,249,0.99),(0,249,0.95),(1,249,0.99))
    @printf("n=%d T=%d alpha=%.2f actual=%.9f reference=%.9f\n",
        n,T,a,kupiec_pvalue(n,T,a),reference_kupiec(n,T,a))
end

function quantile_null_probe()
    rng = MersenneTwister(20260914)
    trials = 50_000
    println("\nPerfect-generator null: 249 training draws, exact population breach probability.")
    println("This measures threshold error without noisy test samples or model misspecification.")
    for distribution in (Uniform(-1,1), Normal(), TDist(5)), alpha in (0.95,0.99)
        rates = [cdf(distribution, -var_threshold(rand(rng,distribution,249),alpha)) for _ in 1:trials]
        @printf("%s alpha=%.2f mean_rate=%.6f mc_se=%.6f nominal=%.4f\n",
            string(distribution),alpha,mean(rates),std(rates)/sqrt(trials),1-alpha)
    end
    println("Exact uniform 99% result = (1 + 248*0.01)/250 = ", (1+248*.01)/250)
end
quantile_null_probe()

function horizon_probe()
    rng = MersenneTwister(20260915)
    T, reps = 249, 1000
    gm = randn(rng,T)
    totals = Dict(k=>Float64[] for k in ("naive","hybrid","gaussian"))
    for _ in 1:reps
        x = 0.3 .+ 2randn(rng,T)
        naive = compose_naive(0.1,0.5,gm,x)
        hybrid,beta,flag = compose_hybrid(0.1,0.5,0.2,gm,x,var(gm),var(x))
        gaussian = compose_gaussian_sim(0.1,0.5,sqrt(4-.25var(gm)),gm,rng)
        push!(totals["naive"],sum(naive .- 0.1 .- 0.5gm)/252)
        push!(totals["hybrid"],sum(hybrid .- 0.1 .- beta*gm)/252)
        push!(totals["gaussian"],sum(gaussian .- 0.1 .- 0.5gm)/252)
    end
    println("\nTerminal idiosyncratic log-return SD, fixed market, 1,000 paths:")
    for k in ("naive","hybrid","gaussian")
        @printf("%s %.12g\n",k,std(totals[k]))
    end
    gm2=gm .+ 0.2
    x=2randn(rng,T)
    g,beta,flag=compose_hybrid(0.1,3.0,0.2,gm2,x,var(gm2),var(x))
    @printf("Clipped mean shift from calibrated alpha+beta*market: %.9f; identity %.9f\n",
        mean(g)-(0.1+3mean(gm2)),(beta-3)*mean(gm2))
end
horizon_probe()

println("\nPublished training cache:")
data = joinpath(repo,"code","downstream-evaluation","data")
saved = load(joinpath(data,"results.jld2"))
r = saved["results"]
println("keys=",keys(saved)," rows=",nrow(r)," columns=",names(r))
println(combine(groupby(r,:composer), nrow=>:rows, :ticker=>(x->length(unique(x)))=>:assets,
    :ks_p=>(x->100mean(x.>0.05))=>:KS, :w1=>median=>:W1))
cal = load(joinpath(data,"sim-calibration.jld2"))["calibration"]
alphas=Dict(zip(cal.ticker,cal.alpha))
r.alpha_error=[abs(row.α_hat-alphas[row.ticker]) for row in eachrow(r)]
println(combine(groupby(r,:composer),:alpha_error=>median=>:median_alpha_error))

function fresh_models_probe()
    universe=load(joinpath(data,"universe.jld2"))
    tickers=universe["tickers"]
    prices=universe["prices"]
    G=universe["growth_rates"]
    gm=G[:,findfirst(==("SPY"),tickers)]
    cfg=TOML.parsefile(joinpath(data,"..","config.toml"))
    models=Dict{String,JumpHMM.JumpHiddenMarkovModel}()
    println("\nFresh full-return fits, all 424 tickers:")
    for (i,t) in enumerate(tickers)
        models[t]=JumpHMM.fit(JumpHMM.JumpHiddenMarkovModel,prices[:,i];
            N=cfg["hmm"]["N"],ν=cfg["hmm"]["nu"],rf=cfg["hmm"]["risk_free_rate"],dt=cfg["hmm"]["dt"])
    end
    println("fitted=",length(models))
    println("models with fallback emissions=",count(m->any(e.is_fallback for e in m.emissions),values(models)))
    for ticker in ("AAPL","JNJ","QQQ")
        model=models[ticker]
        calrow=only(eachrow(filter(x->x.ticker==ticker,cal)))
        i=findfirst(==(ticker),cal.ticker)
        draws=JumpHMM.simulate(model,length(gm);n_paths=100,seed=1234+i)
        for method in ("naive","hybrid")
            ks=Float64[]; alphas_error=Float64[]
            for path in draws.paths
                x=path.observations
                g = method=="naive" ? compose_naive(calrow.alpha,calrow.beta,gm,x) :
                    first(compose_hybrid(calrow.alpha,calrow.beta,calrow.r2_real,gm,x,var(gm),var(x)))
                push!(ks,ks_pvalue(g,G[:,findfirst(==(ticker),tickers)]))
                push!(alphas_error,abs(sim_recovery(g,gm)[1]-calrow.alpha))
            end
            old=filter(x->x.ticker==ticker && x.composer==method,r)
            @printf("%s %s fresh KS=%.1f cached KS=%.1f fresh alpha error=%.6f cached=%.6f\n",
                ticker,method,100mean(ks.>.05),100mean(old.ks_p.>.05),median(alphas_error),median(old.alpha_error))
        end
    end
    temp=get(ENV,"HMM_REVIEW_TEMP","/private/tmp/hmm-review-2026-09-14")
    mkpath(temp)
    jldsave(joinpath(temp,"fresh-marginals.jld2");marginals=models)
end
fresh_models_probe()
