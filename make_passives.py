# -*- coding: utf-8 -*-
import os

TAG = '''[gd_resource type="Resource" script_class="Upgrade" format=3]

[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="1_upg"]

[resource]
script = ExtResource("1_upg")
name = "{name}"
description = "{desc}"
stat_to_modify = "{stat}"
amount = {amount}
rarity = {rarity}
weapon_tag = "{tag}"
'''

BASE = '''[gd_resource type="Resource" script_class="Upgrade" format=3]

[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="1_upg"]

[resource]
script = ExtResource("1_upg")
name = "{name}"
description = "{desc}"
stat_to_modify = "{stat}"
amount = {amount}
rarity = 0
'''

files = [
    # Base passives
    BASE.format(name="BaseDamage", desc="+10% ко всему урону", stat="damage_multiplier", amount=0.1),
    BASE.format(name="BaseHP", desc="+100 HP к здоровью", stat="max_health", amount=100.0),
    BASE.format(name="BaseCritChance", desc="+5% крит. шанса", stat="crit_chance", amount=0.05),
    BASE.format(name="BaseSpeed", desc="+20 к скорости", stat="max_speed", amount=20.0),
    
    # Damage_C/R/E/L
    TAG.format(name="Damage_C", desc="+5% урона", stat="damage_multiplier", amount=0.05, rarity=0, tag="BaseDamage"),
    TAG.format(name="Damage_R", desc="+10% урона", stat="damage_multiplier", amount=0.1, rarity=1, tag="BaseDamage"),
    TAG.format(name="Damage_E", desc="+15% урона", stat="damage_multiplier", amount=0.15, rarity=2, tag="BaseDamage"),
    TAG.format(name="Damage_L", desc="+25% урона", stat="damage_multiplier", amount=0.25, rarity=3, tag="BaseDamage"),
    
    # HP_C/R/E/L
    TAG.format(name="HP_C", desc="+50 HP", stat="max_health", amount=50.0, rarity=0, tag="BaseHP"),
    TAG.format(name="HP_R", desc="+100 HP", stat="max_health", amount=100.0, rarity=1, tag="BaseHP"),
    TAG.format(name="HP_E", desc="+250 HP", stat="max_health", amount=250.0, rarity=2, tag="BaseHP"),
    TAG.format(name="HP_L", desc="+500 HP", stat="max_health", amount=500.0, rarity=3, tag="BaseHP"),
    
    # CritChance_C/R/E/L
    TAG.format(name="CritChance_C", desc="+3% крит. шанса", stat="crit_chance", amount=0.03, rarity=0, tag="BaseCritChance"),
    TAG.format(name="CritChance_R", desc="+5% крит. шанса", stat="crit_chance", amount=0.05, rarity=1, tag="BaseCritChance"),
    TAG.format(name="CritChance_E", desc="+7% крит. шанса", stat="crit_chance", amount=0.07, rarity=2, tag="BaseCritChance"),
    TAG.format(name="CritChance_L", desc="+10% крит. шанса", stat="crit_chance", amount=0.1, rarity=3, tag="BaseCritChance"),
    
    # Speed_C/R/E/L
    TAG.format(name="Speed_C", desc="+15 к скорости", stat="max_speed", amount=15.0, rarity=0, tag="BaseSpeed"),
    TAG.format(name="Speed_R", desc="+30 к скорости", stat="max_speed", amount=30.0, rarity=1, tag="BaseSpeed"),
    TAG.format(name="Speed_E", desc="+50 к скорости", stat="max_speed", amount=50.0, rarity=2, tag="BaseSpeed"),
    TAG.format(name="Speed_L", desc="+80 к скорости", stat="max_speed", amount=80.0, rarity=3, tag="BaseSpeed"),
]

names = ["BaseDamage", "BaseHP", "BaseCritChance", "BaseSpeed",
         "Damage_C", "Damage_R", "Damage_E", "Damage_L",
         "HP_C", "HP_R", "HP_E", "HP_L",
         "CritChance_C", "CritChance_R", "CritChance_E", "CritChance_L",
         "Speed_C", "Speed_R", "Speed_E", "Speed_L"]

for name, content in zip(names, files):
    path = os.path.join("Upgrades", "Passives", f"{name}.tres")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Created: {name}.tres ({len(content)} bytes)")

print(f"\nTotal: {len(files)} files created!")