#include <NTL/ZZ.h>
#include <NTL/ZZ_p.h>
#include <NTL/lzz_p.h>
#include <NTL/lzz_pX.h>
#include <NTL/lzz_pXFactoring.h>
#include <NTL/LLL.h>
#include <NTL/mat_lzz_p.h>
#include <NTL/version.h>
#include <algorithm>
#include <chrono>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using namespace NTL;
using Clock = std::chrono::steady_clock;
using namespace std;

string zz_string(const ZZ& x) { ostringstream out; out << x; return out.str(); }
string rep_string(const zz_p& x) { return to_string(rep(x)); }
string rep_string(const ZZ_p& x) { return zz_string(rep(x)); }

double measure(const string& name, const function<string()>& fn, int reps,
               ofstream& out, const string& backend, const string& note) {
    string checksum = fn();
    vector<double> times;
    for (int i = 0; i < reps; ++i) {
        auto start = Clock::now();
        checksum = fn();
        auto stop = Clock::now();
        times.push_back(chrono::duration<double, milli>(stop - start).count());
    }
    sort(times.begin(), times.end());
    double ms = times[times.size() / 2];
    out << name << ",C++ NTL," << backend << ',' << fixed << setprecision(8)
        << ms << ',' << checksum << ',' << reps << ',' << note << "\n";
    out.flush();
    cout << name << " " << ms << " ms\n";
    return ms;
}

int main(int argc, char** argv) {
    string output = argc > 1 ? argv[1] : "results-workloads-cpp.csv";
    ofstream out(output);
    out << "workload,package,backend,ms,checksum,trials,note\n";
    const int reps = 31;

    zz_p::init(1000000007);
    const zz_p a(123456789), b(987654321);
    measure("small_modmul", [&]() {
        zz_p c(1);
        for (int i = 0; i < 1000000; ++i) { c *= a; c += b; }
        return rep_string(c);
    }, reps, out, "zz_p", "1e6 mul+add; input construction excluded");

    const ZZ n = power_ZZ(2, 521) - 1;
    ZZ_p::init(n);
    const ZZ_p big_a(INIT_VAL, to_ZZ("123456789"));
    measure("big_modpow", [&]() {
        const ZZ_p r = power(big_a, 1000000);
        return rep_string(r);
    }, reps, out, "ZZ_p", "p=2^521-1; exponent=1000000");

    zz_p::init(101);
    zz_pX pa, pb;
    for (long i = 0; i < 1000; ++i) {
        SetCoeff(pa, i, (i + 1) % 101);
        SetCoeff(pb, i, (2 * i + 3) % 101);
    }
    measure("polynomial_mul", [&]() {
        const zz_pX c = pa * pb;
        return to_string(deg(c) + rep(coeff(c, 123)));
    }, reps, out, "zz_pX", "degree 999 inputs; deterministic coefficients");

    zz_p::init(998244353);
    zz_pX na, nb;
    for (long i = 0; i < 4096; ++i) {
        SetCoeff(na, i, (i + 1) % 101);
        SetCoeff(nb, i, (2 * i + 3) % 101);
    }
    measure("ntt_convolve", [&]() {
        const zz_pX c = na * nb;
        return to_string(deg(c) + 1 + rep(coeff(c, 456)));
    }, reps, out, "zz_pX", "4096 coefficients per input; linear convolution");

    zz_p::init(101);
    zz_pX x; SetX(x);
    const zz_pX f = (x + 1) * (x + 1) * (x + 2) * (x * x + x + 1) *
                    (x * x * x + 2 * x + 1);
    measure("factorization", [&]() {
        const vec_pair_zz_pX_long factors = CanZass(f);
        return to_string(factors.length());
    }, reps, out, "CanZass", "fixed degree-7 factorization input");

    zz_p::init(1000000007);
    const long matrix_n = 40;
    mat_zz_p A; A.SetDims(matrix_n, matrix_n);
    for (long i = 0; i < matrix_n; ++i)
        for (long j = 0; j < matrix_n; ++j)
            A[i][j] = (i == j ? 1 : (i + j) % 7);
    measure("determinant", [&]() {
        return rep_string(determinant(A));
    }, reps, out, "mat_zz_p", "40x40; p=1000000007");

    const long lattice_n = 12;
    mat_ZZ B0; B0.SetDims(lattice_n, lattice_n);
    for (long i = 0; i < lattice_n; ++i) {
        for (long j = 0; j < lattice_n; ++j)
            B0[i][j] = (j <= i ? (i + 1) * (j + 2) % 17 : 0);
        B0[i][i] = i + 2;
    }
    measure("lll", [&]() {
        mat_ZZ B = B0, U;
        ZZ det2;
        LLL(det2, B, U);
        return zz_string(det2);
    }, reps, out, "NTL_LLL", "12x12; native LLL; no separate Julia-style verification");

    measure("lll_reduce_only", [&]() {
        mat_ZZ B = B0, U;
        ZZ det2;
        LLL(det2, B, U);
        return zz_string(det2);
    }, reps, out, "NTL_LLL", "12x12; same native call used for reduction-only comparison");

    const long prime_n = (1L << 61) - 1;
    measure("probprime", [&]() {
        long count = 0;
        for (int i = 0; i < 200; ++i) count += ProbPrime(prime_n, 16);
        return to_string(count);
    }, reps, out, "ProbPrime", "200 calls; 16 rounds; p=2^61-1");

    cerr << "NTL version " << NTL_VERSION << "; wrote " << output << "\n";
    return 0;
}
