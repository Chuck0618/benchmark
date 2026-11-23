using NTL
using Random
using Statistics

function bench(io, name, fn; trials = 31)
    result = fn()
    times = Vector{Float64}(undef, trials)
    for i in 1:trials
        times[i] = @elapsed result = fn()
    end
    println(io, name, ",", join(round.(times, digits=6), ','))
    flush(io)
    println(name, " ", round(median(times) * 1000, digits=4), " ms")
end

function main(output)
    open(output, "w") do io
        println(io, "workload,ms")
        A0 = BigInt[1 2; 3 4]
        bench(io, "charpoly_2x2", () -> charpoly(A0))

        n = 12
        A = [BigInt(j <= i ? i * (j + 1) % 17 : 0) for i in 1:n, j in 1:n]
        for i in 1:n
            A[i, i] = i + 1
        end
        bench(io, "hnf_12x12", () -> hnf(A))

        b = BigInt[2]
        bench(io, "solve_integer_trivial", () -> solve_integer(BigInt[2 4], b))

        x = xpoly(BigInt)
        f = (x + 1)^2 * (x + 2) * (x^2 + x + 1) * (x^3 + 2x + 1)
        bench(io, "factor_integer_poly_deg8", () -> factor_integer_poly(f))

        E, a = conway_field(2, 3)
        xe = xpoly(E)
        fe = (xe + a)^2 * (xe + a + 1)
        bench(io, "GF2EXFactoring", () -> GF2EXFactoring(fe))

        F5 = PrimeField(5)
        m = xpoly(F5)^2 + 2
        E5 = extension_field(F5, m)
        a5 = gen(E5)
        x5 = xpoly(E5)
        f5 = (x5 + a5)^2 * (x5 + a5 + 1)
        bench(io, "ZZ_pEXFactoring", () -> ZZ_pEXFactoring(f5))

        T = GF2E(GF2X(13))
        phi = identify(E, T)
        bench(io, "identify_one_element", () -> phi(a))

        Ab = BigInt[28 18 -1 -6; 29 21 -7 27; -21 6 11 5; -28 -9 24 -7]
        bench(io, "bkz_block3", () -> bkz(Ab; block_size = 3))

        bench(io, "isolate_real_roots_repeated_and_irrational", () -> isolate_real_roots((x - 1)^2 * (x^2 - 2)))

        R = BigModRing(97)
        values = fill(R(1), 100_000)
        packed = packedfieldvec(R, values)
        bench(io, "packedfieldvec_read_sum", () -> sum(v for v in packed))
        bench(io, "ordinary_vector_read_sum", () -> sum(values))
    end
    println("Wrote ", output)
end

main(ARGS[1])
