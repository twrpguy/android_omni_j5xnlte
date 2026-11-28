#!/usr/bin/env python3
"""Check that libsec-ril.so and every library it pulls in will load on the device:
each needed library exists on /system and each non-weak undefined symbol is
defined somewhere in the dependency closure (what the dynamic linker searches).

usage: check-ril-symbols.py <product out dir> [root lib ...]
Exit 1 with a list of missing libraries/symbols, 0 if everything resolves.
"""
import os, re, subprocess, sys

out = sys.argv[1]
roots = sys.argv[2:] or ['libsec-ril.so']
dirs = [os.path.join(out, 'system', 'lib'), os.path.join(out, 'system', 'vendor', 'lib')]

def find(lib):
    for d in dirs:
        p = os.path.join(d, lib)
        if os.path.isfile(p):
            return p
    return None

def readelf(args, path):
    return subprocess.run(['readelf', '-W'] + args + [path], capture_output=True, text=True).stdout

def needed(path):
    return re.findall(r'\(NEEDED\).*\[(.+?)\]', readelf(['-d'], path))

def syms(path):
    defined, undef = set(), set()
    for line in readelf(['--dyn-syms'], path).splitlines():
        f = line.split()
        if len(f) < 8 or not f[0].rstrip(':').isdigit():
            continue
        bind, ndx, name = f[4], f[6], f[7].split('@')[0]
        if not name:
            continue
        if ndx == 'UND':
            if bind != 'WEAK':
                undef.add(name)
        else:
            defined.add(name)
    return defined, undef

problems = []
for root in roots:
    rp = find(root)
    if not rp:
        problems.append(f'{root}: not on /system')
        continue
    # breadth-first dependency closure, like the dynamic linker
    order, seen, queue = [], set(), [root]
    # the RIL is dlopen()ed into rild, so rild and its libraries are searched too
    rild = os.path.join(out, 'system', 'bin', 'rild')
    if os.path.isfile(rild):
        order.append(('rild', rild))
        queue += needed(rild)
    while queue:
        lib = queue.pop(0)
        if lib in seen:
            continue
        seen.add(lib)
        p = find(lib)
        if not p:
            problems.append(f'{root}: needed library {lib} missing')
            continue
        order.append((lib, p))
        queue += needed(p)
    defined_all, undef_by_lib = set(), {}
    for lib, p in order:
        d, u = syms(p)
        defined_all |= d
        undef_by_lib[lib] = u
    for lib, u in undef_by_lib.items():
        missing = sorted(u - defined_all)
        if missing:
            problems.append(f'{root}: {lib} needs undefined symbol(s): ' + ' '.join(missing[:15])
                            + (f' (+{len(missing) - 15} more)' if len(missing) > 15 else ''))
    print(f'{root}: {len(order)} libraries in closure checked')

if problems:
    print('\n'.join(problems))
    sys.exit(1)
print('RIL dependency chain complete (libraries and symbols)')
