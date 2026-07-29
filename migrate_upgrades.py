#!/usr/bin/env python3
"""Mass migration of .tres upgrade files to modifiers array (Dictionary format)."""

import os
import re

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPGRADES_DIR = os.path.join(BASE_DIR, "Upgrades")

SPECIAL_MODIFIERS = {
    "Bow_E.tres": [("base_damage", 12.0), ("pierce_limit", 1.0)],
    "Bow_L.tres": [("base_damage", 20.0), ("pierce_limit", 2.0), ("projectile_amount", 1.0)],
    "SiegeDMG_E.tres": [("base_damage", 8.0), ("attack_cooldown", -0.1)],
    "LtngDMG_R.tres": [("base_damage", 20.0), ("pierce_limit", 2.0), ("projectile_amount", 1.0)],
    "SingDMG_C.tres": [("base_damage", 12.0), ("pierce_limit", 1.0)],
    "StarDMG_E.tres": [("base_damage", 50.0), ("orbit_radius", 40.0)],
}

def build_modifiers_text(modifiers_list):
    """Build 'modifiers = [{...}, {...}]' string from list of (stat, amount) tuples."""
    entries = []
    for stat, amount in modifiers_list:
        if amount == int(amount):
            entries.append(f'{{"amount": {int(amount)}, "stat": "{stat}"}}')
        else:
            entries.append(f'{{"amount": {amount}, "stat": "{stat}"}}')
    return "modifiers = [" + ", ".join(entries) + "]"

def migrate_file(filepath):
    filename = os.path.basename(filepath)
    with open(filepath, "r", encoding="utf-8") as f:
        text = f.read()

    if filename in SPECIAL_MODIFIERS:
        modifiers_list = SPECIAL_MODIFIERS[filename]
    else:
        # Extract from old fields
        m = re.search(r'stat_to_modify\s*=\s*"([^"]*)"', text)
        if not m:
            print(f"  SKIP (no stat_to_modify): {filename}")
            return False
        old_stat = m.group(1)
        if not old_stat:
            print(f"  SKIP (empty stat_to_modify): {filename}")
            return False
        am = re.search(r'amount\s*=\s*([\d.]+)', text)
        old_amount = float(am.group(1)) if am else 0.0
        modifiers_list = [(old_stat, old_amount)]

    # Clear old fields and add modifiers
    text = re.sub(r'stat_to_modify\s*=\s*"[^"]*"', 'stat_to_modify = ""', text)
    text = re.sub(r'amount\s*=\s*[\d.]+', 'amount = 0.0', text)

    # Remove existing modifiers line if present
    text = re.sub(r'\nmodifiers\s*=\s*\[.*?\]', '', text, flags=re.DOTALL)

    # Add modifiers before last line
    mod_text = build_modifiers_text(modifiers_list)
    text = text.rstrip("\n") + "\n" + mod_text + "\n"

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(text)

    print(f"  OK: {filename} -> {len(modifiers_list)} modifiers")
    return True

def main():
    total = 0
    ok = 0
    skipped = 0
    for root, dirs, files in os.walk(UPGRADES_DIR):
        for fname in sorted(files):
            if not fname.endswith(".tres"):
                continue
            filepath = os.path.join(root, fname)
            total += 1
            try:
                if migrate_file(filepath):
                    ok += 1
                else:
                    skipped += 1
            except Exception as e:
                print(f"  ERROR: {fname}: {e}")
                skipped += 1
    print(f"\nDone. Total: {total}, Migrated: {ok}, Skipped/Errors: {skipped}")

if __name__ == "__main__":
    main()