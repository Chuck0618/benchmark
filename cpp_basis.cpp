#include <NTL/LLL.h>
#include <fstream>
using namespace NTL;
// Export the native result for independent verification in Julia.
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    mat_ZZ B, U;
    B.SetDims(12,12);
    for (long i=0; i<12; ++i) {
        for (long j=0; j<=i; ++j) B[i][j] = (i+1)*(j+2)%17;
        B[i][i] = i+2;
    }
    ZZ det2;
    if (LLL(det2,B,U) != 12) return 1;
    std::ofstream out(argv[1]);
    for (const auto* M : {&B,&U})
        for (long i=0; i<12; ++i)
            for (long j=0; j<12; ++j) out << (*M)[i][j] << '\n';
    return out ? 0 : 1;
}
