# Simple ridge regression based upon the sindy-mpc
# repository, see https://arxiv.org/abs/1711.05501
# and https://github.com/eurika-kaiser/SINDY-MPC/blob/master/LICENSE

mutable struct STRRidge{T} <: AbstractOptimiser
    ε::T
end

STRRidge() = STRRidge(0.1)

init(o::STRRidge, A::AbstractArray, Y::AbstractArray) = A \ Y

function fit!(X::AbstractArray, A::AbstractArray, Y::AbstractArray, o::STRRidge; maxiter::Int64 = 1)
    smallinds = abs.(X) .<= o.ε
    biginds = @. ! smallinds[:, 1]
    for i in 1:maxiter
        smallinds = abs.(X) .<= o.ε
        X[smallinds] .= zero(eltype(X))
        for j in 1:size(Y, 2)
            biginds = @. ! smallinds[:, j]
            X[biginds, j] = A[:, biginds] \ Y[:,j]
        end
    end
    return
end