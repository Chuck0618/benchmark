using NTL
using Random
using Statistics

const OUTPUT = length(ARGS) >= 1 ? ARGS[1] : "results-workloads-ntl.csv"
const REPS = 31

function measure(name, backend, note, fn)
    checksum = fn() # Warm-up and JIT compilation are excluded.
    times = Vector{Float64}(undef, REPS)
    for i in 1:REPS
        times[i] = @elapsed checksum = fn()
    end
    ms = 1000 * median(times)
    println(name, " ", ms, " ms")
    ms, checksum
end

function record(fn::Function, io, name, package, backend, note)
    ms, checksum = measure(name, backend, note, fn)
    println(io, join((name, package, backend, ms, checksum, REPS, note), ','))
    flush(io)
end

# Specialize once on the field chosen at runtime, before entering the loop.
function affine_chain(a::T, b::T, iterations::Int) where {T<:PrimeField}
    c = one(a)
    for _ in 1:iterations
        c *= a
        c += b
    end
    c
end

open(OUTPUT, "w") do io
    println(io, "workload,package,backend,ms,checksum,trials,note")

    F = PrimeField(1000000007)
    a, b = F(123456789), F(987654321)
    record(io, "small_modmul", "NTL.jl", "PrimeField", "1e6 mul+add; input construction excluded") do
        string(rep(affine_chain(a, b, 1_000_000)))
    end

    n = big(2)^521 - 1
    BF = BigModRing(n)
    big_a = BF(123456789)
    record(io, "big_modpow", "NTL.jl", "BigModRing", "p=2^521-1; exponent=1000000") do
        r = power(big_a, 1000000)
        string(rep(r))
    end

    P = PrimeField(101)
    ac = [(i + 1) % 101 for i in 0:999]
    bc = [(2i + 3) % 101 for i in 0:999]
    pa, pb = poly(P, ac), poly(P, bc)
    record(io, "polynomial_mul", "NTL.jl", "ModPoly", "degree 999 inputs; deterministic coefficients") do
        c = pa * pb
        string(NTL.degree(c) + rep(NTL.coeff(c, 123)))
    end

    NF = PrimeField(998244353)
    na = NF.([(i + 1) % 101 for i in 0:4095])
    nb = NF.([(2i + 3) % 101 for i in 0:4095])
    record(io, "ntt_convolve", "NTL.jl", "radix-two NTT", "4096 coefficients per input; linear convolution") do
        c = ntt_convolve(na, nb)
        string(length(c) + rep(c[457]))
    end

    x = xpoly(P)
    f = (x + 1)^2 * (x + 2) * (x^2 + x + 1) * (x^3 + 2x + 1)
    factor_probe = NTL.factor(f; rng=MersenneTwister(2026))
    @assert NTL.reconstruct(factor_probe) == f
    record(io, "factorization", "NTL.jl", "Cantor-Zassenhaus", "fixed degree-7 factorization input; reconstruction checked outside timing") do
        fac = NTL.factor(f; rng=MersenneTwister(2026))
        string(length(fac.factors))
    end

    MF = PrimeField(1000000007)
    matrix_n = 40
    A = [i == j ? MF(1) : MF((i + j - 2) % 7) for i in 1:matrix_n, j in 1:matrix_n]
    record(io, "determinant", "NTL.jl", "generic field fallback", "40x40; p=1000000007") do
        string(rep(det(A)))
    end

    lattice_n = 12
    B = [BigInt(j <= i ? i * (j + 1) % 17 : 0) for i in 1:lattice_n, j in 1:lattice_n]
    for i in 1:lattice_n
        B[i, i] = i + 1
    end
    default_lll_probe = lll(B)
    @assert default_lll_probe.transform * B == default_lll_probe.basis
    @assert abs(det_exact(default_lll_probe.transform)) == 1
    @assert default_lll_probe.verified
    record(io, "lll", "NTL.jl", "fast LLL + exact verification", "12x12; includes exact post-verification") do
        result = lll(B)
        result.verified ? "verified" : "unverified"
    end
    reduce_probe = lll(B; verify=false)
    @assert reduce_probe.transform * B == reduce_probe.basis
    @assert abs(det_exact(reduce_probe.transform)) == 1
    record(io, "lll_reduce_only", "NTL.jl", "fast LLL without exact verification", "12x12; verify=false; structural identities checked outside timing") do
        result = lll(B; verify=false)
        "exact-verification-disabled"
    end

    prime_n = big(2)^61 - 1
    record(io, "probprime", "NTL.jl", "deterministic Int witnesses", "200 calls; deterministic witnesses; p=2^61-1") do
        count = 0
        for _ in 1:200
            count += ProbPrime(prime_n)
        end
        string(count)
    end


end
println("Wrote ", OUTPUT)
