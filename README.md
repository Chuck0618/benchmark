# NTL.jl Performance Report — 0.14.0

## Scope and validation environment

This report evaluates the uploaded optimization kit against the current NTL.jl baseline. It uses **NTL.jl 0.14.0**, **GaloisFields.jl 1.4**, and **C++ NTL 11.4.2** on the 2-core Intel Xeon Gold 6267C server with Julia 1.11.7. All measurements are single-threaded and run sequentially. Values are medians of 31 runs after warm-up unless otherwise stated; input construction is excluded.

The C++ comparison therefore uses **11.4.2**, not the 11.5.1 version cited in the uploaded kit. Hardware and library versions are not mixed when interpreting the ratios.

### Correctness checks completed

- Full NTL.jl test suite: **4,648,706 passing assertions**, including **1,987 new optimized-kernel assertions**.
- All **14 package examples** passed on the optimized server build.
- **306,588** additional small-modulus arithmetic and factorization checks passed, including exhaustive monic quartics over \(\mathbb F_2\) and \(\mathbb F_3\).
- **112** filtered NTL.jl/C++ random-prime scalar groups match exactly.
- All directly comparable C++ package-workload checksums match; LLL additionally passes transformation, unimodular-determinant, size-reduction, and Lovász checks.
- **40** directly comparable random-small-prime NTL.jl/GaloisFields checksum pairs match. Zech results are checked against ordinary extension-field arithmetic from the same element.
- Independent BigInt expansion of the complete 200,000-step operand sequence agrees with both implementations.

## LLL verification optimization in 0.13.3

The LLL-exact kit was also reviewed independently. The optimized path keeps native `Int` candidates through verification and converts them to `BigInt` only for the public return value. Fixed-width checks are used only when dimensions and magnitudes make the arithmetic provably safe; other inputs use the generic BigInt verifier. A conversion-order regression was found and fixed so that oversized `A` reaches the fallback instead of throwing `InexactError`.

| LLL workload | 0.13.2 baseline | 0.13.3 optimized | C++ NTL |
|---|---:|---:|---:|
| Default LLL with exact verification | 0.1841 ms | 0.0989 ms | 0.0699 ms |
| Reduction only (`verify = false`) | 0.0406 ms | 0.0415 ms | 0.0694 ms |

The default path is therefore about **1.86× faster** than the baseline, while the reduction-only row is essentially unchanged. This confirms that the main improvement lies in verification overhead rather than in the reduction algorithm itself. Native C++ `LLL(det2,B,U)` does not perform Julia's independent exact post-verification, so the default row is an end-to-end API-cost comparison rather than a same-layer algorithm benchmark. For the reduction layer, use `verify = false` versus native C++ LLL. The optional `cpp_checked.cpp` verifier is a separate custom checker and is not part of upstream C++ NTL timing. The new suite adds **536 exact-certificate assertions** and brings the complete test count to **4,645,990**.

## Extended mathematical interfaces in 0.14.0

The feature kit was merged after core and optional validation. It adds HNF, integer linear algebra, integer polynomial factorization, characteristic/minimal polynomials, Conway construction, isomorphism transport, primitive-element and logarithm interfaces, extension-field factorization, packed storage, BKZ, real arithmetic and real-root isolation, as well as caching and ordered parallel execution.

| Workload | Time |
|---|---:|
| `charpoly` on a 2×2 matrix | 0.015 ms |
| HNF on a 12×12 integer matrix | 1.620 ms |
| Integer factorization of the degree-8 test polynomial | 9.014 ms |
| The same factorization with Nemo/FLINT enabled | 0.076 ms |
| GF2EX factorization | 0.453 ms |
| ZZ_pEX factorization | 0.395 ms |
| One generator-map conversion | 0.031 ms |
| BKZ with block size 3 | 0.680 ms |
| Real-root isolation for `(x-1)^2*(x^2-2)` | 1.901 ms |
| Packed-vector read sum | 25.170 ms |
| Ordinary-vector read sum | 8.641 ms |

