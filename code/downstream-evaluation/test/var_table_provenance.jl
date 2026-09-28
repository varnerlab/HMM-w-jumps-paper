using Test, TOML, SHA
include(joinpath(@__DIR__, "..", "src", "VaRTableProvenance.jl"))

@testset "R10 table-only source compatibility" begin
    root = normpath(joinpath(@__DIR__, ".."))
    output = joinpath(root, "results", "var-ensemble")
    record = TOML.parsefile(joinpath(output, "source-corrections", "R10.toml"))
    old = read(joinpath(output, "source-corrections", "VaRBacktest.before-R10.jl"), String)
    corrected = read(joinpath(root, "src", "VaRBacktest.jl"), String)
    # Everything outside the Kupiec function and its docstring is byte-identical.
    before_marker = "\"\"\"\n    kupiec_pvalue("
    after_marker = "\"\"\"\n    var_backtest("
    @test first(split(old, before_marker)) == first(split(corrected, before_marker))
    @test last(split(old, after_marker)) == last(split(corrected, after_marker))
    @test length(split(old, before_marker)) == length(split(corrected, before_marker)) == 2
    @test length(split(old, after_marker)) == length(split(corrected, after_marker)) == 2

    mktempdir() do tmp
        mkpath(joinpath(tmp, "src"))
        out = joinpath(tmp, "results")
        archive = joinpath(out, "source-corrections")
        mkpath(archive)
        write(joinpath(tmp, "src", "VaRBacktest.jl"), corrected)
        write(joinpath(archive, "VaRBacktest.before-R10.jl"), old)
        cp(joinpath(output, "source-corrections", "R10.toml"), joinpath(archive, "R10.toml"))
        write(joinpath(tmp, "input.csv"), "frozen input")
        manifest = Dict("signature" => record["original_signature"], "hashes" => Dict(
            "src/VaRBacktest.jl" => record["original_sha256"],
            "input.csv" => bytes2hex(sha256("frozen input"))))
        @test validate_var_table_sources(tmp, out, manifest)
        write(joinpath(tmp, "src", "VaRBacktest.jl"), corrected * "\n# unrecorded edit\n")
        @test_throws ErrorException validate_var_table_sources(tmp, out, manifest)
        write(joinpath(tmp, "src", "VaRBacktest.jl"), corrected)
        write(joinpath(archive, "VaRBacktest.before-R10.jl"), old * "\n")
        @test_throws ErrorException validate_var_table_sources(tmp, out, manifest)
        write(joinpath(archive, "VaRBacktest.before-R10.jl"), old)
        write(joinpath(tmp, "input.csv"), "changed input")
        @test_throws ErrorException validate_var_table_sources(tmp, out, manifest)
        write(joinpath(tmp, "input.csv"), "frozen input")
        manifest["signature"] = "different run"
        @test_throws ErrorException validate_var_table_sources(tmp, out, manifest)
        manifest["signature"] = record["original_signature"]
        write(joinpath(tmp, "src", "VaRBacktest.jl"), old)
        @test validate_var_table_sources(tmp, out, manifest)
    end
end
