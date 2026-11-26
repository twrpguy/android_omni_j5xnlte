#!/usr/bin/env python3
"""List every ninja input that nothing builds and that doesn't exist on disk.
Ninja itself stops at the first one; this shows them all in one go.
usage: missing-deps.py <build-*.ninja> <path prefix inside container> <real path>"""
import os, re, sys
ninja, cprefix, real = sys.argv[1], sys.argv[2], sys.argv[3]
outputs, needed = set(), {}
def unesc(t): return t.replace('$ ', ' ').replace('$:', ':').replace('$$', '$')
def split(s): return [unesc(t) for t in re.split(r'(?<!\$) ', s) if t]
seen = set()
def parse(path):
    if path in seen: return
    seen.add(path)
    buf = ''
    with open(path, errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            if line.endswith('$') and not line.endswith('$$'):
                buf += line[:-1]; continue
            line, buf = buf + line, ''
            if line.startswith(('subninja ', 'include ')):
                parse(line.split(' ', 1)[1].replace(cprefix, real, 1)); continue
            if not line.startswith('build '): continue
            m = re.match(r'build (.*?)(?<!\$): (\S+)(.*)', line)
            if not m: continue
            outs, rest = m.group(1), m.group(3)
            for o in split(outs.replace(' | ', ' ').replace('|', ' ')): outputs.add(o)
            ins = re.split(r' \|\|? ', rest)
            for part in ins:
                for i in split(part):
                    needed.setdefault(i, outs.split(' ')[0])
parse(ninja)
miss = sorted(i for i in needed if i not in outputs and not os.path.exists(i.replace(cprefix, real, 1)))
for i in miss: print(f'{i}\n    needed by {needed[i]}')
print(f'\n{len(miss)} missing input(s)')
