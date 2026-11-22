#include <NTL/lzz_p.h>
#include <algorithm>
#include <chrono>
#include <iostream>
#include <vector>
using namespace NTL;

__attribute__((noinline)) long chain(long a, long b, long p, long steps) {
    const auto m = PrepMulModPrecon(a, p);
    long x = 1;
    for (long i = 0; i < steps; ++i)
        x = AddMod(MulModPrecon(x, a, p, m), b, p);
    return x;
}

int main() {
    volatile long a = 123456789, b = 987654321, p = 1000000007;
    std::vector<double> times;
    for (int trial = -1; trial < 31; ++trial) {
        auto start = std::chrono::steady_clock::now();
        long x = chain(a,b,p,1000000);
        auto stop = std::chrono::steady_clock::now();
        if (x != 410346119) return 1;
        if (trial >= 0)
            times.push_back(std::chrono::duration<double,std::milli>(stop-start).count());
    }
    std::sort(times.begin(), times.end());
    std::cout << "precon_ms=" << times[15] << "\n";
}
