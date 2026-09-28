# Run from the repository root with --project=code/downstream-evaluation.
using JLD2, Statistics, Distributions, HypothesisTests, Random, Printf
import JumpHMM
obs=load("code/spy-experiment/data/HMM-WJ-SPY-N-100-daily-aggregate.jld2")["insampledataset"]
mean_fit=Laplace(mean(obs),mean(abs.(obs.-mean(obs))))
mle_fit=fit_mle(Laplace,obs)
println("implemented fit=",mean_fit," MLE=",mle_fit)
rng=MersenneTwister(20260914)
a=Float64[]; b=Float64[]
for _ in 1:1000
 u=rand(rng,length(obs))
 x=quantile.(mean_fit,u); y=quantile.(mle_fit,u)
 push!(a,pvalue(ApproximateTwoSampleKSTest(obs,x)))
 push!(b,pvalue(ApproximateTwoSampleKSTest(obs,y)))
end
@printf("Matched-uniform comparison (new review seed): mean-centered KS=%.1f%% MLE KS=%.1f%%\n",100mean(a.>.05),100mean(b.>.05))
