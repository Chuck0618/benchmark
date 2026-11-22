"""Compare the pinned versions of Chuck0618/benchmark across three runs."""
import csv
import sys
from pathlib import Path
from statistics import median

directory = Path(sys.argv[1])
versions = ("baseline", "optimized", "cpp")


def records(prefix, version, fields):
    with (directory / f"{prefix}-{version}.csv").open(newline="") as stream:
        return {tuple(row[k] for k in fields): row for row in csv.DictReader(stream)}


scalars = [records("scalars", name, ("bits", "case", "p", "operation")) for name in versions]
base, opt, cpp = scalars
assert base.keys() == opt.keys() == cpp.keys()
for key in base:
    assert base[key]["checksum"] == opt[key]["checksum"] == cpp[key]["checksum"], key

print(f"Scalar checksums verified against C++: {len(base)}.")
print()
print("| Bits | Operation | Baseline (ns/op) | Optimized (ns/op) | C++ (ns/op) | Optimized / C++ |")
print("|---:|---|---:|---:|---:|---:|")
for bits in sorted({int(k[0]) for k in base}):
    for op in ("add", "mul", "inv", "pow"):
        keys = [k for k in base if int(k[0]) == bits and k[3] == op]
        b, o, c = [median(float(r[k]["ns_per_op"]) for k in keys) for r in scalars]
        print(f"| {bits} | {op} | {b:.3f} | {o:.3f} | {c:.3f} | {o/c:.2f}× |")

workloads = [records("workloads", name, ("workload",)) for name in versions]
base, opt, cpp = workloads
assert base.keys() == opt.keys() == cpp.keys()
print()
print("| Workload | Baseline (ms) | Optimized (ms) | C++ (ms) | Optimized / C++ |")
print("|---|---:|---:|---:|---:|")
for key in base:
    assert base[key]["checksum"] == opt[key]["checksum"], key
    if key[0] not in {"lll", "lll_reduce_only"}:
        assert opt[key]["checksum"] == cpp[key]["checksum"], key
    b, o, c = [float(r[key]["ms"]) for r in workloads]
    print(f"| {key[0]} | {b:.6f} | {o:.6f} | {c:.6f} | {o/c:.2f}× |")
