# GARCH(1,1)-t fitting and cache validation for the residual benchmark.
import ARCHModels
import SHA

const GARCH_CACHE_SCHEMA = 1

garch_coefficient_hash(model) = bytes2hex(SHA.sha256(reinterpret(UInt8, Float64.(ARCHModels.coef(model)))))

"""
    fit_garch_with_diagnostics(residuals; kwargs...) -> (model, optimizer)

Use the pinned ARCHModels likelihood, starting values, BFGS algorithm, and
forward differentiation. Its public `fit` discards the Optim result, so this
narrow adapter retains it for an explicit convergence check. The regression
test compares its coefficients with `ARCHModels.fit` on real residuals.
"""
function fit_garch_with_diagnostics(residuals::AbstractVector{<:Real}; options=ARCHModels.Optim.Options())
    e = Float64.(residuals)
    length(e) > 1 && all(isfinite, e) && isfinite(var(e)) && var(e) > 0 ||
        throw(ArgumentError("GARCH residuals must be finite and nonconstant"))
    ms = ARCHModels.NoIntercept{Float64}()
    initial = vcat(ARCHModels.startingvals(ARCHModels.GARCH{1,1}, e),
                   ARCHModels.startingvals(ARCHModels.StdT, e))
    objective = x -> -ARCHModels.loglik(ARCHModels.GARCH{1,1}, ARCHModels.StdT,
                                      ms, e, x, trues(3), true)
    result = ARCHModels.Optim.optimize(objective, initial, ARCHModels.Optim.BFGS(), options;
                                      autodiff=:forward)
    fitted = ARCHModels.Optim.minimizer(result)
    model = ARCHModels.UnivariateARCHModel(ARCHModels.GARCH{1,1}(fitted[1:3]), e;
        dist=ARCHModels.StdT(fitted[4:4]), meanspec=ms, fitted=true)
    return model, result
end

"""
    check_garch_model(model; trial_length=0, seed=1234)

Require finite coefficients, positive variance intercept, nonnegative ARCH
and GARCH terms, persistence below one, Student-t degrees of freedom above
two, and finite positive unconditional variance. Optionally simulate a finite,
nonconstant trial using a private RNG, leaving evaluation draws unchanged.
This checks the model; optimizer convergence is checked separately at fitting.
"""
function check_garch_model(model; trial_length::Int=0, seed::Int=1234)
    trial_length >= 0 || throw(ArgumentError("trial_length must be nonnegative"))
    blank = (valid=false, reason="unsupported GARCH model specification",
             omega=NaN, garch_beta=NaN, arch_alpha=NaN, nu=NaN,
             persistence=NaN, unconditional_variance=NaN, trial_checked=false)
    model isa ARCHModels.UnivariateARCHModel &&
        model.spec isa ARCHModels.GARCH{1,1} &&
        model.dist isa ARCHModels.StdT &&
        model.meanspec isa ARCHModels.NoIntercept || return blank
    # ARCHModels stores the volatility coefficients in omega, beta, alpha order.
    omega, beta, alpha = model.spec.coefs
    nu = only(model.dist.coefs)
    persistence = alpha + beta
    unconditional_variance = omega / (1 - persistence)
    details = merge(blank, (; omega, garch_beta=beta, arch_alpha=alpha, nu,
                             persistence, unconditional_variance))
    reason = if !all(isfinite, (omega, beta, alpha, nu))
        "nonfinite coefficient"
    elseif omega <= 0 || beta < 0 || alpha < 0
        "inadmissible variance coefficients"
    elseif persistence >= 1
        "nonstationary: ARCH plus GARCH persistence must be below one"
    elseif nu <= 2
        "Student-t degrees of freedom must exceed two"
    elseif !isfinite(unconditional_variance) || unconditional_variance <= 0
        "unconditional variance must be finite and positive"
    else
        ""
    end
    isempty(reason) || return merge(details, (; reason))
    if trial_length > 0
        try
            simulate_garch_residual(model, trial_length; rng=MersenneTwister(seed))
        catch err
            err isa InterruptException && rethrow()
            return merge(details, (reason="trial simulation failed: " * sprint(showerror, err),))
        end
    end
    return merge(details, (valid=true, reason="accepted", trial_checked=trial_length > 0))
