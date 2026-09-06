# Rebuild the comparison figure and reviewable report from saved experiment summaries.
ENV["GKSwstype"] = "100"
include(joinpath(@__DIR__, "..", "Include.jl"))

function jump_ablation_report(directory)
    summary = CSV.read(joinpath(directory,"summary.csv"),DataFrame)
    contrasts = CSV.read(joinpath(directory,"paired-contrasts.csv"),DataFrame)
    replication = CSV.read(joinpath(directory,"replication-metrics.csv"),DataFrame)
    ticker = CSV.read(joinpath(directory,"ticker-metrics.csv"),DataFrame)
    generator = CSV.read(joinpath(directory,"generator-metrics.csv"),DataFrame)
    market = CSV.read(joinpath(directory,"market-metrics.csv"),DataFrame)
    settings = TOML.parsefile(joinpath(directory,"settings.toml"))
    cases = ["off","market_only","market_and_assets"]
    windows = ["training","holdout_2025"]
    methods = ["naive","hybrid"]
    labels = ["Jumps off","Market only","Market + assets"]
    seed_summary = combine(groupby(replication,[:window,:seed,:scenario,:method]),
        [s=>mean=>s for s in Symbol.(names(replication)[7:end])]...)
    CSV.write(joinpath(directory,"seed-summary.csv"),seed_summary)

    incremental_rows = NamedTuple[]
    for window in windows, method in methods
        base = sort(filter(r->r.window==window && r.scenario=="market_only" && r.method==method,replication),[:seed,:rep])
        changed = sort(filter(r->r.window==window && r.scenario=="market_and_assets" && r.method==method,replication),[:seed,:rep])
        @assert base[:,[:seed,:rep]]==changed[:,[:seed,:rep]]
        for metric in Symbol.(names(replication)[7:end])
            d = changed[!,metric]-base[!,metric]
            se = std(d)/sqrt(length(d))
            push!(incremental_rows,(window=window,kind="asset_jumps_given_market_jumps",
                baseline="market_only/$method",changed="market_and_assets/$method",
                metric=String(metric),mean_difference=mean(d),mc_se=se,
                mc_low=mean(d)-1.96se,mc_high=mean(d)+1.96se,n_market_replications=length(d)))
        end
    end
    incremental = DataFrame(incremental_rows)
    CSV.write(joinpath(directory,"incremental-jump-contrasts.csv"),incremental)

    # Equal weight per ticker, then average across simulation batches.
    asset_means = combine(groupby(ticker,[:window,:ticker,:scenario,:method]),
        :abs_acf_mae25=>mean=>:abs_acf_mae25,
        :abs_acf_mae60=>mean=>:abs_acf_mae60,
        :ks_pass=>mean=>:ks_pass,
        :w1_standardized=>mean=>:w1_standardized)
    CSV.write(joinpath(directory,"asset-means.csv"),asset_means)
    breadth_rows = NamedTuple[]
    for window in windows, case in cases[2:3], method in methods
        base = sort(filter(r->r.window==window && r.scenario=="off" && r.method==method,asset_means),:ticker)
        changed = sort(filter(r->r.window==window && r.scenario==case && r.method==method,asset_means),:ticker)
        @assert base.ticker == changed.ticker
        push!(breadth_rows,(window=window,scenario=case,method=method,n_assets=nrow(base),
            acf25_improved_fraction=mean(changed.abs_acf_mae25 .< base.abs_acf_mae25),
            acf60_improved_fraction=mean(changed.abs_acf_mae60 .< base.abs_acf_mae60),
            ks_improved_fraction=mean(changed.ks_pass .> base.ks_pass),
            w1_improved_fraction=mean(changed.w1_standardized .< base.w1_standardized)))
    end
    breadth = DataFrame(breadth_rows)
    CSV.write(joinpath(directory,"improvement-breadth.csv"),breadth)

    panels = []
    for window in windows, (metric,ylabel,scale) in
        ((:abs_acf_mae25,"Absolute-return ACF MAE, lags 1-25",1.0),
         (:ks_pass,"KS non-rejection (%)",100.0))
        p = plot(;xticks=(1:3,labels),ylabel=ylabel,
            title=window=="training" ? "2014-2024 training comparison" : "2025 holdout comparison",
            legend=metric==:abs_acf_mae25 ? :topright : false,
            framestyle=:box,gridalpha=0.15,margin=5Plots.mm)
        for (j,method) in enumerate(methods)
            means = Float64[]
            errors = Float64[]
            for case in cases
                vals = filter(r->r.window==window && r.scenario==case && r.method==method,replication)[!,metric]
                push!(means,scale*mean(vals))
                push!(errors,scale*1.96std(vals)/sqrt(length(vals)))
            end
            plot!(p,(1:3) .+ (j==1 ? -0.04 : 0.04),means;yerror=errors,
                label=method=="hybrid" ? "Corrected" : "Naive",lw=2,markershape=:circle,
                color=j==1 ? "#D55E00" : "#0072B2")
        end
        push!(panels,p)
    end
    figure = plot(panels...;layout=(2,2),size=(1200,760),dpi=180,
        plot_title="Jump settings: temporal fit and marginal tradeoff")
    savefig(figure,joinpath(directory,"jump-ablation-comparison.png"))
    savefig(figure,joinpath(directory,"jump-ablation-comparison.pdf"))

    report_path = joinpath(directory,"REPORT.md")
    open(report_path,"w") do io
        println(io,"# Multi-asset jump experiment\n")
        println(io,"Frozen-fit comparison of three jump settings, each evaluated with paired naive and variance-corrected composition.\n")
        println(io,"## Findings for corrected composition\n")
        select_row(window,case) = only(eachrow(filter(r->r.window==window && r.scenario==case && r.method=="hybrid",summary)))
        for case in cases[2:3]
            tr,te = select_row("training",case),select_row("holdout_2025",case)
            btr,bte = select_row("training","off"),select_row("holdout_2025","off")
            dtr = 100*(tr.abs_acf_mae25/btr.abs_acf_mae25-1)
            dte = 100*(te.abs_acf_mae25/bte.abs_acf_mae25-1)
            @printf(io,"- **%s:** ACF25 error %s by %.2f%% in training and %s by %.2f%% in 2025. KS pass rates changed from %.2f%% to %.2f%% in training and from %.2f%% to %.2f%% in 2025.\n",
                case,dtr<0 ? "fell" : "rose",abs(dtr),dte<0 ? "fell" : "rose",abs(dte),
                100btr.ks_pass,100tr.ks_pass,100bte.ks_pass,100te.ks_pass)
        end
        corrected = filter(r->r.method=="hybrid",summary)
        @printf(io,"- Mean corrected variance divided by the active generator's variance ranges from %.5f to %.5f across the six setting/window combinations.\n",
            minimum(corrected.variance_ratio_generator),maximum(corrected.variance_ratio_generator))
        println(io,"\nThese results distinguish compatibility of jumps with variance correction from transfer of the SPY jump calibration. The Monte Carlo intervals and historical-data limitations below govern their interpretation.\n")
        println(io,"## Design\n")
        println(io,"- Cases: jumps off; SPY market jumps only; jumps in SPY and every asset generator.")
        println(io,"- Enabled models use epsilon = $(settings["epsilon"]), lambda = $(settings["lambda"]) trading days, negative-tail probability = $(settings["p_neg"]), and $(settings["n_tail"]) states per tail. These published SPY settings are transferred to the cached closing-price models, without per-ticker tuning.")
        println(io,"- All state partitions, transitions, emissions, SIM calibrations, and branch settings are frozen at the existing 2014-2024 fits. All 424 cached fits were checked to have jumps disabled before copying them.")
        println(io,"- $(settings["n_paths_per_seed"]) paths per seed, seeds $(join(settings["seeds"],", ")). Each ticker receives $(settings["n_paths_per_seed"]*length(settings["seeds"])) paths per setting and method.")
        println(io,"- Training comparison: 2,766 days; holdout: 249 days in 2025. All eligible non-market assets are included in each window.")
        println(io,"- SPY is simulated in both windows. This differs from the existing manuscript's in-sample table, which conditions on observed SPY. All three new settings use the same market-generation protocol.")
        println(io,"- One market path is shared across all assets in each replication. Naive and corrected methods receive exactly the same asset and market draws. The off and market-only cases reuse the no-jump asset draws; the market-only and market-plus-assets cases reuse the jump-enabled market draws.")
        println(io,"- Enabled and disabled models use separate RNG namespaces. Across jump settings, matching replication IDs do not imply identical innovations. Within each setting, the naive/corrected comparison is exactly paired.")
        println(io,"- The primary temporal metric is mean absolute error in the absolute-return ACF over lags 1-25; lags 1-60 are a secondary check. These are intentionally the same in both windows and differ from the manuscript's single-asset 252-lag score.")
        println(io,"- The main results include every simulated path. Jump-active strata are mechanism diagnostics, not replacements for unconditional results.")
        println(io,"- No copula reorder or joint residual dependence model is used.\n")
        println(io,"## Main results\n")
        println(io,"All entries below are equal-weight cross-ticker averages of per-path metrics. Variance ratios in this table are **means**, not the manuscript's cross-ticker medians. W1/SD divides each ticker's Wasserstein distance by its observed standard deviation.\n")
        println(io,"| Window | Jump setting | Composition | KS % | AD % | ACF MAE 25 | ACF MAE 60 | W1/SD | Variance / generator | Variance / observed | 99% exceedance % |")
        println(io,"|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
        for r in eachrow(summary)
            @printf(io,"| %s | %s | %s | %.2f | %.2f | %.5f | %.5f | %.4f | %.4f | %.4f | %.3f |\n",
                r.window,r.scenario,r.method,100r.ks_pass,100r.ad_pass,r.abs_acf_mae25,
                r.abs_acf_mae60,r.w1_standardized,r.variance_ratio_generator,r.variance_ratio_observed,100r.var99_rate)
        end
        println(io,"\n![Temporal fit and marginal tradeoff](jump-ablation-comparison.png)\n")
        println(io,"## Changes from jumps off, corrected composition\n")
        println(io,"Negative ACF differences indicate improved temporal fit. KS differences are percentage points. Intervals are approximate 95% **Monte Carlo** intervals conditional on these fitted models and observed histories. Replications, with all tickers kept together under their shared market path, are the uncertainty units; assets are not counted as independent market histories. These intervals do not quantify uncertainty across historical regimes, calibration samples, or future years.\n")
        println(io,"| Window | Change | Metric | Difference | MC interval |")
        println(io,"|---|---|---|---:|---:|")
        for r in eachrow(contrasts)
            if r.kind=="jump_setting" && endswith(r.changed,"/hybrid") &&
                r.metric in ["abs_acf_mae25","abs_acf_mae60","ks_pass"]
                scale = r.metric=="ks_pass" ? 100 : 1
                @printf(io,"| %s | %s | %s | %.5f | [%.5f, %.5f] |\n",
                    r.window,r.changed,r.metric,scale*r.mean_difference,scale*r.mc_low,scale*r.mc_high)
            end
        end
        println(io,"\nThe incremental effect of enabling asset jumps while retaining exactly the same jump-enabled market paths is reported separately:\n")
        println(io,"| Window | Composition | Metric | Difference | MC interval |")
        println(io,"|---|---|---|---:|---:|")
        for r in eachrow(incremental)
            if endswith(r.changed,"/hybrid") && r.metric in ["abs_acf_mae25","abs_acf_mae60","ks_pass"]
                scale = r.metric=="ks_pass" ? 100 : 1
                @printf(io,"| %s | corrected | %s | %.5f | [%.5f, %.5f] |\n",
                    r.window,r.metric,scale*r.mean_difference,scale*r.mc_low,scale*r.mc_high)
            end
        end
        println(io,"\n## Breadth across assets\n")
        println(io,"Fraction of tickers whose average metric improved versus jumps off. These are descriptive fractions, without per-ticker significance claims.\n")
        println(io,"| Window | Jump setting | Composition | Assets | ACF25 improved % | ACF60 improved % | KS improved % | W1 improved % |")
        println(io,"|---|---|---|---:|---:|---:|---:|---:|")
        for r in eachrow(breadth)
            @printf(io,"| %s | %s | %s | %d | %.1f | %.1f | %.1f | %.1f |\n",
                r.window,r.scenario,r.method,r.n_assets,100r.acf25_improved_fraction,
                100r.acf60_improved_fraction,100r.ks_improved_fraction,100r.w1_improved_fraction)
        end
        println(io,"\n## Episode frequency and marginal-generator check\n")
        println(io,"| Window | Enabled component | Paths | Paths with episodes % | Forced steps % | ACF25 error before composition |")
        println(io,"|---|---|---:|---:|---:|---:|")
        for window in windows
            for enabled in (false,true)
                m = filter(r->r.window==window && r.enabled==enabled,market)
                @printf(io,"| %s | Market (%s) | %d | %.2f | %.3f | %.5f |\n",
                    window,enabled ? "on" : "off",nrow(m),100mean(m.jump_active),
                    100mean(m.forced_fraction),mean(m.abs_acf_mae25))
                g = filter(r->r.window==window && r.enabled==enabled,generator)
                @printf(io,"| %s | Assets (%s) | %d | %.2f | %.3f | %.5f |\n",
                    window,enabled ? "on" : "off",sum(g.n_paths),100mean(g.jump_active_rate),
                    100mean(g.forced_fraction),mean(g.abs_acf_mae25))
            end
        end
        println(io,"\n## Interpretation limits\n")
        println(io,"- Shared settings test transfer from SPY, not per-asset optimality. The SPY paper used VWAP prices; this composition study retains its existing closing-price fits.")
        println(io,"- ACF improvement and marginal fit must be assessed jointly. Adding jumps can change a generator's own variance and kurtosis; preserving that generator variance does not mean preserving the no-jump or observed variance.")
        println(io,"- Tracker and clipping branches remain active. Tracker paths target calibrated R-squared rather than generator variance; finite paths also retain sample market-asset cross-covariance.")
        println(io,"- KS/AD non-rejection is descriptive because the samples are temporally dependent. A high pass rate does not certify a correct distribution.")
        println(io,"- The 2025 holdout is short, and rare market episodes have limited Monte Carlo representation. VaR rates here use pathwise unconditional quantiles, not a rolling conditional risk forecast.")
        println(io,"- Improved per-asset temporal metrics do not establish portfolio covariance or joint tail fidelity. Independent asset episodes do not restore missing residual dependence.\n")
        println(io,"## Reproduction and artifacts\n")
        println(io,"Run from the repository root:\n\n```sh\njulia --project=code/downstream-evaluation --threads=8 code/downstream-evaluation/scripts/11-Jump-Ablation.jl\njulia --project=code/downstream-evaluation code/downstream-evaluation/scripts/11b-Jump-Ablation-Report.jl\njulia --project=code/downstream-evaluation code/downstream-evaluation/test/jump_ablation.jl\n```\n")
        println(io,"`settings.toml` records settings and SHA-256 fingerprints of input caches, holdout data, code, simulator, and Manifest. Completed seed/window blocks are resumable only with matching settings and fingerprints. Per-path scores are reduced to ticker, market-replication, generator, and jump-stratum summaries; trajectories and individual asset-path scores are reproducible from the seeds but are not retained. `paired-contrasts.csv` contains all differences, including correction versus naive composition. `ticker-metrics.csv` also includes branch frequencies and medians within each ticker/seed batch. Original manuscript tables and model caches are not overwritten.")
    end
    @info "Jump-ablation report written" report_path
end

if abspath(PROGRAM_FILE)==@__FILE__
    settings = TOML.parsefile(joinpath(_ROOT,"jump-ablation.toml"))
    jump_ablation_report(joinpath(_ROOT,settings["output_directory"]))
end