The optional FLINT factorization path was about **119× faster** than basic Kronecker interpolation for this input. HNF and the optional checks agree with FLINT, while the packed representation uses one-eighth of the ordinary payload but reconstructs values more slowly. `validation/feature-bench.csv` and `validation/feature-nemo-bench.txt` contain the raw measurements and the optional environment setup.

## Selective optimization in 0.13.2

The new smallmod-factor proposal was reviewed independently rather than merged wholesale. Only the small-field factorization path and the typed hot-loop benchmark were retained. The small-residue multiplication patch was **not merged**, because it did not provide a stable speedup on this server.

| Operation | C++ NTL (ms) | Baseline (ms) | Selective 0.13.2 (ms) | Optimized / C++ |
|---|---:|---:|---:|---:|
| Small modular mul/add (typed hot loop) | 8.4581 | 67.8763 | 5.0605 | 0.60x |
| BigInt modular exponentiation | 0.0130 | 0.0049 | 0.0047 | 0.36x |
| Polynomial multiplication | 0.0660 | 0.0693 | 0.0677 | 1.03x |
| NTT convolution | 0.6572 | 0.5898 | 0.5793 | 0.88x |
| Polynomial factorization (degree 8) | 0.0250 | 0.0753 | 0.0261 | 1.05x |
| Finite-field determinant | 0.0302 | 0.0148 | 0.0150 | 0.50x |
| LLL (with exact verification) | 0.0702 | 0.1843 | 0.1786 | 2.55x |
| LLL (reduction only) | 0.0694 | 0.0320 | 0.0283 | 0.41x |
| Primality test (per call) | 0.0678 | 0.0262 | 0.0264 | 0.39x |

The factorization input has total degree **8**; the older degree-7 label is only a compatibility label in the raw CSV. The specialized path is used only when `P <= 127` and `1 <= degree(f) <= 16`. All other inputs continue through generic Cantor–Zassenhaus factorization.

A separate factor demo gives the following complementary measurements:

| Input and RNG lifecycle | 0.13.0 baseline | Selective 0.13.2 |
|---|---:|---:|
| Repository degree-8 input, fresh RNG each call | 67.969 µs | 27.061 µs |
| Repository degree-8 input, prebuilt RNG | 36.450 µs | 8.998 µs |
| `7(x+2)^5(x+3)^3`, fresh RNG | 25.314 µs | 23.336 µs |
| `7(x+2)^5(x+3)^3`, prebuilt RNG | 6.563 µs | 5.665 µs |
| Irreducible `x^2+2`, fresh RNG | 23.182 µs | 18.490 µs |
| Irreducible `x^2+2`, prebuilt RNG | 5.088 µs | 0.891 µs |

The factor demo's fresh-RNG baseline differs from the package-level baseline because the timing wrappers differ; these rows should be compared within the same wrapper rather than mixed with the other table.

## Early-splitting threshold scan

A new probe evaluates at most eight candidate roots and delegates to generic Cantor–Zassenhaus as soon as at least two are found. This keeps highly splitting inputs away from an exhaustive small-field scan without changing the factorization result.

| Case | Specialized / generic before probe | Specialized / generic after probe |
|---|---:|---:|
| `p=31, d=4`, distinct linear factors | 2.667× | 0.994× |
| `p=61, d=8`, distinct linear factors | 4.771× | 0.989× |
| `p=101, d=12`, distinct linear factors | 4.687× | 0.951× |
| `p=127, d=16`, distinct linear factors | 7.115× | 0.995× |

Ratios below 1 indicate that the specialized path is faster. The original proposal's `P <= 127` and degree limit of 16 is retained, while the early probe supplies the missing worst-case guard. All other inputs retain their previous algorithms.

## Package-level C++ NTL comparison (0.13.0)

