# -*- coding: utf-8 -*-
import os, re

files = []
for root, dirs, fnames in os.walk('Upgrades'):
    for f in fnames:
        if f.endswith('.tres'):
            files.append(os.path.join(root, f))

stats = {}
for fpath in sorted(files):
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    name_m = re.search(r'^name = "(.+?)"', content, re.MULTILINE)
    stat_m = re.search(r'^stat_to_modify = "(.+?)"', content, re.MULTILINE)
    amount_m = re.search(r'^amount = ([\-\d.]+)', content, re.MULTILINE)
    
    name = name_m.group(1) if name_m else 'NO_NAME'
    stat = stat_m.group(1) if stat_m else 'NO_STAT'
    amount = amount_m.group(1) if amount_m else 'N/A'
    
    relpath = fpath.replace('\\', '/')[len('Upgrades/'):]
    
    key = stat if stat != 'NO_STAT' else 'NO_STAT'
    if key not in stats:
        stats[key] = []
    stats[key].append((name, amount, relpath))

for stat in sorted(stats.keys()):
    items = stats[stat]
    print(f'\n=== {stat} ({len(items)} upgrades) ===')
    for name, amount, path in items:
        print(f'  {name:30s} amount={amount:>8s}  {path}')