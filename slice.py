"""Extract the two LLL timing blocks unchanged from the pinned upstream scripts."""
from pathlib import Path
import sys
repo, out = map(Path, sys.argv[1:])
jl = (repo/'workloads_ntl.jl').read_text()
start = jl.index('    lattice_n = ')
end = jl.index('    prime_n',start) if '    prime_n' in jl[start:] else jl.index('    record(io, "probprime"',start)
(out/'work.jl').write_text(jl[:jl.index('    F = PrimeField',jl.index('open(OUTPUT'))]+jl[start:end]+'end\n')
cpp = (repo/'workloads.cpp').read_text()
(out/'work.cpp').write_text(cpp[:cpp.index('    zz_p::init',cpp.index('int main'))]+cpp[cpp.index('    const long lattice_n'):cpp.index('    const long prime_n')]+'}\n')
