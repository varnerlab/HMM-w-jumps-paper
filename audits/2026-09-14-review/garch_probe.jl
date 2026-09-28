using JLD2, DataFrames, Statistics, Random
import ARCHModels
u=load("code/downstream-evaluation/data/universe.jld2")
c=load("code/downstream-evaluation/data/sim-calibration.jld2")["calibration"]
gm=u["growth_rates"][:,findfirst(==("SPY"),u["tickers"])]
for ticker in ("ALB","ALL","AMAT")
 r=only(eachrow(filter(x->x.ticker==ticker,c)))
 e=u["growth_rates"][:,findfirst(==(ticker),u["tickers"])] .- r.alpha .- r.beta .* gm
 Random.seed!(1234)
 try
  m=ARCHModels.fit(ARCHModels.GARCH{1,1},e;dist=ARCHModels.StdT,meanspec=ARCHModels.NoIntercept{Float64})
  println(ticker," fit succeeded coefficients=",m.spec.coefs," persistence=",sum(m.spec.coefs[2:3]))
  try
   ARCHModels.simulate(m,249)
   println(ticker," simulation succeeded")
  catch err
   println(ticker," simulation FAILED: ",sprint(showerror,err))
  end
 catch err
  println(ticker," fit failed: ",sprint(showerror,err))
 end
end
