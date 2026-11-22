using NTL
using Random

const BITS = (8, 16, 24, 31, 32, 48, 63, 64, 96, 127, 128, 256, 512, 1024)
const OUTPUT = length(ARGS) >= 1 ? ARGS[1] : "primes.csv"

open(OUTPUT, "w") do io
    println(io, "bits,case,p")
    for bits in BITS
        seen = Set{BigInt}()
        for case_id in 1:2
            rng = MersenneTwister(20261122 + 100bits + case_id)
            p = GenPrime(bits; rng=rng)
            while p in seen
                p = GenPrime(bits; rng=rng)
            end
            push!(seen, p)
            @assert ndigits(p, base=2) == bits
            @assert ProbPrime(p; rounds=32)
            println(io, bits, ",", case_id, ",", p)
        end
    end
end
println("Generated 28 random prime cases in ", OUTPUT)
