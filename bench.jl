using NTL, Statistics
function bench(f, expected, name)
    @assert f() == expected
    times = Float64[]
    for _ in 1:61
        t = time_ns()
        value = f()
        push!(times,(time_ns()-t)/1000)
        @assert value == expected
    end
    println(name,",",median(times),",",quantile(times,0.25),",",quantile(times,0.75),",",@allocated(f()))
end
function run()
    A = [BigInt(j<=i ? i*(j+1)%17 : 0) for i in 1:12,j in 1:12]
    for i=1:12
        A[i,i] = i+1
    end
    d = big(3)//4
    result = lll(A)
    B,U = result.basis,result.transform
    @assert result.verified && result.mode == :fast && U*A == B && abs(det_exact(U)) == 1
    @assert NTL._lll_verify(A,B,U,d)
    println("stage,median_us,q25_us,q75_us,bytes")
    bench(() -> lll(A), result, "public_verified")
    bench(() -> lll(A;verify=false), merge(result,(verified=false,)), "public_reduce_only")
    bench(() -> NTL._lll_transform_matches(A,B,U), true, "reference_transform")
    bench(() -> abs(det_exact(U)), big(1), "reference_det")
    bench(() -> NTL._gram_bareiss(B)[end,end], NTL._gram_bareiss(B)[end,end], "reference_gram")
    bench(() -> NTL._lll_verify(A,B,U,d), true, "reference_verify")
    if isdefined(NTL,:_lll_word_verify)
        V,W = Int.(B),Int.(U)
        bench(() -> NTL._lll_verify_reduction(A,V,W,d,B,U),true,"optimized_verify")
    end
end
run()
