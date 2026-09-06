# Validate aggregation against independently grouped saved block diagnostics.
# Run after the full experiment; no trajectories are regenerated here.
using JLD2, CSV, DataFrames, Statistics, TOML, Test, SHA

root = normpath(joinpath(@__DIR__,".."))
settings = TOML.parsefile(joinpath(root,"jump-ablation.toml"))
directory = joinpath(root,settings["output_directory"])

@testset "Saved provenance matches the current experiment code" begin
    recorded = TOML.parsefile(joinpath(directory,"settings.toml"))
    for (key,path) in (("ablation_source_sha256",joinpath(root,"src","JumpAblation.jl")),
                       ("composer_source_sha256",joinpath(root,"src","Composers.jl")),
                       ("metrics_source_sha256",joinpath(root,"src","Metrics.jl")),
                       ("manifest_sha256",joinpath(root,"Manifest.toml")))
        @test recorded["provenance"][key] == open(io->bytes2hex(sha256(io)),path)
    end
end

@testset "All configured paths and correct aggregation" begin
    for (window,n_assets) in (("training",423),("holdout_2025",416)), seed in settings["seeds"]
        saved = load(joinpath(directory,"block-$window-$seed.jld2"))
        block = saved["result"]
        @test length(unique(block.ticker.ticker)) == n_assets
        @test nrow(block.ticker) == n_assets*6
        @test nrow(block.replication) == settings["n_paths_per_seed"]*6
        @test all(block.ticker.n_paths .== settings["n_paths_per_seed"])
        @test sum(block.stratum.n_paths) == n_assets*settings["n_paths_per_seed"]*6
        @test all(.!block.market.jump_active[.!block.market.enabled])
        @test all(block.generator.jump_active_rate[.!block.generator.enabled] .== 0)
        for group in groupby(block.ticker,[:scenario,:method])
            case,method = group.scenario[1],group.method[1]
            rep = filter(r->r.scenario==case && r.method==method,block.replication)
            strata = filter(r->r.scenario==case && r.method==method,block.stratum)
            for metric in (:ks_pass,:abs_acf_mae25,:abs_acf_mae60,:variance_ratio_generator)
                # The per-replication mean and the per-ticker mean commute.
                @test mean(group[!,metric]) ≈ mean(rep[!,metric]) atol=1e-12
                # Weighted jump strata must reconstruct the unconditional result.
                @test sum(strata[!,metric].*strata.n_paths)/sum(strata.n_paths) ≈ mean(group[!,metric]) atol=1e-12
            end
        end
    end
end

@testset "Published summaries and paired differences" begin
    summary = CSV.read(joinpath(directory,"summary.csv"),DataFrame)
    contrasts = CSV.read(joinpath(directory,"paired-contrasts.csv"),DataFrame)
    @test nrow(summary)==12
    @test all(isfinite,Matrix(select(summary,Not([:window,:scenario,:method]))))
    @test all(contrasts.n_market_replications .== settings["n_paths_per_seed"]*length(settings["seeds"]))
    for r in eachrow(contrasts)
        base_case,base_method = split(r.baseline,"/")
        new_case,new_method = split(r.changed,"/")
        base = only(eachrow(filter(x->x.window==r.window && x.scenario==base_case && x.method==base_method,summary)))
        changed = only(eachrow(filter(x->x.window==r.window && x.scenario==new_case && x.method==new_method,summary)))
        @test r.mean_difference ≈ changed[Symbol(r.metric)]-base[Symbol(r.metric)] atol=1e-12
    end
end
