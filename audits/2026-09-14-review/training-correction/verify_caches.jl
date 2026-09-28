# Compare every regenerated path with the archived centered run, and independently
# identify which methods differ from the old distributed canonical cache.
include(joinpath(@__DIR__,"..","..","..","code","downstream-evaluation","src","TrainingSetup.jl"))
fresh,cal,meta = load_canonical_training()
sort!(fresh,[:ticker,:composer,:rep])
metrics = [:α_hat,:β_hat,:R²_hat,:ks_p,:ad_p,:w1,:hill_up,:kurt,:var_g]
comparisons = Dict{String,Any}()
for (label,name) in (("old_canonical","results.jld2"),("historical_centered","results-centered.jld2"))
    historical = load(joinpath(@__DIR__,"before","code","downstream-evaluation","data",name),"results")
    sort!(historical,[:ticker,:composer,:rep])
    @assert historical[:,[:ticker,:composer,:rep]] == fresh[:,[:ticker,:composer,:rep]]
    comparison = Dict{String,Any}()
    for method in TRAINING_METHODS
        a = filter(r->r.composer==method,fresh)
        b = filter(r->r.composer==method,historical)
        errors = Dict(string(metric)=>maximum(abs.(a[!,metric].-b[!,metric])) for metric in metrics)
        same = all(isapprox.(Matrix(a[:,metrics]),Matrix(b[:,metrics]);atol=1e-12,rtol=1e-12))
        comparison[method] = Dict("paths"=>nrow(a),"all_metrics_agree"=>same,"maximum_absolute_difference"=>errors)
        label=="historical_centered" && @assert same
        label=="old_canonical" && method in TRAINING_METHODS[[2,4,5,6]] && @assert same
    end
    comparisons[label]=comparison
    CSV.write(joinpath(@__DIR__,"comparison-"*label*"-summary.csv"),training_summary(historical,cal))
end

# All native metrics in the earlier centering control should describe these
# same draws, not just yield matching rounded aggregate scores.
control = CSV.read(joinpath(_ROOT,"results","centering-control","paired-paths.csv"),DataFrame;
    types=Dict(:ticker=>String))
rename!(control,:method=>:composer)
sort!(control,[:ticker,:composer,:rep])
@assert control[:,[:ticker,:composer,:rep]]==fresh[:,[:ticker,:composer,:rep]]
index = Dict(row.ticker=>row for row in eachrow(cal))
checks = Dict{String,Bool}()
for (source,target) in ((:native_w1,:w1),(:native_variance,:var_g),(:native_kurtosis,:kurt))
    checks[string(source)]=all(isapprox.(control[!,source],fresh[!,target];atol=1e-12,rtol=1e-12))
end
checks["ks_pass"]=all(control.native_ks_pass .== (fresh.ks_p .> .05))
checks["ad_pass"]=all(control.native_ad_pass .== (fresh.ad_p .> .05))
for (source,metric,target) in ((:native_alpha_error,:α_hat,:alpha),(:native_beta_error,:β_hat,:beta),(:native_r2_error,:R²_hat,:r2_real))
    expected_errors = [abs(row[metric]-index[row.ticker][target]) for row in eachrow(fresh)]
    checks[string(source)]=all(isapprox.(control[!,source],expected_errors;atol=1e-12,rtol=1e-12))
end
@assert all(values(checks))
report = Dict("rows"=>nrow(fresh),"comparisons"=>comparisons,"centering_control_checks"=>checks,
    "canonical_signature"=>meta["signature"])
open(joinpath(@__DIR__,"cache-checks.toml"),"w") do io
    TOML.print(io,report;sorted=true)
end
println("All ",nrow(fresh)," regenerated paths agree with the historical centered cache.")
println("Every native metric available from the centering control agrees.")
println("Old canonical Gaussian, residual JumpHMM, bootstrap, and GARCH rows agree; naive/hybrid differ.")
