using NTL
using Statistics

# Dispatch once on the concrete element type before entering a hot loop.
Base.@noinline function affine_chain(a::T, b::T, iterations::Int, ::Val{fused}) where {T<:PrimeField,fused}
    acc = one(a)
    for _ in 1:iterations
        acc = fused ? muladd(acc, a, b) : acc * a + b
    end
    acc
end

# A mutable GMP accumulator is useful for batch work over one large modulus.
# Source values are read-only and the accumulator is local to this call.
function bigmod_sum(A::Vector{ModInt}, iterations::Int)
    isempty(A) && throw(ArgumentError("expected at least one element"))
    iterations >= 0 || throw(ArgumentError("iterations must be nonnegative"))
    F = parent(first(A))
    all(x -> parent(x) == F, A) || throw(ArgumentError("modulus mismatch"))
    p = modulus(F)
    acc = rep(one(F))
    for i in 0:(iterations - 1)
        value = rep(A[mod(i, length(A)) + 1])
        Base.GMP.MPZ.add!(acc, acc, value)
        acc >= p && Base.GMP.MPZ.sub!(acc, acc, p)
    end
    F(acc)
end

function median_ms(work)
    expected = work()
    work()
    results = Vector{typeof(expected)}(undef, 31)
    times = [@elapsed(results[i] = work()) for i in eachindex(results)]
    @assert all(==(expected), results)
    1e3 * median(times)
end

function main()
    F = PrimeField(1_000_000_007)
    a, b = F(123456789), F(987654321)
    for (label, mode) in (("typed_separate", Val(false)), ("typed_fused", Val(true)))
        affine_work = () -> affine_chain(a, b, 1_000_000, mode)
        @assert rep(affine_work()) == 410346119
        println(label, "_ms=", median_ms(affine_work))
    end

    R = BigModRing(big(2)^127 - 1)
    A = R.([mod(big(1) << i, modulus(R)) for i in 0:1023])
    scratch_work = () -> bigmod_sum(A, 200_000)
    expected = mod(1 + sum(rep(A[i % length(A) + 1]) for i in 0:199_999), modulus(R))
    @assert rep(scratch_work()) == expected
    println("scratch_add_ms=", median_ms(scratch_work))
end

main()
