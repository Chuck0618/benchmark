using NTL, Statistics

# For invariant a and b in x <- a*x+b, p <= 2^32-1.
# m is rounded down. q is exact or one too small for x*a/p.
function fixed_chain(a::T, b::T, steps::Int) where {P,T<:PrimeField{P}}
    steps >= 0 || throw(ArgumentError("negative iteration count"))
    P <= typemax(UInt32) || throw(ArgumentError("expected modulus at most 32 bits"))
    p, multiplier, offset = UInt64(P), UInt64(rep(a)), UInt64(rep(b))
    m = (multiplier << 32) ÷ p
    x = UInt64(1)
    for _ in 1:steps
        q = (x * m) >> 32
        r = x * multiplier - q * p + offset
        # 0 <= r < 3p. Correct in two comparisons.
        r = ifelse(r >= 2p, r - 2p, r)
        x = ifelse(r >= p, r - p, r)
    end
    T(Int(x))
end

function main()
    F = PrimeField(1_000_000_007)
    a, b = F(123456789), F(987654321)
    @assert rep(fixed_chain(a,b,1_000_000)) == 410346119
    times = Float64[]
    for _ in 1:31
        start = time_ns()
        x = fixed_chain(a,b,1_000_000)
        push!(times, (time_ns()-start)/1e6)
        @assert rep(x) == 410346119
    end
    println("fixed_ms=", median(times))
end
abspath(PROGRAM_FILE) == (@__FILE__) && main()
