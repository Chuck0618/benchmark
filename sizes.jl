using NTL, Random, Statistics
function measure_case(n, m, scale)
    rng = MersenneTwister(n+m)
    A = [big(scale)*(j<=i ? (i==j ? i+1 : rand(rng,-5:5)) : (j>n ? rand(rng,-3:3) : 0)) for i in 1:n,j in 1:m]
    first = lll(A)
    @assert first.verified && NTL._lll_verify(A, first.basis, first.transform, big(3)//4)
    times = Float64[]
    for _ in 1:31
        start = time_ns()
        result = lll(A)
        push!(times,(time_ns()-start)/1000)
        @assert result == first
    end
    println(n,",",m,",",scale,",",median(times),",",first.mode)
end
println("rows,cols,scale,median_us,mode")
for (n,m,s) in ((4,4,1),(8,12,1),(12,12,1),(16,16,1),(24,24,1),(12,12,1<<22))
    measure_case(n,m,s)
end
