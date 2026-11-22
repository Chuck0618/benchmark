#!/usr/bin/env bash
set -euo pipefail
# Usage: bash replay.sh BASE_JULIA_REPO PATCHED_JULIA_REPO BENCH_REPO OUTPUT
here=$(cd "$(dirname "$0")" && pwd)
base=$(cd "$1" && pwd)
opt=$(cd "$2" && pwd)
bench=$(cd "$3" && pwd)
mkdir -p "$4"
out=$(cd "$4" && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
julia=${JULIA:-julia}
cxx=${CXX:-g++}
pin=()
if [[ -n ${BENCH_CPU:-} ]]; then pin=(taskset -c "$BENCH_CPU"); fi
flags=(-O3 -DNDEBUG -std=c++17)
if [[ -n ${NTL_INCLUDE_DIR:-} ]]; then flags+=(-I"$NTL_INCLUDE_DIR"); fi
libs=("${NTL_ARCHIVE:--lntl}" -l:libgmp.so.10 -pthread)
python3 "$here/slice.py" "$bench" "$tmpdir"
"$cxx" "${flags[@]}" "$tmpdir/work.cpp" "${libs[@]}" -o "$tmpdir/native"
"$cxx" "${flags[@]}" "$here/cpp_basis.cpp" "${libs[@]}" -o "$tmpdir/cert"
"$tmpdir/cert" "$out/cpp-basis.txt"
runjl() { "${pin[@]}" "$julia" --startup-file=no --threads=1 --project="$1" "${@:2}"; }
for r in 1 2 3; do
    order=(base opt)
    if [[ $r == 2 ]]; then order=(opt base); fi
    "${pin[@]}" "$tmpdir/native" "$out/cpp-$r.csv"
    for tag in "${order[@]}"; do
        if [[ $tag == base ]]; then dir=$base; else dir=$opt; fi
        runjl "$dir" "$tmpdir/work.jl" "$out/$tag-$r.csv"
    done
done
for tag in base opt; do
    if [[ $tag == base ]]; then dir=$base; else dir=$opt; fi
    runjl "$dir" "$here/bench.jl" > "$out/$tag.csv"
done
runjl "$opt" "$here/check.jl" "$out/cpp-basis.txt" > "$out/check.txt"
"$cxx" "${flags[@]}" "$here/cpp_checked.cpp" "${libs[@]}" -o "$tmpdir/cpp-checked"
"${pin[@]}" "$tmpdir/cpp-checked" > "$out/cpp-checked.csv"
for tag in base opt; do
    if [[ $tag == base ]]; then dir=$base; else dir=$opt; fi
    runjl "$dir" "$here/sizes.jl" > "$out/$tag-sizes.csv"
done
