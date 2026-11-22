# Random-Prime Scalar Performance Comparison

## Scope and reproducibility

This report compares **NTL.jl 0.12.0**, **GaloisFields.jl 1.4**, and **C++ NTL 11.4.2** on identical randomly generated prime fields. It also reruns the complete package-level workload tables from the project README, including polynomial, matrix, lattice, number-theory, fused-muladd, and Zech-extension workloads. The server is a 2-core Intel Xeon Gold 6267C environment running Julia 1.11.7. Measurements are single-threaded and were run sequentially rather than concurrently.

- Prime sizes: **8, 16, 24, 31, 32, 48, 63, 64, 96, 127, 128, 256, 512, and 1024 bits**.
- Two independently generated random primes per bit size, for **28 prime cases** total.
- Every generated integer has the requested exact bit length and passed `ProbPrime(p; rounds=32)`.
- Operand sequences are deterministic functions of the random modulus and the operand index; they are identical across all three implementations.
- Addition and multiplication: 200,000 operations per run, median of 7 runs.
- Inversion: 3,000 dependent inversions per run, median of 5 runs.
- Power: 1,000 powers with the fixed exponent 1,234,567,890,123,456,789, median of 5 runs.
- Field construction, JIT compilation, and input generation are outside the timed regions.
- Each table entry is the median of the two per-prime medians for that bit size.

## Backend boundaries

| Bit range | NTL.jl | GaloisFields.jl | C++ NTL |
|---|---|---|---|
| Up to 60 bits | `PrimeField` | Signed machine-word `PrimeField` | `zz_p` |
| 63 bits | `PrimeField` | `Int64` `PrimeField` | `ZZ_p` in this build |
| 64–127 bits | `BigModRing` | `Int128` `PrimeField` | `ZZ_p` |
| 128 bits and above | `BigModRing` | Unsupported | `ZZ_p` |

The C++ build uses NTL's default 60-bit single-precision modulus limit. It therefore switches to `ZZ_p` for the 63-bit cases. GaloisFields uses increasingly wide signed integer storage and supports prime moduli through signed `Int128`; its 128-bit-and-above entries are marked **unsupported**, not slow.

## Correctness verification

There are **112 comparable bit-size / prime / operation groups**. The final checksums of NTL.jl, GaloisFields.jl, and C++ NTL agree in every group, with **zero mismatches**. The raw files also retain every unsupported GaloisFields row explicitly. The expanded package workloads also have matching checksums wherever the representations are directly comparable. LLL uses structural verification, and Zech results are checked against NTL.jl ordinary extension arithmetic rather than compared as representation-specific display strings.

## Results

Bold values mark the fastest supported implementation in each row. Addition, multiplication, and inversion use ns/op; powering uses µs/op because of the fixed 61-bit exponent.

### ADD (ns/op)

| Bits | NTL.jl | GaloisFields.jl | C++ NTL |
|---:|---:|---:|---:|
| 8 | 41.45 | 33.75 | **1.011** |
| 16 | 32.89 | 34.06 | **1.020** |
| 24 | 34.10 | 35.11 | **1.012** |
| 31 | 33.02 | 37.61 | **1.003** |
| 32 | 33.05 | 33.97 | **1.004** |
| 48 | 33.08 | 34.64 | **1.003** |
| 63 | 33.24 | 34.19 | **21.64** |
| 64 | 219.3 | 81.22 | **22.85** |
| 96 | 236.3 | 102.0 | **20.60** |
| 127 | 266.3 | 75.84 | **22.72** |
| 128 | 225.8 | unsupported | **23.06** |
| 256 | 284.2 | unsupported | **27.50** |
| 512 | 302.3 | unsupported | **36.48** |
| 1024 | 575.3 | unsupported | **55.51** |

### MUL (ns/op)

| Bits | NTL.jl | GaloisFields.jl | C++ NTL |
|---:|---:|---:|---:|
| 8 | 36.85 | 36.17 | **7.337** |
| 16 | 35.05 | 34.17 | **7.338** |
| 24 | 35.39 | 35.43 | **7.359** |
| 31 | 33.71 | 46.18 | **7.368** |
| 32 | 42.89 | 42.65 | **7.342** |
| 48 | 67.92 | 64.01 | **7.405** |
| 63 | 67.98 | **62.47** | 79.60 |
| 64 | 227.4 | **77.83** | 78.63 |
| 96 | 330.2 | **90.11** | 90.14 |
| 127 | 333.2 | 346.6 | **129.1** |
| 128 | 314.2 | unsupported | **129.8** |
| 256 | 338.7 | unsupported | **270.7** |
| 512 | 741.2 | unsupported | **707.5** |
| 1024 | **1092.1** | unsupported | 2062.3 |

