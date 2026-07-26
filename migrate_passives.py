# -*- coding: utf-8 -*-
"""Apply Stage 9B migration: rename fields in .tres files, remove duplicates."""
import os
import re

PASSIVES_DIR = "Upgrades/Passives"
GLOBAL_DIR = "Upgrades/Global"

# ── Step 1: Update existing .tres files ──

updates = {
    # Book → AttackRange
    "BaseBook.tres":   {"name": "AttackRange"},
    "Book_RAD_C.tres": {"name": "AttackRange_C", "weapon_tag": "AttackRange"},
    "Book_RAD_R.tres": {"name": "AttackRange_R", "weapon_tag": "AttackRange"},
    "Book_RAD_E.tres": {"name": "AttackRange_E", "weapon_tag": "AttackRange"},
    "Book_RAD_L.tres": {"name": "AttackRange_L", "weapon_tag": "AttackRange"},
    # Stone → MaxHP
    "BaseStone.tres":   {"name": "MaxHP"},
    "Stone_HP_C.tres":  {"name": "MaxHP_C", "weapon_tag": "MaxHP"},
    "Stone_HP_R.tres":  {"name": "MaxHP_R", "weapon_tag": "MaxHP"},
    "Stone_HP_E.tres":  {"name": "MaxHP_E", "weapon_tag": "MaxHP"},
    "Stone_HP_L.tres":  {"name": "MaxHP_L", "weapon_tag": "MaxHP"},
    # BaseDamage → Damage
    "BaseDamage.tres":  {"name": "Damage"},
    "Damage_C.tres":    {"weapon_tag": "Damage"},
    "Damage_R.tres":    {"weapon_tag": "Damage"},
    "Damage_E.tres":    {"weapon_tag": "Damage"},
    "Damage_L.tres":    {"weapon_tag": "Damage", "amount": "0.35"},
    # BaseCritChance → CritChance
    "BaseCritChance.tres": {"name": "CritChance"},
    "CritChance_C.tres":   {"weapon_tag": "CritChance"},
    "CritChance_R.tres":   {"weapon_tag": "CritChance"},
    "CritChance_E.tres":   {"weapon_tag": "CritChance"},
    "CritChance_L.tres":   {"weapon_tag": "CritChance"},
    # BaseSpeed → MoveSpeed
    "BaseSpeed.tres": {"name": "MoveSpeed"},
    "Speed_C.tres":   {"name": "MoveSpeed_C", "weapon_tag": "MoveSpeed"},
    "Speed_R.tres":   {"name": "MoveSpeed_R", "weapon_tag": "MoveSpeed"},
    "Speed_E.tres":   {"name": "MoveSpeed_E", "weapon_tag": "MoveSpeed"},
    "Speed_L.tres":   {"name": "MoveSpeed_L", "weapon_tag": "MoveSpeed"},
}

for fname, changes in updates.items():
    fpath = os.path.join(PASSIVES_DIR, fname)
    if not os.path.exists(fpath):
        print(f"WARN: {fpath} not found, skipping")
        continue
    
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()
    
    original = content
    for key, value in changes.items():
        if key == "name":
            content = re.sub(r'^name = ".*"', f'name = "{value}"', content, flags=re.MULTILINE)
        elif key == "weapon_tag":
            content = re.sub(r'^weapon_tag = ".*"', f'weapon_tag = "{value}"', content, flags=re.MULTILINE)
        elif key == "amount":
            content = re.sub(r'^amount = [\d.]+', f'amount = {value}', content, flags=re.MULTILINE)
    
    if content != original:
        with open(fpath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"UPDATED: {fname}")
    else:
        print(f"NO CHANGES: {fname}")

# ── Step 2: Remove duplicate files ──

REMOVE_PASSIVES = [
    "BaseHP.tres", "HP_C.tres", "HP_R.tres", "HP_E.tres", "HP_L.tres",
]

REMOVE_GLOBALS = [
    "Global_Damage_I.tres", "Global_MoveSpeed_I.tres",
]

for fname in REMOVE_PASSIVES:
    fpath = os.path.join(PASSIVES_DIR, fname)
    if os.path.exists(fpath):
        os.remove(fpath)
        print(f"REMOVED: {fpath}")

for fname in REMOVE_GLOBALS:
    fpath = os.path.join(GLOBAL_DIR, fname)
    if os.path.exists(fpath):
        os.remove(fpath)
        print(f"REMOVED: {fpath}")

print("\nMigration complete!")