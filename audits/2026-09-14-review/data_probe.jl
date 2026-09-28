using JLD2, DataFrames, Statistics
import JumpHMM
u=load("code/downstream-evaluation/data/universe.jld2")
for window in ("SP500-Daily-OHLC-1-3-2014-to-12-31-2024.jld2","SP500-Daily-OHLC-1-2-2025-to-12-31-2025.jld2")
 d=load(joinpath("code/downstream-evaluation/data",window))["dataset"]
 println(window," cols=",names(d["SPY"]))
 key=(:timestamp in propertynames(d["SPY"])) ? :timestamp : :date
 maxrows=maximum(nrow(df) for df in values(d))
 reference=d["SPY"][!,key]
 kept=[t for (t,x) in d if nrow(x)==maxrows]
 println("complete=",length(kept)," date_mismatch=",[t for t in kept if d[t][!,key]!=reference])
 println("first=",first(reference)," last=",last(reference)," sorted=",issorted(reference)," unique=",length(unique(reference))==length(reference))
 println("nonpositive/nonfinite closes=",sum(count(x->!isfinite(x)||x<=0,d[t].close) for t in kept))
end
ms=load("/private/tmp/hmm-review-2026-09-14/fresh-marginals.jld2")["marginals"]
for t in sort(collect(keys(ms)))
 m=ms[t]; f=findall(e->e.is_fallback,m.emissions); isempty(f) && continue
 println(t," fallback_states=",f," n_obs=",[m.emissions[k].n_obs for k in f]," stationary_mass=",sum(m.stationary[f]))
end
