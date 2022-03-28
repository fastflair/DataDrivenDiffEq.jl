mutable struct OptimizerState{T, P}
    error::T
    sparsity::T

    pareto::Function

    abstol::T
    reltol::T
    converged::Bool
    iters::Int
    maxiters::Int
    verbose::Bool
    show_progress::Bool
    progress::P
end

function init_progress(opt::AbstractOptimizer, maxiters)
    Progress(
        maxiters .* length(get_threshold(opt)), desc = summary(opt), dt = 1.0
    )
end

function OptimizerState(opt::AbstractOptimizer{T};
    abstol = 10*eps(eltype(T)), reltol = 10*eps(eltype(T)), 
    maxiters = 1_000, verbose = false, 
    show_progress = false, f = F(opt), g = G(opt), kwargs...) where T

    fg = (x, A, y, lambda) -> let g = g, f = f
        (g∘f)(x, A, y, lambda)
    end
    
    progress = show_progress ? init_progress(opt, maxiters) : nothing

    return OptimizerState{eltype(T), typeof(progress)}(
        convert(eltype(T), Inf), convert(eltype(T), Inf), fg, abstol, reltol, 
        false, 0, maxiters, verbose, show_progress, progress
    )
end

function reset!(s::OptimizerState{T}) where T
    s.error = convert(T, Inf)
    s.sparsity = convert(T, Inf)
    s.converged = false
    s.iters = 0
    return 
end

function cleanup!(s::OptimizerState)
    if s.show_progress 
        ProgressMeter.finish!(s.progress)
    end
    return
end

increment!(s::OptimizerState) = s.iters += 1

@views set_metrics!(s::OptimizerState, A, x, b, λ = zero(eltype(x))) = begin
    s.error = norm(A*x-b, 2)
    s.sparsity = sum(abs.(x) .> λ)
    return 
end

@views is_convergend!(s::OptimizerState, x, x_prev)::Bool = begin
    if s.iters > 1 
        if norm(x .- x_prev, 2) <= s.abstol 
            s.converged = true
        else
            s.converged = false
        end
    end
    return s.converged
end

is_runable(s::OptimizerState)::Bool = begin
    s.converged && return false 
    s.sparsity < 1 && return false
    return s.iters <= s.maxiters
end

@views function eval_pareto!(cache, s::OptimizerState, A, Y, λ)
    X = cache.X_prev
    X̂ = cache.X_opt
    for i in axes(Y, 2)
        # We do not want zeros
        all(X[:, i] .≈ zero(λ)) && continue
        if s.pareto(X[:, i], A, Y[:, i], λ) < s.pareto(X̂[:, i], A, Y[:,i], λ)
            cache.X_opt[:, i] .=  X[:,i]
            cache.λ_opt[i] = λ
        end
    end
end

function Base.print(io::IO, s::OptimizerState{T}, λ::T = zero(T)) where T
    if s.show_progress 
        ProgressMeter.next!(
            s.progress;
            showvalues = [
                (:Threshold, λ), (:Objective, s.error), (:Sparsity, s.sparsity)
            ]
            )
        return
    end
    
    !s.verbose && return
    
    s.iters <= 1 && begin
        @printf io " Iter    Threshold          Error         Sparsity\n"
        @printf io "------ -------------- -------------- --------------\n"
    end

    @printf io "%6d %14e %14e %14e\n" s.iters λ s.error s.sparsity
    return 
end
