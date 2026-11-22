using NTL, Statistics, Random, Test

function runfactor(f, newrng, expected)
    rng = MersenneTwister(2026)
    work() = NTL.factor(f; rng=newrng ? MersenneTwister(2026) : rng)
    times = Float64[]
    for i in 0:31
        start = time_ns()
        fac = work()
        elapsed = time_ns() - start
        @assert reconstruct(fac) == f
        @assert all(pair -> pair in expected, fac.factors)
        @assert length(fac.factors) == length(expected)
        i > 0 && push!(times, elapsed/1000)
    end
    median(times)
end

function demo()
    F = PrimeField(101)
    x = xpoly(F)
    f = (x+1)^2*(x+2)*(x^2+x+1)*(x^3+2x+1)
    expected = NTL.factor(f; rng=MersenneTwister(111)).factors
    @assert all(pair -> is_irreducible(first(pair)), expected)
    for (label, g, factors) in (("repo", f, expected), ("linear", F(7)*(x+2)^5*(x+3)^3, [(x+2,5),(x+3,3)]), ("quadratic", x^2+2, [(x^2+2,1)]))
        for fresh in (true,false)
            println(label,",",fresh,",",runfactor(g, fresh, factors))
        end
    end
end
abspath(PROGRAM_FILE) == (@__FILE__) && demo()