### INV (ns/op)

| Bits | NTL.jl | GaloisFields.jl | C++ NTL |
|---:|---:|---:|---:|
| 8 | 27.67 | **27.61** | 51.10 |
| 16 | 27.77 | **27.45** | 50.06 |
| 24 | 28.04 | **27.57** | 52.08 |
| 31 | 27.97 | **27.62** | 50.06 |
| 32 | 28.15 | **27.90** | 50.05 |
| 48 | 43.00 | **41.52** | 50.05 |
| 63 | 43.02 | **41.29** | 338.1 |
| 64 | 487.4 | **54.99** | 325.7 |
| 96 | 729.8 | **85.65** | 325.0 |
| 127 | 787.3 | **74.34** | 343.4 |
| 128 | 847.6 | unsupported | **345.2** |
| 256 | 829.0 | unsupported | **436.1** |
| 512 | 898.6 | unsupported | **553.5** |
| 1024 | 1124.1 | unsupported | **791.2** |

### POW (µs/op)

| Bits | NTL.jl | GaloisFields.jl | C++ NTL |
|---:|---:|---:|---:|
| 8 | **0.287** | 0.329 | 0.551 |
| 16 | **0.286** | 0.290 | 0.555 |
| 24 | 0.291 | **0.291** | 0.546 |
| 31 | 0.313 | **0.294** | 0.547 |
| 32 | 0.954 | 1.033 | **0.543** |
| 48 | 2.842 | 2.866 | **0.548** |
| 63 | **2.843** | 2.860 | 3.863 |
| 64 | 25.93 | **3.494** | 3.770 |
| 96 | 35.19 | 4.757 | **3.551** |
| 127 | 35.98 | 26.24 | **5.387** |
| 128 | 36.59 | unsupported | **5.118** |
| 256 | 37.95 | unsupported | **11.88** |
| 512 | 46.38 | unsupported | **32.08** |
| 1024 | 127.2 | unsupported | **107.5** |

## Package-level C++ NTL workloads

These are the complete workload categories from the project README, rerun on 2026-11-22 with NTL.jl 0.12.0 and C++ NTL 11.4.2. Input construction is excluded. NTL.jl runs in a process that loads only NTL.jl, and every value is the median of 31 runs after warm-up.

| Operation | C++ NTL (ms) | NTL.jl (ms) | NTL.jl / C++ |
|---|---:|---:|---:|
| Small modular mul/add | 8.4664 | 68.6621 | 8.11x |
| BigInt modular exponentiation | 0.0130 | 0.0243 | 1.87x |
| Polynomial multiplication | 0.0655 | 0.2717 | 4.15x |
| NTT convolution | 0.6629 | 1.0280 | 1.55x |
| Polynomial factorization | 0.0277 | 0.6428 | 23.18x |
| Finite-field determinant | 0.0303 | 0.0373 | 1.23x |
| LLL (with exact verification) | 0.0697 | 1.8148 | 26.03x |
| LLL (reduction only) | 0.0691 | 0.3160 | 4.58x |
| Primality test (per call) | 0.0697 | 0.0308 | 0.44x |

The primality row is normalized per call from the 200-call workload. The LLL rows deliberately separate NTL.jl's default exact post-verification from `verify = false`; the C++ side is the same native call in both rows. Factor reconstruction and Julia-side LLL structural checks are performed outside the timed regions.

## Package-level GaloisFields workloads

These are the complete NTL.jl-versus-GaloisFields workload categories from the README, including fused muladd, Zech extension arithmetic, and degree-999 polynomial multiplication. Both packages are loaded in the same Julia process, with input construction excluded and 31 runs per workload.

| Operation | NTL.jl (ms) | GaloisFields (ms) |
|---|---:|---:|
| Prime-field mul/add x1e6, p=101 | 65.9643 | 70.8851 |
| Prime-field fused muladd x1e6 | 9.9902 | 14.8994 |
| Prime-field power x10000, p=101 | 0.4292 | 0.4265 |
| Prime-field inverse x10000, p=101 | 0.2386 | 0.2314 |
| Zech extension ops x10000 | 0.4849 | 0.6042 |
| Zech muladd x10000 | 0.5573 | 0.6049 |
| Zech inverse x10000 | 0.3790 | 0.4832 |
| Zech power x10000 | 0.4209 | 0.3842 |
| Polynomial multiplication, deg 999 | 0.3136 | 6.4466 |

NTL.jl's Zech results are checked against ordinary extension-field arithmetic before timing. Display strings are not used as cross-package checksums for extension elements because the representations differ. Prime-field and polynomial results do have matching checksums.

## Interpretation

