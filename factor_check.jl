using NTL, Test, Random
include("fixed_multiplier.jl")
rng = MersenneTwister(201)
@testset "factor and affine equivalence" begin
    for p in (2,3,5,17,101,127,131,1009)
        F = PrimeField(p)
        x = xpoly(F)
        for d in (1,2,3,4,7,8,16,17), trial in 1:8
            f = poly(F, vcat(rand(rng,0:p-1,d), rand(rng,1:p-1)))
            before = coefficients(f)
            result = NTL.factor(f; rng=rng)
            @test reconstruct(result) == f
            @test all(pair -> isone(LeadCoeff(first(pair))) && is_irreducible(first(pair)) && last(pair)>0, result.factors)
            @test all(i -> all(j -> result.factors[i][1] != result.factors[j][1], 1:i-1), eachindex(result.factors))
            @test coefficients(f) == before
        end
        @test_throws DomainError NTL.factor(zero(x))
        @test isempty(NTL.factor(poly(F,1)).factors)
        @test NTL.factor((x+1)^8).factors == [(x+1,8)]
    end
    for p in (2,3,101,1_000_000_007,4112838589)
        p > typemax(Int) && continue
        F = PrimeField(Int(p))
        for n in (0,1,3,257), a in (0,1,p-1), b in (0,1,p-1)
            expected = foldl((v,_) -> mod(v*a+b,p), 1:n; init=big(1))
            @test rep(fixed_chain(F(a),F(b),n)) == expected
        end
    end
end
