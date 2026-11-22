using NTL
using GaloisFields
using Polynomials
using Random
using Statistics

const OUTPUT = length(ARGS) >= 1 ? ARGS[1] : "results-workloads-julia.csv"
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

function record(fn::Function, io, name, package, backend, note; p="")
    ms, checksum = measure(name, backend, note, fn)
    println(io, join((name, package, backend, p, ms, checksum, REPS, note), ','))
    flush(io)
end

open(OUTPUT, "w") do io
    println(io, "workload,package,backend,p,ms,checksum,trials,note")

    F = PrimeField(1000000007)
    a, b = F(123456789), F(987654321)
    record(io, "small_modmul", "NTL.jl", "PrimeField", "1e6 mul+add; input construction excluded") do
        c = one(F)
        for _ in 1:1000000
            c *= a
            c += b
        end
        string(rep(c))
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

    # Random small-prime comparison: the same eight primes are used for every
    # workload and both packages. Seven-bit primes also keep p^2 below the
    # current Zech table limit.
    prime_rng = MersenneTwister(20261122)
    small_primes = Int[]
    while length(small_primes) < 8
        q = Int(GenPrime(7; rng=prime_rng))
        q in small_primes || push!(small_primes, q)
    end
    println("Random 7-bit prime set: ", small_primes)

    for p in small_primes
        SP = PrimeField(p)
        G = GaloisField(p)
        sa, sb = SP(123456789), SP(987654321)
        ga, gb = G(123456789), G(987654321)

        record(io, "prime_muladd_separate", "NTL.jl", "PrimeField", "1e6 separate multiply-add; random 7-bit prime set"; p=p) do
            c = one(SP)
            for _ in 1:1000000
                c *= sa
                c += sb
            end
            string(rep(c))
        end
        record(io, "prime_muladd_separate", "GaloisFields.jl", "PrimeField", "1e6 separate multiply-add; random 7-bit prime set"; p=p) do
            c = one(G)
            for _ in 1:1000000
                c *= ga
                c += gb
            end
            string(Integer(c))
        end

        record(io, "prime_muladd_fused", "NTL.jl", "fused muladd", "1e6 fused multiply-add; random 7-bit prime set"; p=p) do
            c = one(SP)
            for _ in 1:1000000
                c = Base.muladd(c, sa, sb)
            end
            string(rep(c))
        end
        record(io, "prime_muladd_fused", "GaloisFields.jl", "generic muladd", "1e6 generic multiply-add; random 7-bit prime set"; p=p) do
            c = one(G)
            for _ in 1:1000000
                c = Base.muladd(c, ga, gb)
            end
            string(Integer(c))
        end

        sx, gx = SP(3), G(3)
        @assert sx * inv(sx) == one(SP)
        @assert gx * inv(gx) == one(G)
        record(io, "prime_power_1000", "NTL.jl", "PrimeField", "10000 powers; exponent=1000; random 7-bit prime set"; p=p) do
            v = [sx^1000 for _ in 1:10000]
            string(rep(v[end]))
        end
        record(io, "prime_power_1000", "GaloisFields.jl", "PrimeField", "10000 powers; exponent=1000; random 7-bit prime set"; p=p) do
            v = [gx^1000 for _ in 1:10000]
            string(v[end])
        end
        record(io, "prime_inverse", "NTL.jl", "PrimeField", "10000 inversions; random 7-bit prime set"; p=p) do
            v = [inv(sx) for _ in 1:10000]
            string(rep(v[end]))
        end
        record(io, "prime_inverse", "GaloisFields.jl", "PrimeField", "10000 inversions; random 7-bit prime set"; p=p) do
            v = [inv(gx) for _ in 1:10000]
            string(v[end])
        end

        EF = PrimeField(p)
        E = extension_field(EF, BuildIrred(EF, 2; rng=MersenneTwister(p)))
        Z = zech_field(E)
        z = ZechElem(Z, Z._generator)
        e = extension_element(z)
        GG, beta = GaloisField(p, 2, :β)

        ordinary = e
        fast = z
        for _ in 1:10000
            ordinary = ordinary * e + one(ordinary)
            fast = fast * z + one(fast)
        end
        @assert extension_element(fast) == ordinary
        @assert extension_element(inv(z)) == inv(e)
        @assert extension_element(z^100) == e^100

        record(io, "zech_extension_ops", "NTL.jl", "ZechElem", "10000 extension multiply-add steps; random quadratic base primes"; p=p) do
            y = z
            for _ in 1:10000
                y = y * z + one(y)
            end
            string(rep(y))
        end
        record(io, "zech_extension_ops", "GaloisFields.jl", "ExtensionField", "10000 extension multiply-add steps; random quadratic base primes"; p=p) do
            y = beta
            for _ in 1:10000
                y = y * beta + one(y)
            end
            string(y)
        end

        record(io, "zech_muladd", "NTL.jl", "Zech muladd", "10000 fused extension multiply-add steps; random quadratic base primes"; p=p) do
            y = z
            for _ in 1:10000
                y = Base.muladd(y, z, one(y))
            end
            string(rep(y))
        end
        record(io, "zech_muladd", "GaloisFields.jl", "generic muladd", "10000 generic extension multiply-add steps; random quadratic base primes"; p=p) do
            y = beta
            for _ in 1:10000
                y = Base.muladd(y, beta, one(y))
            end
            string(y)
        end

        record(io, "zech_inverse", "NTL.jl", "ZechElem", "10000 extension inversions; random quadratic base primes"; p=p) do
            v = [inv(z) for _ in 1:10000]
            string(rep(v[end]))
        end
        record(io, "zech_inverse", "GaloisFields.jl", "ExtensionField", "10000 extension inversions; random quadratic base primes"; p=p) do
            v = [inv(beta) for _ in 1:10000]
            string(v[end])
        end
        record(io, "zech_power", "NTL.jl", "ZechElem", "10000 extension powers; exponent=100; random quadratic base primes"; p=p) do
            v = [z^100 for _ in 1:10000]
            string(rep(v[end]))
        end
        record(io, "zech_power", "GaloisFields.jl", "ExtensionField", "10000 extension powers; exponent=100; random quadratic base primes"; p=p) do
            v = [beta^100 for _ in 1:10000]
            string(v[end])
        end

        SPA, SPB = poly(SP, ac), poly(SP, bc)
        GPA, GPB = Polynomial(G.(ac)), Polynomial(G.(bc))
        record(io, "polynomial_mul_deg999", "NTL.jl", "ModPoly generalized FFT", "degree 999 inputs; random 7-bit prime set"; p=p) do
            c = SPA * SPB
            string(NTL.degree(c) + rep(NTL.coeff(c, 123)))
        end
        record(io, "polynomial_mul_deg999", "GaloisFields.jl", "Polynomials.jl", "degree 999 inputs; random 7-bit prime set"; p=p) do
            c = GPA * GPB
            string(Polynomials.degree(c) + Integer(c[123]))
        end
        println("Random small-prime case p=", p, " complete")
    end

end
println("Wrote ", OUTPUT)
