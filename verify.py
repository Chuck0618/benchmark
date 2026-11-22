import csv
import sys
from pathlib import Path

root = Path(sys.argv[1])
def read(name):
    with (root / name).open() as f:
        return list(csv.DictReader(f))

def checks(rows, keys):
    return {tuple(row[k] for k in keys): row["checksum"] for row in rows}

keys = ("bits", "case", "operation", "n")
reference = checks(read("cpp.csv"), keys)
assert len(reference) == 40
for label in ("base", "opt"):
    assert checks(read(label + ".csv"), keys) == reference
wanted = {"small_modmul", "factorization"}
for label in ("cpp-workloads", "base-original", "base-typed", "opt-original", "opt-typed"):
    values = {r["workload"]: r["checksum"] for r in read(label + ".csv") if r["workload"] in wanted}
    assert values == {"small_modmul": "410346119", "factorization": "5"}
print("40 scalar checksums and both target workload checksums matched.")