| Operation | C++ NTL (ms) | 0.12.0 baseline (ms) | 0.13.0 optimized (ms) | Optimized / C++ |
|---|---:|---:|---:|---:|
| Small modular mul/add | 8.4191 | 65.2180 | 70.4097 | 8.36x |
| BigInt modular exponentiation | 0.0129 | 0.0224 | 0.0046 | 0.36x |
| Polynomial multiplication | 0.0654 | 0.2609 | 0.0671 | 1.03x |
| NTT convolution | 0.6519 | 1.0235 | 0.5717 | 0.88x |
| Polynomial factorization | 0.0257 | 0.6673 | 0.0751 | 2.92x |
| Finite-field determinant | 0.0299 | 0.0373 | 0.0146 | 0.49x |
| LLL (with exact verification) | 0.0704 | 1.7875 | 0.1794 | 2.55x |
| LLL (reduction only) | 0.0693 | 0.2674 | 0.0278 | 0.40x |
| Primality test (per call) | 0.0690 | 0.0258 | 0.0258 | 0.37x |

The primality row is normalized per call from the 200-call workload. C++ uses 16 Miller–Rabin rounds, while NTL.jl uses its deterministic signed-`Int` witnesses. LLL separates NTL.jl's exact post-verification from reduction-only timing; the C++ side is the same native call in both rows.

### Interpretation

- The packed polynomial implementation is close to C++ NTL for degree-999 multiplication, and the DIF/DIT convolution is faster than C++ NTL in the measured 4096-coefficient workload.
- Determinant and LLL reduction-only are faster than C++ NTL in this environment. Default LLL still spends additional time on exact verification.
- `small_modmul` did not improve in this run: 65.218 ms at baseline versus 70.410 ms optimized. An independent replay gave 66.963 ms, so there is no meaningful scalar improvement to advertise for that loop.
- Typed hot-loop examples clarify the separate dispatch-boundary issue: separate mul/add measured 5.815 ms at baseline and 5.088 ms optimized; fused muladd measured 5.786 ms at baseline and 4.381 ms optimized. These are different call patterns from the original 66–70 ms loop and should not be conflated with it.
- Factorization improved substantially but is still 2.92× slower than C++ NTL. The result is meaningful progress, not parity across every algorithm.

## Random small-prime GaloisFields comparison

The fixed p=101 comparison was replaced by **eight random 7-bit primes** used identically for every workload and both packages: `[67, 73, 83, 89, 97, 101, 107, 113]`. Zech tests use random quadratic extensions over these primes, with `p^2` below the current table limit. Each per-prime time is the median of 31 runs; the median columns below are taken across the eight per-prime medians.

| Operation | NTL.jl median | GaloisFields median | NTL.jl min–max | GaloisFields min–max |
|---|---:|---:|---:|---:|
| Prime-field mul/add x1e6 | 69.9130 | 72.0840 | 67.8461–74.4842 | 68.7637–74.5095 |
| Prime-field fused muladd x1e6 | 9.9001 | 14.9645 | 9.6332–10.6711 | 13.7398–16.6379 |
| Prime-field power x10000 | 0.3935 | 0.4288 | 0.3224–0.4694 | 0.4263–0.5498 |
| Prime-field inverse x10000 | 0.2408 | 0.2339 | 0.1626–0.2451 | 0.1389–0.2367 |
| Zech extension ops x10000 | 0.5010 | 0.8568 | 0.4960–0.5286 | 0.8187–0.9232 |
| Zech muladd x10000 | 0.5971 | 0.8385 | 0.5905–0.6085 | 0.8089–0.8993 |
| Zech inverse x10000 | 0.3940 | 0.4656 | 0.3751–0.4525 | 0.4491–0.5151 |
| Zech power x10000 | 0.4858 | 0.3820 | 0.4217–0.5118 | 0.3791–0.4126 |
| Polynomial multiplication, deg 999 | 0.0649 | 6.5789 | 0.0623–0.0668 | 5.7308–7.8592 |

NTL.jl's Zech results are checked against ordinary extension-field arithmetic before timing. Display strings are not used as cross-package checksums for extension elements because their representations differ. Prime-field and polynomial results have matching checksums.

