# Figure 4 uses per-draw generator variances recovered by the checked replay.
function write_preservation_figure(summary,metadata)
    background = colorant"#f2f2f2"
    colors = Dict("naive"=>colorant"#1d3557", "hybrid"=>colorant"#e63946")
    ordinary = summary[summary.branch .!= "R2_PRESERVE",:]
    trackers = summary[summary.branch .== "R2_PRESERVE",:]
    bandwidth = metadata["smoothing_bandwidth"]
    n_grid = metadata["smoothing_grid_points"]
    panels = []
    curves = DataFrame(panel=String[],composer=String[],beta=Float64[],value=Float64[])
    function smooth!(plot,rows,ycol,panel,method;style=:solid,width=2.5)
        x,y = rows.beta_cal,rows[!,ycol]
        grid = collect(range(minimum(x),maximum(x);length=n_grid))
        values = [_weighted_median(y,exp.(-((x.-g).^2)./(2*bandwidth^2))) for g in grid]
        plot!(plot,grid,values;label=nothing,color=colors[method],ls=style,lw=width)
        append!(curves,DataFrame(panel=fill(panel,n_grid),composer=fill(method,n_grid),beta=grid,value=values))
    end
    for (panel,title,ylabel,ycol) in (
        ("a","(a) Marginal fit","KS pass fraction",:ks_pass),
        ("b","(b) Generator-variance ratio","Median variance ratio",:ratio_generator))
        p = plot(;title,xlabel="Calibrated β",ylabel,
            legend=panel=="a" ? :topright : :topleft,
            bg=background,background_color_outside=:white,
            framestyle=:box,fontfamily="sans-serif",gridalpha=0.20,
            titlefontsize=14,guidefontsize=12,tickfontsize=10,legendfontsize=10,
            foreground_color_legend=:transparent)
        panel=="a" && ylims!(p,(-0.03,1.08))
        for method in ("naive","hybrid")
            rows = ordinary[ordinary.composer .== method,:]
            scatter!(p,rows.beta_cal,rows[!,ycol];
                label=panel=="a" ? uppercasefirst(method) : nothing,
                color=colors[method],marker=method=="naive" ? :circle : :diamond,
                markersize=3.2,alpha=0.45,markerstrokewidth=0)
            if panel=="a"
                smooth!(p,rows,ycol,panel,method)
            end
            selected = trackers[trackers.composer .== method,:]
            scatter!(p,selected.beta_cal,selected[!,ycol];label=nothing,
                color=colors[method],marker=:circle,markersize=5.5,
                markerstrokecolor=:black,markerstrokewidth=0.6)
        end
        if panel=="b"
            # Use each paired draw's generator denominator. The dotted curve
            # summarizes ticker-specific 1+rho, not an invented median asset.
            rows = ordinary[ordinary.composer .== "naive",:]
            smooth!(p,rows,:reference_generator,"b_reference","naive";style=:dot,width=2.5)
            plot!(p,[NaN],[NaN];color=colors["naive"],ls=:dot,lw=2.5,
                label="Naive reference (1 + ρ)")
            hline!(p,[1.0];label="Hybrid target (421 assets)",color=colors["hybrid"],ls=:dash,lw=2)
            scatter!(p,[NaN],[NaN];marker=:circle,color=:white,markerstrokecolor=:black,
                markersize=5.5,label="Trackers: QQQ, SPYG")
            # Include every point and leave room for the independently labeled
            # tracker cases; no variance ratio is clipped by the display.
            ylims!(p,(minimum(summary.ratio_generator)-0.07,maximum(summary.ratio_generator)+0.12))
        end
        push!(panels,p)
    end
    figure = plot(panels...;layout=(1,2),size=(1200,460),
        left_margin=9Plots.mm,right_margin=3Plots.mm,bottom_margin=9Plots.mm,top_margin=4Plots.mm)
    repo = abspath(joinpath(_ROOT,"..",".."))
    first_path = joinpath(repo,"arxiv-paper","figs","main","Fig06-Variance-Preservation.pdf")
    savefig(figure,first_path)
    second_path = joinpath(repo,"jfds-paper","figs","main","Fig06-Variance-Preservation.pdf")
    cp(first_path,second_path;force=true)
    output = joinpath(_ROOT,"results","variance-diagnostic")
    CSV.write(joinpath(output,"figure-curves.csv"),curves)
    figure_metadata = Dict("diagnostic_metadata_sha256"=>training_hash(joinpath(output,"metadata.toml")),
        "source_sha256"=>Dict(p=>training_hash(joinpath(_ROOT,p)) for p in
            ("scripts/05-Figures.jl","src/PreservationFigure.jl")),
        "curve_sha256"=>training_hash(joinpath(output,"figure-curves.csv")),
        "figure_sha256"=>training_hash(first_path),"ordinary_assets"=>length(unique(ordinary.ticker)),
        "tracker_assets"=>sort(unique(trackers.ticker)))
    open(joinpath(output,"figure-metadata.toml"),"w") do io
        TOML.print(io,figure_metadata;sorted=true)
    end
    @info "Wrote Figure 4 in arXiv and JFDS" ordinary_assets=length(unique(ordinary.ticker)) trackers=unique(trackers.ticker)
end
