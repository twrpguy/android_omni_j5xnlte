#!/usr/bin/env python3
"""List every missing input reachable from the build goal (ninja stops at the first).
usage: missing-deps.py <combined-*.ninja> <prefix inside container> <real prefix> [goal]"""
import os, re, sys
from collections import deque
ninja, cprefix, real = sys.argv[1:4]
goal = sys.argv[4] if len(sys.argv) > 4 else 'bacon'
deps, seen_files = {}, set()
def unesc(t): return t.replace('$ ', ' ').replace('$:', ':').replace('$$', '$')
def fix(p): return real + p[len(cprefix):] if p.startswith(cprefix + '/') else p
def split(s): return [unesc(t) for t in re.split(r'(?<!\$) ', s) if t]
def parse(path):
    if path in seen_files: return
    seen_files.add(path)
    buf = ''
    with open(path, errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            if line.endswith('$') and not line.endswith('$$'):
                buf += line[:-1]; continue
            line, buf = buf + line, ''
            if line.startswith(('subninja ', 'include ')):
                parse(fix(line.split(' ', 1)[1].strip())); continue
            if not line.startswith('build '): continue
            m = re.match(r'build (.*?)(?<!\$): (\S+)(.*)', line)
            if not m: continue
            outs = split(m.group(1).replace(' | ', ' ').replace('|', ' '))
            ins = [i for part in re.split(r' \|\|? ', m.group(3)) for i in split(part)]
            for o in outs: deps[o] = ins
parse(ninja)
if goal not in deps:
    sys.exit(f'goal {goal!r} not in ninja graph')
missing, todo, done = {}, deque([goal]), {goal}
while todo:
    t = todo.popleft()
    for i in deps.get(t, ()):
        if i in done: continue
        done.add(i)
        if i in deps: todo.append(i)
        elif not os.path.exists(fix(i)): missing[i] = t
for i in sorted(missing): print(f'{i}\n    needed by {missing[i]}')
print(f'\n{len(missing)} missing input(s) reachable from {goal}')
