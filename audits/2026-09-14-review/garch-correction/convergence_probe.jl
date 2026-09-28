using JLD2, DataFrames, Statistics, Random, CSV
import ARCHModels
const A = ARCHModels
u=load("code/downstream-evaluation/data/universe.jld2")
c=load("code/downstream-evaluation/data/sim-calibration.jld2", "calibration")
gm=u["growth_rates"][:,findfirst(==("SPY"),u["tickers"])]
old=load("code/downstream-evaluation/data/garch-t-models.jld2", "models")
rows=NamedTuple[]
fresh=Dict{String,Any}()
for (i,r) in enumerate(eachrow(c))
 e=u["growth_rates"][:,findfirst(==(r.ticker),u["tickers"])] .- r.alpha .- r.beta .* gm
 try
  ms=A.NoIntercept{Float64}()
  x0=vcat(A.startingvals(A.GARCH{1,1}, e), A.startingvals(A.StdT, e))
  obj=x -> -A.loglik(A.GARCH{1,1},A.StdT,ms,e,x,trues(3),true)
  result=A.Optim.optimize(obj, x0, A.Optim.BFGS();autodiff=:forward)
  cc=A.Optim.minimizer(result)
  model=A.UnivariateARCHModel(A.GARCH{1,1}(cc[1:3]),e;dist=A.StdT(cc[4:4]),meanspec=ms,fitted=true)
  fresh[r.ticker]=model
  diff=haskey(old,r.ticker) ? maximum(abs.(A.coef(model).-A.coef(old[r.ticker]))) : NaN
  push!(rows,(ticker=r.ticker,converged=A.Optim.converged(result),iterations=A.Optim.iterations(result),persistence=sum(cc[2:3]),omega=cc[1],nu=cc[4],objective=A.Optim.minimum(result),old=haskey(old,r.ticker),max_coef_difference=diff,reason=""))
 catch err
  err isa InterruptException && rethrow()
  push!(rows,(ticker=r.ticker,converged=false,iterations=0,persistence=NaN,omega=NaN,nu=NaN,objective=NaN,old=haskey(old,r.ticker),max_coef_difference=NaN,reason=sprint(showerror,err)))
 end
 if i==1 || i%25==0 || i==nrow(c)
  println(i,"/",nrow(c)," fits; converged=",count(r->r.converged,rows));flush(stdout)
  CSV.write("audits/2026-09-14-review/garch-correction/convergence-probe.csv",DataFrame(rows))
 end
end
jldsave("audits/2026-09-14-review/garch-correction/probe-models.jld2";models=fresh)
println("Complete");flush(stdout)
