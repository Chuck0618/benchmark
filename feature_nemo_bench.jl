using NTL
using NTL
using Nemo
using Statistics

x = xpoly(BigInt)
f = (x + 1)^2 * (x + 2) * (x^2 + x + 1) * (x^3 + 2x + 1)
times = Vector{Float64}(undef, 31)
for i in 1:31
    times[i] = @elapsed factor_integer_poly(f)
end
println("nemo_factor_integer_poly_ms=", median(times) * 1000)
println("nemo_hnf_12x12_ms=", let
    A = [BigInt(j <= i ? i * (j + 1) % 17 : 0) for i in 1:12, j in 1:12]
    for i in 1:12
        A[i, i] = i + 1
    end
    t = Float64[]
    for _ in 1:31
        push!(t, @elapsed NTL.hnf(A))
    end
    median(t) * 1000
end)
