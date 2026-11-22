using NTL
using GaloisFields
using Statistics

const N_ADD = 200_000
const N_MUL = 200_000
const N_INV = 3_000
const N_POW = 1_000
const EXPONENT = 1_234_567_890_123_456_789
const PRIMES = length(ARGS) >= 1 ? ARGS[1] : "primes.csv"
const OUTPUT = length(ARGS) >= 2 ? ARGS[2] : "results-julia.csv"

function operands(p::BigInt)
    factor = big"12345678901234567890"
    [begin
         x = mod(p - 2 - big(i) * factor, p)
         iszero(x) ? big(1) : x
     end for i in 0:1023]
end

function timed(fn, n::Int, trials::Int)
    checksum = fn() # Warm-up; compilation and field construction are excluded.
    times = Vector{Float64}(undef, trials)
    for i in 1:trials
        times[i] = @elapsed checksum = fn()
    end
    (median(times) * 1e9 / n, checksum)
end

function field_workloads(F, values::Vector{BigInt}, out)
    A = F.(values)

    add_ns, add_sum = timed(N_ADD, 7) do
        acc = one(F)
        for i in 0:(N_ADD - 1)
            acc += A[(i & 1023) + 1]
        end
        out(acc)
    end

    mul_ns, mul_sum = timed(N_MUL, 7) do
        acc = one(F)
        for i in 0:(N_MUL - 1)
            acc *= A[(i & 1023) + 1]
        end
        out(acc)
    end

    inv_ns, inv_sum = timed(N_INV, 5) do
        acc = A[1]
        for _ in 1:N_INV
            acc = inv(acc)
            iszero(acc) && error("unexpected zero inverse")
        end
        out(acc)
    end

    pow_ns, pow_sum = timed(N_POW, 5) do
        acc = A[2]
        for _ in 1:N_POW
            acc = acc^EXPONENT
        end
        out(acc)
    end

    ((add_ns, add_sum), (mul_ns, mul_sum), (inv_ns, inv_sum), (pow_ns, pow_sum))
end

function record(io, bits, case_id, p, package, backend, operation, result, n, trials, status="ok")
    ns, checksum = result
    println(io, join((bits, case_id, p, package, backend, operation, ns, checksum, n, trials, status), ','))
    flush(io)
end

function record_unsupported(io, bits, case_id, p)
    for operation in ("add", "mul", "inv", "pow")
        println(io, join((bits, case_id, p, "GaloisFields.jl", "unsupported", operation, "", "", 0, 0, "unsupported"), ','))
    end
    flush(io)
end

open(OUTPUT, "w") do io
    println(io, "bits,case,p,package,backend,operation,ns_per_op,checksum,n,trials,status")
    for line in readlines(PRIMES)[2:end]
        bits_s, case_s, p_s = split(line, ',')
        bits = parse(Int, bits_s)
        case_id = parse(Int, case_s)
        p = parse(BigInt, p_s)
        values = operands(p)

        F = bits <= 63 ? PrimeField(Int(p)) : BigModRing(p)
        backend = bits <= 63 ? "PrimeField" : "BigModRing"
        results = field_workloads(F, values, x -> string(rep(x)))
        for (operation, result, n, trials) in zip(("add", "mul", "inv", "pow"), results,
                                                  (N_ADD, N_MUL, N_INV, N_POW), (7, 7, 5, 5))
            record(io, bits, case_id, p_s, "NTL.jl", backend, operation, result, n, trials)
        end
        println("NTL.jl ", bits, "-bit case ", case_id, " complete")

        try
            G = GaloisField(p)
            results = field_workloads(G, values, x -> string(Integer(x)))
            for (operation, result, n, trials) in zip(("add", "mul", "inv", "pow"), results,
                                                      (N_ADD, N_MUL, N_INV, N_POW), (7, 7, 5, 5))
                record(io, bits, case_id, p_s, "GaloisFields.jl", "PrimeField", operation, result, n, trials)
            end
            println("GaloisFields.jl ", bits, "-bit case ", case_id, " complete")
        catch err
            if bits >= 128
                record_unsupported(io, bits, case_id, p_s)
                println("GaloisFields.jl ", bits, "-bit case ", case_id, ": unsupported")
            else
                rethrow(err)
            end
        end
    end
end
println("Wrote ", OUTPUT)
