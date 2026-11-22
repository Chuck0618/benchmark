using NTL
using Statistics

const OPS = (("add", 200_000, 7), ("mul", 200_000, 7), ("inv", 3_000, 5), ("pow", 1_000, 5))
const EXPONENT = 1_234_567_890_123_456_789
const OPERAND_FACTOR = big"12345678901234567890"

function workloads(A::Vector{T}) where {T}
    (
        function ()
            acc = one(A[1])
            @inbounds for i in 0:199_999
                acc += A[(i & 1023) + 1]
            end
            string(rep(acc))
        end,
        function ()
            acc = one(A[1])
            @inbounds for i in 0:199_999
                acc *= A[(i & 1023) + 1]
            end
            string(rep(acc))
        end,
        function ()
            acc = A[1]
            for _ in 1:3_000
                acc = inv(acc)
                iszero(acc) && error("unexpected zero inverse")
            end
            string(rep(acc))
        end,
        function ()
            acc = A[2]
            for _ in 1:1_000
                acc ^= EXPONENT
            end
            string(rep(acc))
        end,
    )
end

function measure(f, operations, trials)
    checksum = f()
    f()
    outputs = Vector{typeof(checksum)}(undef, trials)
    times = [@elapsed(outputs[i] = f()) for i in eachindex(outputs)]
    @assert all(==(checksum), outputs)
    median(times) * 1e9 / operations, checksum
end

function main(primes, output)
    open(output, "w") do io
        println(io, "bits,case,p,package,backend,operation,ns_per_op,checksum,n,trials,status")
        for row in Iterators.drop(eachline(primes), 1)
            bits_text, case_id, prime = split(row, ',')
            bits, p = parse(Int, bits_text), parse(BigInt, prime)
            F = bits <= 63 ? PrimeField(Int(p)) : BigModRing(p)
            backend = bits <= 63 ? "PrimeField" : "BigModRing"
            A = [F(max(BigInt(1), mod(p - 2 - i * OPERAND_FACTOR, p))) for i in 0:1023]
            for ((operation, n, trials), kernel) in zip(OPS, workloads(A))
                ns, checksum = measure(kernel, n, trials)
                println(io, join((bits, case_id, prime, "NTL.jl", backend, operation, ns, checksum, n, trials, "ok"), ','))
            end
        end
    end
end

main(ARGS...)
