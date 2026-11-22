#include <NTL/ZZ_p.h>
#include <NTL/lzz_p.h>
#include <NTL/version.h>
#include <chrono>
#include <algorithm>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using namespace NTL;
using namespace std;

const long N_ADD = 200000;
const long N_MUL = 200000;
const long N_INV = 3000;
const long N_POW = 1000;
const long EXPONENT_SMALL = 1234567890123456789LL;
const ZZ EXPONENT_BIG = to_ZZ("1234567890123456789");

vector<ZZ> make_operands(const ZZ& p) {
    vector<ZZ> values;
    const ZZ factor = to_ZZ("12345678901234567890");
    for (long i = 0; i < 1024; ++i) {
        ZZ x = (p - 2 - to_ZZ(i) * factor) % p;
        if (x < 0) x += p;
        if (x == 0) x = 1;
        values.push_back(x);
    }
    return values;
}

string rep_string(const zz_p& x) { return to_string(rep(x)); }
string rep_string(const ZZ_p& x) {
    ostringstream out;
    out << rep(x);
    return out.str();
}

template<class T>
T convert_value(const ZZ& x);
template<>
zz_p convert_value<zz_p>(const ZZ& x) { return zz_p(to_long(x)); }
template<>
ZZ_p convert_value<ZZ_p>(const ZZ& x) { return ZZ_p(INIT_VAL, x); }

template<class F>
double timed(F fn, long n, int trials, string& checksum) {
    checksum = fn();
    vector<double> times;
    for (int i = 0; i < trials; ++i) {
        auto begin = chrono::steady_clock::now();
        checksum = fn();
        auto end = chrono::steady_clock::now();
        times.push_back(chrono::duration<double>(end - begin).count());
    }
    sort(times.begin(), times.end());
    return times[trials / 2] * 1e9 / n;
}

void record(ofstream& out, int bits, int case_id, const string& p,
            const string& backend, const string& operation,
            double ns, const string& checksum, long n, int trials) {
    out << bits << ',' << case_id << ',' << p << ",C++ NTL," << backend << ','
        << operation << ',' << setprecision(12) << ns << ',' << checksum << ','
        << n << ',' << trials << ",ok\n";
    out.flush();
}

template<class T, class E>
void run_case(ofstream& out, int bits, int case_id, const string& p_str,
              const ZZ& p, const string& backend, E exponent) {
    vector<ZZ> raw = make_operands(p);
    vector<T> A;
    for (const ZZ& x : raw) A.push_back(convert_value<T>(x));

    for (const string& operation : {"add", "mul", "inv", "pow"}) {
        long n = operation == "add" ? N_ADD : operation == "mul" ? N_MUL :
                 operation == "inv" ? N_INV : N_POW;
        int trials = operation == "add" || operation == "mul" ? 7 : 5;
        string checksum;
        double ns = 0.0;
        if (operation == "add") {
            ns = timed([&]() {
                T acc; set(acc);
                for (long i = 0; i < N_ADD; ++i) add(acc, acc, A[i & 1023]);
                return rep_string(acc);
            }, n, trials, checksum);
        } else if (operation == "mul") {
            ns = timed([&]() {
                T acc; set(acc);
                for (long i = 0; i < N_MUL; ++i) mul(acc, acc, A[i & 1023]);
                return rep_string(acc);
            }, n, trials, checksum);
        } else if (operation == "inv") {
            ns = timed([&]() {
                T acc = A[0];
                for (long i = 0; i < N_INV; ++i) {
                    inv(acc, acc);
                    if (IsZero(acc)) Error("unexpected zero inverse");
                }
                return rep_string(acc);
            }, n, trials, checksum);
        } else {
            ns = timed([&]() {
                T acc = A[1];
                for (long i = 0; i < N_POW; ++i) power(acc, acc, exponent);
                return rep_string(acc);
            }, n, trials, checksum);
        }
        record(out, bits, case_id, p_str, backend, operation, ns, checksum, n, trials);
    }
}

int main(int argc, char** argv) {
    const string input = argc > 1 ? argv[1] : "primes.csv";
    const string output = argc > 2 ? argv[2] : "results-cpp.csv";
    ifstream in(input);
    ofstream out(output);
    if (!in || !out) {
        cerr << "cannot open input or output\n";
        return 1;
    }
    out << "bits,case,p,package,backend,operation,ns_per_op,checksum,n,trials,status\n";
    string line;
    getline(in, line);
    while (getline(in, line)) {
        size_t first = line.find(',');
        size_t second = line.find(',', first + 1);
        int bits = stoi(line.substr(0, first));
        int case_id = stoi(line.substr(first + 1, second - first - 1));
        string p_str = line.substr(second + 1);
        ZZ p = to_ZZ(p_str.c_str());
        if (bits <= 60) {
            zz_p::init(to_long(p));
            run_case<zz_p, long>(out, bits, case_id, p_str, p, "zz_p", EXPONENT_SMALL);
        } else {
            ZZ_p::init(p);
            run_case<ZZ_p, ZZ>(out, bits, case_id, p_str, p, "ZZ_p", EXPONENT_BIG);
        }
        cout << "C++ NTL " << bits << "-bit case " << case_id << " complete\n";
    }
    cerr << "NTL version " << NTL_VERSION << "; wrote " << output << "\n";
    return 0;
}
