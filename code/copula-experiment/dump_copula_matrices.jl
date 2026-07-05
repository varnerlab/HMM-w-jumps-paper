# Dump the already-computed copula-comparison matrices to CSV for the M-exam deck's
# 6-panel copula figure. Reads data/Copula-Comparison-Results.jld2 (no experiment re-run)
# and writes data/panels/{obs_corr,sim_corr_<model>,ks_by_model}.csv.
using JLD2, FileIO, DelimitedFiles

const HERE = @__DIR__
d = load(joinpath(HERE, "data", "Copula-Comparison-Results.jld2"))
results = d["results"]
tickers = d["tickers"]
obs_corr = d["obs_corr"]

outdir = joinpath(HERE, "data", "panels")
isdir(outdir) || mkpath(outdir)

# model internal name => short label used in the CSV filenames
models = ["SingleIndexModel" => "sim", "GaussianCopula" => "gauss",
          "StudentTCopula" => "t", "VineCopula" => "vine"]

writedlm(joinpath(outdir, "obs_corr.csv"), obs_corr, ',')
for (name, short) in models
    writedlm(joinpath(outdir, "sim_corr_$(short).csv"), results[name].sim_corr, ',')
end

# ks_by_model.csv: header row = model short names; first column = ticker; NaN where absent (SIM/SPY)
open(joinpath(outdir, "ks_by_model.csv"), "w") do io
    println(io, "ticker," * join([s for (_, s) in models], ","))
    for t in tickers
        vals = String[]
        for (name, _) in models
            r = results[name]
            push!(vals, haskey(r.marginal, t) ? string(r.marginal[t].ks_pass) : "NaN")
        end
        println(io, t * "," * join(vals, ","))
    end
end

# also dump the tickers in order, for the plotting script
writedlm(joinpath(outdir, "tickers.csv"), reshape(tickers, :, 1), ',')

println("dumped Paper I panels -> ", outdir)
for f in readdir(outdir); println("  ", f); end
