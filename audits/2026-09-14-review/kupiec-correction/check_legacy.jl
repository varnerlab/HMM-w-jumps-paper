using CSV, DataFrames, Distributions, JLD2, Statistics, SHA, TOML, Test
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "code", "downstream-evaluation"))
include(joinpath(ROOT, "src", "VaRBacktest.jl"))
module BeforeR10
    using Distributions, Statistics
    include(joinpath(@__DIR__, "..", "..", "..", "code", "downstream-evaluation",
        "results", "var-ensemble", "source-corrections", "VaRBacktest.before-R10.jl"))
end

# Saved holdout rates were evaluated on 249 real daily returns (script 10).
# Verify integer counts and agreement with the archived implementation before
# attributing a change to R10. Preserve the historical result files in place.
const HORIZON = 249
horizons = Dict(name => jldopen(joinpath(ROOT, "data", name), "r") do file
    file["T_oos"]
end for name in ("results-oos.jld2", "results-oos-centered.jld2", "results-oos-centered-components.jld2"))
@assert all(==(HORIZON), values(horizons))
open(joinpath(@__DIR__, "legacy-horizons.toml"), "w") do io
    TOML.print(io, horizons)
end
lookup = DataFrame([(observations=HORIZON, alpha_level=α, n_breach=n,
    old_p=BeforeR10.kupiec_pvalue(n, HORIZON, α),
    corrected_p=kupiec_pvalue(n, HORIZON, α)) for α in (.95, .99) for n in 0:HORIZON])
CSV.write(joinpath(@__DIR__, "kupiec-values-T249.csv"), lookup)
rows = NamedTuple[]
hashes = Dict{String,String}()

@testset "Saved legacy diagnostic impact" begin
    for filename in ("results-oos.csv", "results-oos-centered.csv", "results-oos-centered-components.csv")
        path = joinpath(ROOT, "data", filename)
        hashes[filename] = open(io -> bytes2hex(sha256(io)), path)
        data = CSV.read(path, DataFrame; types=Dict(:ticker=>String))
        for level in (95, 99)
            α = level / 100
            rate = data[!, Symbol("var$(level)_rate")]
            old_p = data[!, Symbol("var$(level)_kupiec_p")]
            counts = round.(Int, HORIZON .* rate)
            @test all(abs.(HORIZON .* rate .- counts) .< 1e-10)
            @test all(0 .≤ counts .≤ HORIZON)
            expected_old = [BeforeR10.kupiec_pvalue(n, HORIZON, α) for n in counts]
            @test all(isapprox.(old_p, expected_old; rtol=1e-12, atol=1e-14))
            new_p = [kupiec_pvalue(n, HORIZON, α) for n in counts]
            boundary = (counts .== 0) .| (counts .== HORIZON)
            @test all(isapprox.(old_p[.!boundary], new_p[.!boundary]; rtol=2e-10, atol=1e-13))
            for method in sort(unique(data.composer))
                ids = findall(==(method), data.composer)
                push!(rows, (file=filename, composer=method, alpha_level=α, records=length(ids),
                    zero_breaches=count(==(0), counts[ids]), all_breaches=count(==(HORIZON), counts[ids]),
                    mean_p_before=mean(old_p[ids]), mean_p_corrected=mean(new_p[ids]),
                    pass_rate_before=mean(old_p[ids] .> .05), pass_rate_corrected=mean(new_p[ids] .> .05),
                    changed_5pct_decisions=count((old_p[ids] .> .05) .!= (new_p[ids] .> .05))))
            end
        end
        @test open(io -> bytes2hex(sha256(io)), path) == hashes[filename]
    end
end
report = DataFrame(rows)
CSV.write(joinpath(@__DIR__, "legacy-impact.csv"), report)
open(joinpath(@__DIR__, "legacy-inputs.toml"), "w") do io
    TOML.print(io, Dict("observations"=>HORIZON, "input_sha256"=>hashes,
        "policy"=>"Historical files preserved; corrected p-values derived from verified integer breach counts"))
end
show(combine(groupby(report, [:file, :alpha_level]),
    [:records, :zero_breaches, :all_breaches, :changed_5pct_decisions] .=> sum);
    allrows=true, allcols=true)
println()