end

function simulate_garch_residual(model, n::Int; rng=Random.default_rng())
    draw = Float64.(ARCHModels.simulate(model, n; rng).data)
    length(draw) == n && all(isfinite, draw) || error("GARCH simulation returned a nonfinite or incomplete path")
    n <= 1 || (isfinite(var(draw)) && var(draw) > 0) || error("GARCH simulation variance is not finite and positive")
    return draw
end

"""Fit one ticker and retain both acceptance and exclusion diagnostics."""
function fit_checked_garch(residuals; ticker::String, seed::Int=1234, kwargs...)
    row = (ticker=ticker, accepted=false, reason="", converged=false,
           iterations=0, objective=NaN, gradient_residual=NaN,
           omega=NaN, garch_beta=NaN, arch_alpha=NaN, nu=NaN,
           persistence=NaN, unconditional_variance=NaN, trial_checked=false,
           coefficient_sha256="")
    try
        model, optimizer = fit_garch_with_diagnostics(residuals; kwargs...)
        check = check_garch_model(model; trial_length=length(residuals), seed)
        converged = ARCHModels.Optim.converged(optimizer)
        objective = ARCHModels.Optim.minimum(optimizer)
        accepted = converged && isfinite(objective) && check.valid
        reason = !converged ? "optimizer did not converge" :
                 !isfinite(objective) ? "nonfinite optimizer objective" : check.reason
        row = merge(row, (; accepted, reason, converged, objective,
            iterations=ARCHModels.Optim.iterations(optimizer),
            gradient_residual=ARCHModels.Optim.g_residual(optimizer),
            omega=check.omega, garch_beta=check.garch_beta, arch_alpha=check.arch_alpha,
            nu=check.nu, persistence=check.persistence,
            unconditional_variance=check.unconditional_variance,
            trial_checked=check.trial_checked, coefficient_sha256=garch_coefficient_hash(model)))
        return accepted ? model : nothing, row
    catch err
        err isa InterruptException && rethrow()
        return nothing, merge(row, (reason="fit failed: " * sprint(showerror, err),))
    end
end

"""
Load only a cache with matching acceptance records. Legacy or inconsistent
caches fail before evaluation starts; rerun 01c-Fit-GARCH.jl --refit to replace
them. Every accepted model is checked again with a trial at the scoring horizon.
"""
function load_validated_garch_models(path; trial_length::Int, seed::Int=1234)
    cache = load(path)
    repair = "Rebuild with scripts/01c-Fit-GARCH.jl --refit."
    haskey(cache, "metadata") && get(cache["metadata"], "schema", 0) == GARCH_CACHE_SCHEMA &&
        haskey(cache, "diagnostics") || error("GARCH cache lacks acceptance diagnostics. $repair")
    models, diagnostics = cache["models"], cache["diagnostics"]
    nrow(diagnostics) == length(unique(diagnostics.ticker)) || error("Duplicate GARCH acceptance records. $repair")
    accepted = filter(r -> r.accepted, diagnostics)
    Set(keys(models)) == Set(accepted.ticker) || error("GARCH models disagree with eligibility records. $repair")
    for row in eachrow(accepted)
        model = models[row.ticker]
        row.converged && isfinite(row.objective) && row.trial_checked &&
            row.coefficient_sha256 == garch_coefficient_hash(model) ||
            error("GARCH acceptance record is invalid for $(row.ticker). $repair")
        check = check_garch_model(model; trial_length, seed)
        check.valid || error("GARCH model $(row.ticker): $(check.reason). $repair")
    end
    return models
end
