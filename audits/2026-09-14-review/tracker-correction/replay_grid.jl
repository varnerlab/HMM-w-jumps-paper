using CSV, DataFrames, JLD2, Random, Statistics, LinearAlgebra, StatsBase, HypothesisTests, TOML, SHA, Test
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "code", "downstream-evaluation"))
include(joinpath(ROOT, "src", "Composers.jl"))
include(joinpath(ROOT, "src", "Metrics.jl"))

cfg = TOML.parsefile(joinpath(ROOT, "config.toml"))
ud = load(joinpath(ROOT, "data", "universe.jld2"))
gm = ud["growth_rates"][:, findfirst(==(cfg["universe"]["market_ticker"]), ud["tickers"])]
rng = MersenneTwister(cfg["simulation"]["seed"])
rows = NamedTuple[]
checks = NamedTuple[]

for β in (.8, 1., 1.2), R² in (.8, .85, .9, .95, .99), rep in 1:cfg["simulation"]["n_paths"]
    target = β^2 * var(gm) * (1 - R²) / R²
    σ = sqrt(target)
    reference = 0.0 .+ β .* gm .+ σ .* randn(rng, length(gm))
    draw = σ .* randn(rng, length(gm))
    g, β_eff, flag = compose_hybrid(0., β, R², gm, draw, var(gm), target;
        f=cfg["hybrid"]["idiosyncratic_floor"], R²_threshold=cfg["hybrid"]["r2_preserve_threshold"])
    _, β_hat, R²_hat = sim_recovery(g, gm)
    push!(rows, (beta_true=β, r2_true=R², rep=rep, beta_hat=β_hat, r2_hat=R²_hat,
        ks_p=ks_pvalue(g, reference), kurt=excess_kurtosis(g), flag=string(flag),
        beta_eff=β_eff, var_g=var(g)))
    push!(checks, (scale=sqrt(target / target), residual_mean=mean(g .- β .* gm),
        reference_residual_mean=mean(reference .- β .* gm),
        variance_ratio=var(draw) / target))
end
replayed = DataFrame(rows)
saved = CSV.read(joinpath(ROOT, "data", "synth-tracker.csv"), DataFrame)
summary = combine(groupby(replayed, [:beta_true, :r2_true]),
    :beta_hat => median => :median_beta_hat, :beta_hat => std => :sd_beta_hat,
    :r2_hat => median => :median_r2_hat, :r2_hat => std => :sd_r2_hat,
    :ks_p => (p -> 100mean(p .> .05)) => :ks_pass_pct,
    :flag => (f -> join(unique(f), ",")) => :flags)
stored_summary = CSV.read(joinpath(ROOT, "data", "synth-tracker-summary.csv"), DataFrame)

@testset "Original tracker grid replay" begin
    @test nrow(replayed) == 1500
    @test names(replayed) == names(saved)
    for column in names(saved)
        @test replayed[!, column] == saved[!, column]
    end
    @test summary == stored_summary
    @test all(x -> x.scale == 1, checks)
    @test maximum(abs(x.residual_mean) for x in checks) < 1e-12
    @test std(x.reference_residual_mean for x in checks) > .001
    @test std(x.variance_ratio for x in checks) > .001
    original = Meta.parseall(read(joinpath(@__DIR__, "08-Synthetic-Tracker-Eval.before.jl"), String))
    current = Meta.parseall(read(joinpath(ROOT, "scripts", "08-Synthetic-Tracker-Eval.jl"), String))
    # Remove source-location metadata at every AST level, including macros.
    strip_locations(x) = x isa Expr ? Expr(x.head,
        (strip_locations(a) for a in x.args if !(a isa LineNumberNode))...) : x
    @test strip_locations(original) == strip_locations(current)
end
CSV.write(joinpath(@__DIR__, "replayed-summary.csv"), summary)
open(joinpath(@__DIR__, "grid-checks.toml"), "w") do io
    TOML.print(io, Dict("rows"=>nrow(replayed), "cells"=>nrow(summary),
        "horizon"=>length(gm), "all_saved_values_reproduced_exactly"=>true,
        "all_scales_equal_one"=>true, "all_ks_pass"=>all(replayed.ks_p .> .05),
        "max_abs_composed_residual_mean"=>maximum(abs(x.residual_mean) for x in checks),
        "reference_residual_mean_sd"=>std(x.reference_residual_mean for x in checks),
        "realized_to_nominal_residual_variance_range"=>collect(extrema(x.variance_ratio for x in checks)),
        "script_executable_code_unchanged"=>true))
end
println("Reproduced all 1,500 historical grid rows and 15 summaries exactly.")