1. **Small machine-word primes:** NTL.jl and GaloisFields are generally close for addition, multiplication, inversion, and powering. C++ NTL leads most addition and multiplication rows, while the two Julia implementations are faster in the repeated-inversion loop. The power ordering varies with bit size. These are workload-specific results, not a universal ranking.
2. **64–127 bits:** GaloisFields' `Int128` representation gives particularly strong addition and inversion performance. NTL.jl's `BigModRing` pays for `BigInt` allocation and reduction; multiplication is more competitive, including at 127 bits, but C++ NTL remains faster in that case.
3. **128 bits and above:** only NTL.jl and C++ NTL remain in this comparison. NTL.jl's large-integer multiplication becomes relatively stronger as the modulus grows. At 1024 bits, the measured multiplication rate is **1092.1 ns/op for NTL.jl versus 2062.3 ns/op for C++ NTL**. Addition, inversion, and most powering cases still favor C++ NTL.
4. **Backend changes matter:** some ratios change at 63/64 bits because the implementations switch storage strategies at different thresholds. They should not be interpreted as a discontinuity in the underlying mathematical operation alone.

## Optimization implications

- `BigModRing` addition and subtraction are obvious targets: avoiding a full `BigInt` division/modulo after every operation should reduce the large gap in addition.
- The typed auxiliary-NTT work in NTL.jl 0.11.0 is consistent with the relatively strong large-modulus multiplication result; further gains would require profiling allocation and reduction inside `BigInt` arithmetic.
- Prime-field addition and powering still have substantial room relative to C++ NTL in the tested loops.
- Polynomial, matrix, factorization, and lattice workloads are outside this scalar benchmark and should retain their own separate measurements.

## Files and reproduction

- `primes.csv`: all random moduli in decimal form.
- `benchmark.jl`: NTL.jl and GaloisFields benchmark.
- `benchmark.cpp`: C++ NTL benchmark.
- `results-julia.csv`: Julia-side per-prime results.
- `results-cpp.csv`: C++ per-prime results.
- `results-all.csv`: combined random-prime raw data.
- `workloads.cpp`: C++ package-workload benchmark.
- `workloads.jl`: mixed-process NTL.jl / GaloisFields workloads.
- `workloads_ntl.jl`: pure-NTL workloads used against C++ NTL.
- `results-workloads-cpp.csv`: C++ package-workload results.
- `results-workloads-ntl.csv`: pure-NTL package-workload results.
- `results-workloads-julia.csv`: mixed-process NTL.jl / GaloisFields results.
- `results-workloads-all.csv`: combined package-workload raw data.

On the project server, the scripts are in `/home/jingdong/kimi/ntl-benchmark`. The essential commands are:

```bash
/home/jingdong/kimi/julia-1.11.7/bin/julia --project=/home/jingdong/kimi/NTLJulia generate_primes.jl primes.csv

g++ -O3 -DNDEBUG -std=c++17   -I/home/jingdong/kimi/ntl-install/include benchmark.cpp   -o benchmark-random-prime   /home/jingdong/kimi/ntl-install/lib/libntl.a   /home/jingdong/kimi/gf2x-install/lib/libgf2x.a   -L/usr/lib/x86_64-linux-gnu -l:libgmp.so.10 -lpthread

./benchmark-random-prime primes.csv results-cpp.csv

JULIA_DEPOT_PATH=/home/jingdong/kimi/.julia JULIA_LOAD_PATH=/home/jingdong/kimi/NTLJulia:/home/jingdong/kimi/.julia/environments/v1.11:@stdlib /home/jingdong/kimi/julia-1.11.7/bin/julia --threads=1   benchmark.jl primes.csv results-julia.csv

# Package-level workloads
g++ -O3 -DNDEBUG -std=c++17 \
  -I/home/jingdong/kimi/ntl-install/include workloads.cpp \
  -o benchmark-workloads \
  /home/jingdong/kimi/ntl-install/lib/libntl.a \
  /home/jingdong/kimi/gf2x-install/lib/libgf2x.a \
  -L/usr/lib/x86_64-linux-gnu -l:libgmp.so.10 -lpthread
./benchmark-workloads results-workloads-cpp.csv
/home/jingdong/kimi/julia-1.11.7/bin/julia --threads=1 \
  --project=/home/jingdong/kimi/NTLJulia workloads_ntl.jl results-workloads-ntl.csv

JULIA_DEPOT_PATH=/home/jingdong/kimi/.julia \
JULIA_LOAD_PATH=/home/jingdong/kimi/NTLJulia:/home/jingdong/kimi/.julia/environments/v1.11:@stdlib \
/home/jingdong/kimi/julia-1.11.7/bin/julia --threads=1 \
  workloads.jl results-workloads-julia.csv
```