## Random-prime scalar results

These tables use the same two random primes per bit size and the same deterministic operand formula across implementations. Addition and multiplication use 200,000 operations per run, inversion uses 3,000 dependent inversions, and powering uses 1,000 powers with the fixed exponent 1,234,567,890,123,456,789. Addition and multiplication use medians of 7 runs; inversion and power use medians of 5 runs. Each entry is the median of the two per-prime medians. Bold values mark the faster implementation.

### ADD (ns/op)

| Bits | NTL.jl 0.13.0 | C++ NTL |
|---:|---:|---:|
| 8 | 1.343 | **1.005** |
| 16 | 1.622 | **1.008** |
| 24 | 1.425 | **1.028** |
| 31 | 1.622 | **1.003** |
| 32 | 1.622 | **1.005** |
| 48 | 1.514 | **1.006** |
| 63 | **1.541** | 21.89 |
| 64 | 147.4 | **23.20** |
| 96 | 89.21 | **20.75** |
| 127 | 89.74 | **22.94** |
| 128 | 134.7 | **22.81** |
| 256 | 137.3 | **29.52** |
| 512 | 141.3 | **37.20** |
| 1024 | 237.6 | **55.64** |

### MUL (ns/op)

| Bits | NTL.jl 0.13.0 | C++ NTL |
|---:|---:|---:|
| 8 | **4.581** | 7.285 |
| 16 | **4.075** | 7.310 |
| 24 | **4.044** | 7.261 |
| 31 | **5.063** | 7.297 |
| 32 | **4.553** | 7.313 |
| 48 | **6.186** | 7.437 |
| 63 | **5.801** | 76.79 |
| 64 | 151.4 | **78.14** |
| 96 | 180.8 | **91.34** |
| 127 | 179.8 | **124.3** |
| 128 | 172.9 | **125.8** |
| 256 | 337.1 | **272.5** |
| 512 | **492.6** | 715.0 |
| 1024 | **879.9** | 1997.7 |

### INV (ns/op)

| Bits | NTL.jl 0.13.0 | C++ NTL |
|---:|---:|---:|
| 8 | **27.78** | 49.10 |
| 16 | **27.96** | 49.09 |
| 24 | **27.81** | 49.15 |
| 31 | **28.98** | 49.72 |
| 32 | **28.08** | 49.27 |
| 48 | **43.28** | 49.77 |
| 63 | **43.03** | 320.4 |
| 64 | **174.4** | 323.5 |
| 96 | **269.7** | 323.8 |
| 127 | **275.9** | 341.9 |
| 128 | **280.0** | 342.4 |
| 256 | **302.7** | 462.7 |
| 512 | **372.1** | 551.3 |
| 1024 | **481.0** | 793.8 |

### POW (µs/op)

| Bits | NTL.jl 0.13.0 | C++ NTL |
|---:|---:|---:|
| 8 | 289.7 | **0.544** |
| 16 | 254.3 | **0.548** |
| 24 | 257.0 | **0.549** |
| 31 | 325.0 | **0.547** |
| 32 | 297.0 | **0.547** |
| 48 | 294.3 | **0.548** |
| 63 | 294.5 | **3.796** |
| 64 | 651.9 | **3.802** |
| 96 | 1262.1 | **3.636** |
| 127 | 1320.9 | **5.384** |
| 128 | 1704.8 | **5.144** |
| 256 | 3891.8 | **12.61** |
| 512 | 9942.1 | **32.13** |
| 1024 | 33392.1 | **109.0** |

## Optimization design and rationality

