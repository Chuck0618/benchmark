// Optional matched check of all four predicates. This separate verifier is
// included for reproducibility; it is not part of the upstream C++ timing.
#include <NTL/LLL.h>
#include <chrono>
#include <algorithm>
#include <iostream>
#include <vector>
using namespace NTL;

bool verify(const mat_ZZ& A, const mat_ZZ& B, const mat_ZZ& U) {
    if (U*A != B || abs(determinant(U)) != 1) return false;
    mat_ZZ g = B*transpose(B);
    ZZ prev(1);
    const long n=B.NumRows();
    for (long j=0; j<n; ++j) {
        const ZZ pivot=g[j][j];
        if (pivot<=0) return false;
        for (long i=j+1; i<n; ++i)
            if (2*abs(g[i][j])>pivot) return false;
        for (long k=j+1; k<n; ++k)
            for (long i=k; i<n; ++i)
                g[i][k]=(pivot*g[i][k]-g[i][j]*g[k][j])/prev;
        if (j+1<n && 4*(prev*g[j+1][j+1]+sqr(g[j+1][j])) < 3*sqr(pivot))
            return false;
        prev=pivot;
    }
    return true;
}
int main() {
    mat_ZZ A; A.SetDims(12,12);
    for (long i=0; i<12; ++i) {
        for (long j=0; j<=i; ++j) A[i][j]=(i+1)*(j+2)%17;
        A[i][i]=i+2;
    }
    std::cout << "round,median_us\n";
    for (int round=1; round<=3; ++round) {
        std::vector<double> times;
        for (int trial=-1; trial<31; ++trial) {
            auto start=std::chrono::steady_clock::now();
            mat_ZZ B=A,U;
            ZZ det2;
            LLL(det2,B,U);
            if (!verify(A,B,U)) return 1;
            auto stop=std::chrono::steady_clock::now();
            if (trial>=0) times.push_back(std::chrono::duration<double,std::micro>(stop-start).count());
        }
        std::sort(times.begin(),times.end());
        std::cout << round << ',' << times[15] << '\n';
    }
}
