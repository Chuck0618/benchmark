using NTL
using Statistics

# Accumulate a bounded block of canonical residues exactly before reducing.
function blocksum(xs::AbstractVector{PrimeField{P}}) where {P}
    safe_count = typemax(UInt) ÷ UInt(P - 1)
    block = Int(min(safe_count, UInt(65536)))
    acc = zero(PrimeField{P})
    for indices in Iterators.partition(eachindex(xs), block)
        total = zero(UInt)
        @inbounds for i in indices
            total += UInt(rep(xs[i]))
        end
        acc += PrimeField{P}(Int(total % UInt(P)))
    end
    acc
end

function serialsum(xs::Vector{T}) where {T<:PrimeField}
    value = zero(T)
    for x in xs
        value += x
    end
    value
end

function demo(p)
    F = PrimeField(p)
    xs = [F(mod(1234567 * i, p)) for i in 1:200000]
    reference = Int(mod(sum(x -> big(rep(x)), xs), p))
    for f in (serialsum, blocksum)
        @assert rep(f(xs)) == reference
        t = Float64[]
        for _ in 1:31
            start = time_ns()
            value = f(xs)
            push!(t, (time_ns() - start) / length(xs))
            @assert rep(value) == reference
        end
        println(f, ",", p, ",", median(t), ",", reference)
    end
end

abspath(PROGRAM_FILE) == (@__FILE__) && demo(1_000_000_007)
