#!/usr/bin/env python3
"""Drop overlay resources that the base package doesn't define.

The device trees were written for LineageOS, whose frameworks/base has extra
config entries. Omni's aapt rejects overlays for resources missing from the
base package, so remove those entries (and files left empty).
usage: filter-overlays.py <overlay dir> [<overlay dir> ...]   (run from source top)
"""
import os, re, sys
import xml.etree.ElementTree as ET
ET.register_namespace('xliff', 'urn:oasis:names:tc:xliff:document:1.2')

# Extra resource dirs merged into a package's base (LOCAL_RESOURCE_DIR)
EXTRA_RES = {
    'packages/apps/Settings': ['packages/apps/OmniGears/res'],
}
base_cache = {}

def base_names(pkg):
    if pkg in base_cache:
        return base_cache[pkg]
    names = set()
    for res in [os.path.join(pkg, 'res')] + EXTRA_RES.get(pkg, []):
        if not os.path.isdir(res):
            continue
        for d in os.listdir(res):
            if not d.startswith('values') or not os.path.isdir(os.path.join(res, d)):
                continue
            for f in os.listdir(os.path.join(res, d)):
                if not f.endswith('.xml'):
                    continue
                try:
                    root = ET.parse(os.path.join(res, d, f)).getroot()
                except ET.ParseError:
                    continue
                for el in root:
                    if el.get('name'):
                        names.add(el.get('name'))
    base_cache[pkg] = names
    return names

removed = 0
for overlay in sys.argv[1:]:
    for dirpath, _, files in os.walk(overlay):
        m = re.match(re.escape(overlay.rstrip('/')) + r'/(.+)/res/(values[^/]*)$', dirpath)
        if not m:
            continue
        pkg = m.group(1)
        if not os.path.isdir(os.path.join(pkg, 'res')):
            continue  # overlay for a package Omni doesn't have: ignored by the build
        names = base_names(pkg)
        for f in files:
            if not f.endswith('.xml'):
                continue
            path = os.path.join(dirpath, f)
            try:
                tree = ET.parse(path)
            except ET.ParseError:
                continue
            root = tree.getroot()
            drop = [el for el in root if el.get('name') and el.get('name') not in names]
            if not drop:
                continue
            for el in drop:
                print(f'  {path}: dropping {el.tag} {el.get("name")}')
                root.remove(el)
                removed += 1
            if len([el for el in root if el.get('name')]) == 0:
                os.remove(path)
            else:
                tree.write(path, encoding='utf-8', xml_declaration=True)
print(f'{removed} overlay resource(s) removed')
