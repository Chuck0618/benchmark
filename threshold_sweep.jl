using NTL
using Random
using Statistics
using Printf

function measure(fn, trials=11)
    fn()
    times = Vector{Float64}(undef, trials)
    for i in 1:trials
        times[i] = @elapsed fn()
    end
    median(times) * 1e6
end

function test_case(F, d, kind, rng)
    x = xpoly(F)
    if kind == :irreducible
        f = BuildIrred(F, d; rng=rng)
    elseif kind == :repeated
        f = (x + 1)^d
    elseif kind == :distinct
        f = BuildFromRoots(F, collect(0:(d - 1)))
    else
        f = random_poly(F, d + 1; rng=rng) + LeftShift(poly(F, 1), d)
    end

    fast = NTL.factor(f; rng=MersenneTwister(2026))
    generic = NTL._factor_generic(f, MersenneTwister(2026))
    @assert NTL.reconstruct(fast) == f
    @assert NTL.reconstruct(generic) == f

    fast_us = measure(() -> NTL.factor(f; rng=MersenneTwister(2026)))
    generic_us = measure(() -> NTL._factor_generic(f, MersenneTwister(2026)))
    fast_us, generic_us
end

function main()
    println("p,d,kind,generic_us,specialized_us,specialized_over_generic")
    for p in (31, 61, 101, 127), d in (4, 8, 12, 16), kind in (:distinct, :repeated, :irreducible, :random)
        F = PrimeField(p)
        rng = MersenneTwister(1000p + d)
        generic_us, fast_us = test_case(F, d, kind, rng)
        ratio = fast_us / generic_us
        @printf("%d,%d,%s,%.3f,%.3f,%.3f\n", p, d, kind, generic_us, fast_us, ratio)
    end
end

main()