1. **PrimeField:** specialized unsigned multiplication, Barrett reduction for large machine-word moduli, and Montgomery powering on 64-bit builds. Generated constants are compile-time values rather than mutable global state.
2. **BigModRing:** conditional add/subtract corrections, GMP-backed inversion and `powermod`. No shared mutable global workspace is used.
3. **Packed polynomial multiplication:** coefficients are packed as base-2^bits digits only when the worst-case coefficient bound fits one digit, preventing cross-coefficient carries. Other inputs retain schoolbook, Karatsuba, or NTT paths.
4. **NTT and CRT:** DIF forward and DIT inverse transforms consume the same bit-reversed order. Unit roots are selected by exact-order checks, and `UInt128` CRT is limited to at most four auxiliary primes; larger cases retain BigInt CRT.
5. **Determinants:** delayed modular reduction uses a computed refresh interval based on the machine-integer bound, with a generic fallback for unsuitable moduli.
6. **Factorization:** typed polynomial parents and buffered small-degree modular powers reduce repeated allocation and leading-inverse work without replacing the general factorization algorithms.
7. **LLL:** incremental floating GSO updates are backed by checked integer row operations and BigInt fallback. Exact fraction-free checks still verify the transformation, unimodularity, size reduction, and Lovász condition.

## Remaining optimization targets

- `BigModRing` addition remains slower than C++ NTL at large bit widths. Avoiding full BigInt division/modulo after every small operation is still a relevant direction.
- `small_modmul` needs profiling at the call boundary as well as inside the arithmetic kernel; library-only micro-optimization is not enough.
- Factorization still requires algorithm-level work on repeated modulus reduction and Frobenius-based composition rather than only loop tuning.
- Polynomial, matrix, factorization, and lattice workloads have different bottlenecks and should retain separate benchmarks rather than a single aggregate score.

## Files and reproduction

The `validation/` directory contains the optimized and baseline raw CSV files, C++ results, the kit comparison, typed examples, feature benchmarks, and optional FLINT measurements. `validation/smallmod-results/` additionally contains the selective-factor baseline, final, C++, scalar, and factor-demo results. The benchmark root also contains `benchmark.jl`, `benchmark.cpp`, `workloads.jl`, `workloads.cpp`, `workloads_ntl.jl`, and `generate_primes.jl` for independent replay.

On the project server, run the kit's complete comparison with:

```bash
cd /home/jingdong/kimi/ntl-benchmark
export JULIA=/home/jingdong/kimi/julia-1.11.7/bin/julia
export NTL_INCLUDE_DIR=/home/jingdong/kimi/ntl-install/include
export NTL_ARCHIVE=/home/jingdong/kimi/ntl-install/lib/libntl.a
export GF2X_ARCHIVE=/home/jingdong/kimi/gf2x-install/lib/libgf2x.a
bash run.sh /home/jingdong/kimi/NTLJulia   /home/jingdong/kimi/NTLJulia-opt-kit   /home/jingdong/kimi/ntl-benchmark   /home/jingdong/kimi/kit-results
```

Run the feature benchmark and optional FLINT replay with:

```bash
/home/jingdong/kimi/julia-1.11.7/bin/julia --project=NTL-feature/NTL.jl feature_bench.jl /home/jingdong/kimi/ntl-benchmark/feature-bench.csv

JULIA_DEPOT_PATH=/home/jingdong/kimi/.julia \
JULIA_LOAD_PATH=/home/jingdong/kimi/ntl-optional-env \
/home/jingdong/kimi/julia-1.11.7/bin/julia --project=/home/jingdong/kimi/ntl-optional-env \
  /home/jingdong/kimi/ntl-benchmark/feature_nemo_bench.jl
```

Run the package tests and independent replay with:

```bash
/home/jingdong/kimi/julia-1.11.7/bin/julia --startup-file=no --threads=1   --project=/home/jingdong/kimi/NTLJulia-opt-kit test/runtests.jl

JULIA_DEPOT_PATH=/home/jingdong/kimi/.julia JULIA_LOAD_PATH=/home/jingdong/kimi/NTLJulia-opt-kit:/home/jingdong/kimi/.julia/environments/v1.11:@stdlib /home/jingdong/kimi/julia-1.11.7/bin/julia --threads=1   --project=/home/jingdong/kimi/NTLJulia-opt-kit benchmark.jl primes.csv results-julia-opt-kit.csv
```
