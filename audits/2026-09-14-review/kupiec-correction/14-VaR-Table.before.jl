# Table 5 consumes only the dedicated pooled ensemble, never results-oos.jld2.
using CSV, DataFrames, Printf, TOML, SHA
let
    root = normpath(joinpath(@__DIR__,".."))
    output = joinpath(root,"results","var-ensemble")
    isfile(joinpath(output,"scoring.toml")) || error("Run 13-VaR-Ensemble.jl first")
    manifest = TOML.parsefile(joinpath(output,"provenance.toml"))
    scoring = TOML.parsefile(joinpath(output,"scoring.toml"))
    settings = TOML.parsefile(joinpath(root,"var-ensemble.toml"))
    manifest["settings"] == settings || error("Pooled VaR settings mismatch")
    scoring["calibration_signature"] == manifest["signature"] || error("Pooled VaR provenance mismatch")
    for (path, hash) in manifest["hashes"]
        open(io -> bytes2hex(sha256(io)),joinpath(root,path)) == hash ||
            error("Pooled VaR input/source changed: $path")
    end
    open(io -> bytes2hex(sha256(io)),joinpath(output,"thresholds.csv")) == scoring["thresholds_sha256"] ||
        error("Pooled VaR thresholds changed after scoring")
    summary = CSV.read(joinpath(output,"summary.csv"),DataFrame)
    selected = filter(r -> r.population == "available" &&
        r.calibration_paths == settings["calibration_paths"],summary)
    order = ["naive","gaussian","hybrid","residual_jumphmm","block_bootstrap","garch_t"]
    names = ["Naive","Gaussian SIM","Hybrid","JumpHMM-on-residuals","Block bootstrap","GARCH(1,1)-\$t\$"]
    @assert nrow(selected) == 12
    CSV.write(joinpath(root,"data","var-backtest-oos-summary.csv"),selected)
    buffer = IOBuffer()
    row_end = " " * string(Char(92),Char(92))
    println(buffer, raw"\begin{tabular}{lrrrrr}")
    println(buffer, raw"\toprule")
    println(buffer, raw" & & \multicolumn{2}{c}{$\alpha = 0.95$} & \multicolumn{2}{c}{$\alpha = 0.99$}", row_end)
    println(buffer, raw"\cmidrule(lr){3-4} \cmidrule(lr){5-6}")
    println(buffer, raw"Method & Assets & rate (\%) & SD (pp) & rate (\%) & SD (pp)", row_end)
    println(buffer, raw"\midrule")
    for (method,name) in zip(order,names)
        row95 = only(eachrow(filter(r -> r.composer == method && r.alpha_level == .95,selected)))
        row99 = only(eachrow(filter(r -> r.composer == method && r.alpha_level == .99,selected)))
        @assert row95.n_tickers == row99.n_tickers == (method == "garch_t" ? 386 : 416)
        values = [name,string(row95.n_tickers),
            (@sprintf("%.2f",100x) for x in (row95.mean_rate,row95.sd_rate,row99.mean_rate,row99.sd_rate))...]
        println(buffer,join(values," & "),row_end)
    end
    println(buffer,raw"\bottomrule")
    println(buffer,raw"\end{tabular}")
    table = String(take!(buffer))
    for paper in ("arxiv-paper","jfds-paper")
        write(joinpath(root,"..","..",paper,"sections","tables","table5_var_backtest_oos.tex"),table)
    end
    show(selected;allrows=true,allcols=true)
    println()
end
