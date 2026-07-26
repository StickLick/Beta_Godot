TEMPLATE = """[gd_resource type="Resource" script_class="Upgrade" format=3 uid="{uid}"]

[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="1_upg"]

[resource]
script = ExtResource("1_upg")
name = "{name}"
description = "{desc}"
stat_to_modify = "max_speed"
amount = {amount}
rarity = {rarity}
weapon_tag = "{tag}"
"""

BASE = """[gd_resource type="Resource" script_class="Upgrade" format=3 uid="{uid}"]

[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="1_upg"]

[resource]
script = ExtResource("1_upg")
name = "BaseSpeed"
description = "+20 к скорости передвижения"
stat_to_modify = "max_speed"
amount = 20.0
rarity = 0
"""

import os

# Base
with open("Upgrades/Passives/BaseSpeed.tres", "w", encoding="utf-8") as f:
    f.write(BASE.format(uid="uid://basespd01"))

# C/R/E/L
data = [
    ("Speed_C", "uid://spdc01", 15.0, 0, "BaseSpeed"),
    ("Speed_R", "uid://spdr01", 30.0, 1, "BaseSpeed"),
    ("Speed_E", "uid://spde01", 50.0, 2, "BaseSpeed"),
    ("Speed_L", "uid://spdl01", 80.0, 3, "BaseSpeed"),
]

for name, uid, amount, rarity, tag in data:
    desc = f"+{int(amount)} к скорости"
    content = TEMPLATE.format(uid=uid, name=name, desc=desc, amount=amount, rarity=rarity, tag=tag)
    path = f"Upgrades/Passives/{name}.tres"
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Created: {name}")

print("Speed series done!")