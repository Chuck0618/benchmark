#!/usr/bin/env bash
# Usage: bash replay.sh ORIGINAL_NTL PATCHED_NTL ORIGINAL_BENCH PATCHED_BENCH NEW_RESULTS
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
base=$1
opt=$2
bench=$3
typed=$4
out=$5
mkdir -p "$out"
julia=${JULIA:-julia}
compiler=${CXX:-g++}
flags=(-O3 -march=native -std=c++17)
if [[ -n ${NTL_INCLUDE_DIR:-} ]]; then flags+=(-I"$NTL_INCLUDE_DIR"); fi
libs=("${NTL_ARCHIVE:--lntl}" -l:libgmp.so.10 -pthread)
runner=()
if [[ -n ${BENCH_CPU:-} ]]; then runner=(taskset -c "$BENCH_CPU"); fi
run() { "${runner[@]}" "$@"; }
for src in benchmark workloads; do
    "$compiler" "${flags[@]}" "$bench/$src.cpp" "${libs[@]}" -o "$out/$src"
done
run "$out/benchmark" "$here/smallmod-primes.csv" "$out/cpp.csv"
run "$out/workloads" "$out/cpp-workloads.csv"
"$compiler" "${flags[@]}" "$here/precon.cpp" "${libs[@]}" -o "$out/precon"
run "$out/precon" > "$out/precon.txt"
for label in base opt; do
    project=$base
    [[ $label != opt ]] || project=$opt
    jl=("$julia" --startup-file=no --threads=1 --project="$project")
    run "${jl[@]}" "$bench/scalars.jl" "$here/smallmod-primes.csv" "$out/$label.csv"
    run "${jl[@]}" "$bench/workloads_ntl.jl" "$out/$label-original.csv"
    run "${jl[@]}" "$typed/workloads_ntl.jl" "$out/$label-typed.csv"
    run "${jl[@]}" "$bench/typed_examples.jl" > "$out/$label-affine.txt"
    run "${jl[@]}" "$here/factor_demo.jl" > "$out/$label-factor.csv"
done
for script in examples fixed_multiplier check factor_check; do
    run "$julia" --project="$opt" "$here/$script.jl" > "$out/$script.txt"
done
run "$julia" --project="$opt" "$opt/test/runtests.jl" > "$out/full-suite.txt"
python3 "$here/verify.py" "$out"
