#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 4 ]]; then
    echo "Usage: $0 BASELINE_NTL_JL OPTIMIZED_NTL_JL CHUCK0618_BENCHMARK OUTPUT_DIR" >&2
    exit 2
fi

here=$(cd "$(dirname "$0")" && pwd)
baseline=$(cd "$1" && pwd)
optimized=$(cd "$2" && pwd)
bench=$(cd "$3" && pwd)
mkdir -p "$4"
out=$(cd "$4" && pwd)
julia=${JULIA:-julia}
cxx=${CXX:-g++}
runner=()
if [[ -n ${BENCH_CPU:-} ]]; then
    runner=(taskset -c "$BENCH_CPU")
fi
run() { "${runner[@]}" "$@"; }

compile_flags=(-O3 -DNDEBUG -std=c++17)
libraries=(-lntl -l:libgmp.so.10 -pthread)
if [[ -n ${NTL_INCLUDE_DIR:-} ]]; then
    compile_flags+=(-I"$NTL_INCLUDE_DIR")
fi
if [[ -n ${NTL_ARCHIVE:-} ]]; then
    libraries=("$NTL_ARCHIVE" -l:libgmp.so.10 -pthread)
fi
if [[ -n ${GF2X_ARCHIVE:-} ]]; then
    libraries=("${libraries[0]}" "$GF2X_ARCHIVE" "${libraries[@]:1}")
fi

for target in workloads benchmark; do
    "$cxx" "${compile_flags[@]}" "$bench/$target.cpp" "${libraries[@]}" -o "$out/$target-cpp"
done
run "$out/workloads-cpp" "$out/workloads-cpp.csv"
run "$out/benchmark-cpp" "$bench/primes.csv" "$out/scalars-cpp.csv"
for label in baseline optimized; do
    project=$baseline
    [[ $label != optimized ]] || project=$optimized
    run "$julia" --startup-file=no --threads=1 --project="$project" "$bench/workloads_ntl.jl" "$out/workloads-$label.csv"
    run "$julia" --startup-file=no --threads=1 --project="$project" "$here/scalars.jl" "$bench/primes.csv" "$out/scalars-$label.csv"
    run "$julia" --startup-file=no --threads=1 --project="$project" "$here/typed_examples.jl" > "$out/examples-$label.txt"
done
python3 "$here/compare.py" "$out" > "$out/comparison.md"
