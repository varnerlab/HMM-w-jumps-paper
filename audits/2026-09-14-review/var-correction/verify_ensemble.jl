using CSV, DataFrames, JLD2, Random, Statistics, TOML, Test
import JumpHMM
using JumpHMM: JumpHiddenMarkovModel
const ROOT = normpath(joinpath(@__DIR__,"..","..","..","code","downstream-evaluation"))
for source in ("Composers.jl","GARCHFit.jl","VaRBacktest.jl","VaREnsemble.jl")
    include(joinpath(ROOT,"src",source))
end
cfg = TOML.parsefile(joinpath(ROOT,"config.toml"))
settings = TOML.parsefile(joinpath(ROOT,"var-ensemble.toml"))
ud = load(joinpath(ROOT,"data","universe.jld2"))
calib = load(joinpath(ROOT,"data","sim-calibration.jld2"),"calibration")
models = load(joinpath(ROOT,"data","marginals.jld2"),"marginals")
resid = load(joinpath(ROOT,"data","marginals-residuals.jld2"),"marginals")
garch = load_validated_garch_models(joinpath(ROOT,"data","garch-t-models.jld2");trial_length=249,seed=settings["seed"]);
index = Dict(t=>i for (i,t) in enumerate(ud["tickers"]))
gm = ud["growth_rates"][:,index["SPY"]]
i = findfirst(==("AAPL"),calib.ticker)
cal = calib[i,:]
history = ud["growth_rates"][:,index["AAPL"]] .- cal.alpha .- cal.beta .* gm
markets = [var_market_paths(models["SPY"],n,249,settings["batch_size"],settings["seed"],phase)
    for (phase,n) in enumerate((5000,1000))]
paths = [var_asset_paths(cal,i,models,resid,garch,history,markets[p],var(gm),cfg,settings,p) for p in 1:2]
recomputed = summarize_var_calibration(paths[1],paths[2],"AAPL",settings["checkpoints"])
saved = CSV.read(joinpath(ROOT,"results","var-ensemble","assets","AAPL.csv"),DataFrame)
@testset "Production ensemble integration" begin
    # Serial replay of a ticker produced during the threaded full run.
    @test recomputed == saved
    @test markets[1][:,1:1000] != markets[2]
    @test length(unique(Tuple(markets[1][:,j]) for j in 1:5000)) == 5000
    @test all(size(p) == (249,5000) for p in values(paths[1]))
    @test all(size(p) == (249,1000) for p in values(paths[2]))
    # Check a production path directly against the unchanged composers.
    full = JumpHMM.simulate(models["AAPL"],249;n_paths=100,
        seed=var_seed(settings["seed"],1,2,i,1))
    draw = full.paths[1].observations
    market = markets[1][:,1]
    dt = cfg["hmm"]["dt"]
    @test paths[1]["naive"][:,1] == dt .* compose_naive(cal.alpha,cal.beta,market,draw)
    hybrid, beta, _ = compose_hybrid(cal.alpha,cal.beta,cal.r2_real,market,draw,var(gm),var(draw);
        f=cfg["hybrid"]["idiosyncratic_floor"],R²_threshold=cfg["hybrid"]["r2_preserve_threshold"])
    @test paths[1]["hybrid"][:,1] == dt .* hybrid
    @test abs(sum(hybrid .- cal.alpha .- beta .* market)) < 1e-10
    @test std(vec(mean(paths[1]["gaussian"] ./ dt .- cal.alpha .- cal.beta .* markets[1];dims=1))) > 0.01
    @test all(isfinite, recomputed.validation_mcse)
end
