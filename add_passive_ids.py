# Add passive_id to all C/R/E/L passive .tres files
import os

PASSIVES = 'Upgrades/Passives'

passive_map = {
    'Damage_C.tres': 'Damage',
    'Damage_R.tres': 'Damage',
    'Damage_E.tres': 'Damage',
    'Damage_L.tres': 'Damage',
    'Speed_C.tres': 'MoveSpeed',
    'Speed_R.tres': 'MoveSpeed',
    'Speed_E.tres': 'MoveSpeed',
    'Speed_L.tres': 'MoveSpeed',
    'CritChance_C.tres': 'CritChance',
    'CritChance_R.tres': 'CritChance',
    'CritChance_E.tres': 'CritChance',
    'CritChance_L.tres': 'CritChance',
    'Book_RAD_C.tres': 'AttackRange',
    'Book_RAD_R.tres': 'AttackRange',
    'Book_RAD_E.tres': 'AttackRange',
    'Book_RAD_L.tres': 'AttackRange',
    'Stone_HP_C.tres': 'MaxHP',
    'Stone_HP_R.tres': 'MaxHP',
    'Stone_HP_E.tres': 'MaxHP',
    'Stone_HP_L.tres': 'MaxHP',
}

for fname, pid in passive_map.items():
    fpath = os.path.join(PASSIVES, fname)
    if not os.path.exists(fpath):
        print('MISSING: ' + fpath)
        continue
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if 'passive_id' in content:
        print('SKIP: ' + fname)
        continue
    
    # Insert passive_id before name
    content = content.replace('name = "', 'passive_id = "' + pid + '"\nname = "')
    
    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(content)
    print('UPDATED: ' + fname + ' -> passive_id=' + pid)

print('Done!')