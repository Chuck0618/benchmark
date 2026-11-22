using NTL
# Same row convention and 12-dimensional input as Chuck0618/benchmark.
A = [big(i == j ? i+1 : j <= i ? i*(j+1)%17 : 0) for i in 1:12, j in 1:12]
result = lll(A)  # verify=true, delta=3/4 by default
@assert result.verified && result.transform * A == result.basis
@assert abs(det_exact(result.transform)) == 1
mu, norms = gram_schmidt_exact(result.basis)
@assert all(abs(mu[i,j]) <= 1//2 for i in 2:12 for j in 1:i-1)
@assert all(norms[i] >= (3//4-mu[i,i-1]^2)*norms[i-1] for i in 2:12)
println("exact verification passed; mode = ", result.mode)
