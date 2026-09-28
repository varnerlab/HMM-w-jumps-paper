using Test, CSV, DataFrames, JLD2, Random, Statistics
import ARCHModels
include(joinpath(@__DIR__, "..", "src", "GARCHFit.jl"))

const GARCH_DATA = joinpath(@__DIR__, "..", "data")
universe = load(joinpath(GARCH_DATA, "universe.jld2"))
calibration = load(joinpath(GARCH_DATA, "sim-calibration.jld2"), "calibration")
gm = universe["growth_rates"][:, findfirst(==("SPY"), universe["tickers"])]
function residuals_for(ticker)
    row = only(eachrow(filter(r->r.ticker==ticker, calibration)))
    return universe["growth_rates"][:,findfirst(==(ticker), universe["tickers"])] .-
           row.alpha .- row.beta .* gm
end

@testset "GARCH fit acceptance" begin
    e = residuals_for("AAPL")
    reference = ARCHModels.fit(ARCHModels.GARCH{1,1}, e;
                              dist=ARCHModels.StdT, meanspec=ARCHModels.NoIntercept{Float64})
    model, record = fit_checked_garch(e; ticker="AAPL")
    @test record.accepted && record.converged && record.trial_checked
    @test ARCHModels.coef(model) == ARCHModels.coef(reference)
    @test check_garch_model(model; trial_length=249).valid
    # A preflight must not change the scoring stream.
    Random.seed!(731)
    expected = rand(5)
    Random.seed!(731)
    check_garch_model(model; trial_length=249)
    @test rand(5) == expected

    # Regression: fitting returns normally, but its nonstationary result cannot
    # be simulated and must never reach the accepted model dictionary.
    alb = ARCHModels.fit(ARCHModels.GARCH{1,1}, residuals_for("ALB");
                         dist=ARCHModels.StdT, meanspec=ARCHModels.NoIntercept{Float64})
    @test_throws Exception ARCHModels.simulate(alb, 249)
    @test !check_garch_model(alb).valid
    rejected, bad_record = fit_checked_garch(residuals_for("ALB"); ticker="ALB")
    @test rejected === nothing
    @test bad_record.converged && !bad_record.accepted
    @test occursin("nonstationary", bad_record.reason)

    stopped, stopped_record = fit_checked_garch(e; ticker="AAPL",
                                               options=ARCHModels.Optim.Options(iterations=0))
    @test stopped === nothing
    @test !stopped_record.converged && !stopped_record.accepted
    @test stopped_record.reason == "optimizer did not converge"
    @test_throws ArgumentError fit_garch_with_diagnostics(zeros(10))

    function candidate(coefficients, nu=5.0)
        ARCHModels.UnivariateARCHModel(ARCHModels.GARCH{1,1}(coefficients), e;
            dist=ARCHModels.StdT(nu), meanspec=ARCHModels.NoIntercept{Float64}())
    end
    for invalid in (candidate([0.1,0.9,0.1]), candidate([0.0,0.8,0.1]),
                    candidate([0.1,-0.1,0.1]), candidate([NaN,0.8,0.1]),
                    candidate([0.1,0.8,0.1],2.0), candidate([0.1,0.8,0.1],Inf),
                    candidate([1e308,0.9,0.09]))
        @test !check_garch_model(invalid).valid
    end

    mktempdir() do dir
        cache = joinpath(dir, "garch.jld2")
        models = Dict("AAPL"=>model)
        jldsave(cache; models)
        @test_throws ErrorException load_validated_garch_models(cache; trial_length=249)
        metadata = Dict("schema"=>GARCH_CACHE_SCHEMA)
        diagnostics = DataFrame([record])
        jldsave(cache; models, diagnostics, metadata)
        @test Set(keys(load_validated_garch_models(cache; trial_length=249))) == Set(["AAPL"])
        models["AAPL"].spec.coefs[1] *= 2
        jldsave(cache; models, diagnostics, metadata)
        @test_throws ErrorException load_validated_garch_models(cache; trial_length=249)
    end
end
