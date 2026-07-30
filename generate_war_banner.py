#!/usr/bin/env python3
"""Generate 16 WarBanner upgrade .tres files AND Update UpgradeMenu.tscn."""

import os
import re

TEMPLATE = '''[gd_resource type="Resource" script_class="Upgrade" format=3]

[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="1_upg"]

[resource]
script = ExtResource("1_upg")
name = "{name}"
description = "{desc}"
stat_to_modify = ""
amount = 0.0
rarity = {rarity}
weapon_tag = "Banner"
modifiers = [{mods}]
'''

UPGRADES = [
    # (filename, name, description, rarity, [(stat, amount)])
    ("BannerDrill_C.tres", "Banner: Drill", "+5 damage to banner units", 0, [("base_damage", 5.0)]),
    ("BannerDrill_R.tres", "Banner: Drill", "+10 damage to banner units", 1, [("base_damage", 10.0)]),
    ("BannerDrill_E.tres", "Banner: Drill", "+20 damage to banner units", 2, [("base_damage", 20.0)]),
    ("BannerDrill_L.tres", "Banner: Drill", "+40 damage to banner units", 3, [("base_damage", 40.0)]),
    
    ("BannerMorale_C.tres", "Banner: Morale", "+1s inspired duration", 0, [("inspired_duration", 1.0)]),
    ("BannerMorale_R.tres", "Banner: Morale", "+2s inspired duration", 1, [("inspired_duration", 2.0)]),
    ("BannerMorale_E.tres", "Banner: Morale", "+3s inspired duration", 2, [("inspired_duration", 3.0)]),
    ("BannerMorale_L.tres", "Banner: Morale", "+5s inspired duration", 3, [("inspired_duration", 5.0)]),
    
    ("BannerRally_C.tres", "Banner: Rally", "-1s war cry interval", 0, [("war_cry_interval", -1.0)]),
    ("BannerRally_R.tres", "Banner: Rally", "-2s war cry interval", 1, [("war_cry_interval", -2.0)]),
    ("BannerRally_E.tres", "Banner: Rally", "-3s war cry interval", 2, [("war_cry_interval", -3.0)]),
    ("BannerRally_L.tres", "Banner: Rally", "-5s war cry interval", 3, [("war_cry_interval", -5.0)]),
    
    ("BannerGuardSlots_C.tres", "Banner: Guard Slots", "+1 banner unit", 0, [("max_banner_units", 1)]),
    ("BannerGuardSlots_R.tres", "Banner: Guard Slots", "+1 banner unit", 1, [("max_banner_units", 1)]),
    ("BannerGuardSlots_E.tres", "Banner: Guard Slots", "+2 banner units", 2, [("max_banner_units", 2)]),
    ("BannerGuardSlots_L.tres", "Banner: Guard Slots", "+2 banner units", 3, [("max_banner_units", 2)]),
]

def make_mods(mods):
    entries = []
    for stat, amount in mods:
        if amount == int(amount):
            entries.append(f'{{"amount": {int(amount)}, "stat": "{stat}"}}')
        else:
            entries.append(f'{{"amount": {amount}, "stat": "{stat}"}}')
    return ", ".join(entries)

def generate_tres_files():
    out_dir = os.path.join(os.path.dirname(__file__), "Upgrades", "Weapons", "WarBanner")
    os.makedirs(out_dir, exist_ok=True)
    
    for filename, name, desc, rarity, mods in UPGRADES:
        content = TEMPLATE.format(
            name=name,
            desc=desc,
            rarity=rarity,
            mods=make_mods(mods)
        )
        path = os.path.join(out_dir, filename)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  Created: {filename}")

def update_upgrade_menu():
    menu_path = os.path.join(os.path.dirname(__file__), "Assets", "Scenes", "UpgradeMenu.tscn")
    with open(menu_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Generate ext_resource lines
    ext_lines = []
    ext_refs = []
    for filename, _, _, _, _ in UPGRADES:
        rid = f"wb_{filename.replace('.tres','').lower()}"
        ext_lines.append(f'[ext_resource type="Resource" path="res://Upgrades/Weapons/WarBanner/{filename}" id="{rid}"]')
        ext_refs.append(f'ExtResource("{rid}")')
    
    # Find the line with all_available_upgrades
    # The format is: all_available_upgrades = Array[ExtResource("...")]([...])
    match = re.search(r'(all_available_upgrades\s*=\s*Array\[[^\]]*\]\()(\[[^\]]*\])', content)
    if not match:
        print("ERROR: Could not find all_available_upgrades array!")
        return
    
    prefix = match.group(1)
    existing_array = match.group(2)
    
    # Parse existing array
    existing_refs = re.findall(r'ExtResource\("[^"]*"\)', existing_array)
    
    # Add new refs (only if not already present)
    new_refs = []
    for ref in ext_refs:
        if ref not in existing_refs:
            new_refs.append(ref)
    
    if not new_refs:
        print("  All WarBanner upgrades already registered.")
        return
    
    # Build new array
    all_refs = existing_refs + new_refs
    new_array = "[" + ", ".join(all_refs) + "]"
    new_line = prefix + new_array + ")"
    
    # Replace in content
    content = content[:match.start()] + new_line + content[match.end():]
    
    # Add ext_resource lines before the [node] section
    ext_block = "\n".join(ext_lines)
    # Insert after the last ext_resource line
    last_ext_pos = content.rfind("[ext_resource ")
    if last_ext_pos >= 0:
        end_of_last_ext = content.find("\n", content.rfind("]", last_ext_pos)) + 1 if content.rfind("]", last_ext_pos) > 0 else last_ext_pos
        # Find next empty line after last ext_resource
        next_line_pos = content.find("\n", last_ext_pos)
        if next_line_pos >= 0:
            # Go to end of that line
            eol = content.find("\n", next_line_pos)
            if eol >= 0:
                # Check if next line is also ext_resource or empty
                while eol < len(content) and (content[eol:eol+2] == "\n\n" or "[ext_resource" in content[eol:eol+20]):
                    if "[ext_resource" in content[eol:eol+20]:
                        eol = content.find("\n", content.find("\n", eol + 1)) + 1
                    else:
                        eol += 1
                insert_pos = eol
            else:
                insert_pos = len(content)
        else:
            insert_pos = last_ext_pos + 1
    else:
        insert_pos = content.find("\n[node ") 
    
    content = content[:insert_pos] + "\n" + ext_block + "\n" + content[insert_pos:]
    
    with open(menu_path, "w", encoding="utf-8") as f:
        f.write(content)
    
    print(f"  Added {len(new_refs)} WarBanner upgrades to UpgradeMenu.tscn")

def main():
    print("=== Generating 16 WarBanner .tres files ===")
    generate_tres_files()
    
    print("\n=== Updating UpgradeMenu.tscn ===")
    update_upgrade_menu()
    
    print("\nDone!")

if __name__ == "__main__":
    main()