using Test, Random, NTL
include("examples.jl")
rng = MersenneTwister(197)
@testset "small residues and reduction boundaries" begin
    for p in (2, 3, 97, 157, 199, 251, 36587, 44203, 65521, 65537, 8423879, 1_000_000_007, 2147483647, 4112838589)
        p > typemax(Int) && continue
        F = PrimeField(Int(p))
        pairs = p <= 251 ? Iterators.product(0:p-1, 0:p-1) :
            Iterators.flatten((Iterators.product((0,1,p÷2,p-2,p-1), (0,1,p÷2,p-2,p-1)), ((rand(rng,0:p-1), rand(rng,0:p-1)) for _ in 1:2000)))
        for (a,b) in pairs
            @test rep(F(a)*F(b)) == mod(big(a)*b,p)
            @test rep(F(a)+F(b)) == mod(big(a)+b,p)
        end
        for n in (0,1,65535,65536,65537)
            @test rep(blocksum(fill(F(p-1),n))) == mod(-n,p)
        end
    end
end
