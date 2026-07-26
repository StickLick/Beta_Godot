import os

TEMPLATE = """[gd_resource type="Resource" script_class="Upgrade" format=3 uid="{uid}"]

[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="1_upg"]

[resource]
script = ExtResource("1_upg")
name = "{name}"
description = "{desc}"
stat_to_modify = "{stat}"
amount = {amount}
rarity = {rarity}
weapon_tag = "{tag}"
"""

BASE_TEMPLATE = """[gd_resource type="Resource" script_class="Upgrade" format=3 uid="{uid}"]

[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="1_upg"]

[resource]
script = ExtResource("1_upg")
name = "{name}"
description = "{desc}"
stat_to_modify = "{stat}"
amount = {amount}
rarity = 0
"""

# Series definitions: (base_name, stat, base_amount, base_desc, C, R, E, L, c_amount, r_amount, e_amount, l_amount)
series = [
    ("BaseAttackCooldown", "attack_cooldown", -0.1, "-0.1 сек кулдауна", -0.05, -0.1, -0.15, -0.2),
    ("BaseDamage", "damage_multiplier", 0.1, "+10% урона", 0.05, 0.1, 0.15, 0.25),
    ("BaseHP", "max_health", 100.0, "+100 здоровья", 50.0, 100.0, 250.0, 500.0),
    ("BaseCritChance", "crit_chance", 0.05, "+5% крит. шанса", 0.03, 0.05, 0.07, 0.1),
    ("BaseCritDamage", "crit_damage", 0.25, "+25% крит. урона", 0.15, 0.25, 0.4, 0.6),
    ("BaseLuck", "luck", 0.2, "+0.2 удачи", 0.1, 0.2, 0.3, 0.5),
    ("BaseRadiusXp", "xp_radius", 0.15, "+15% радиуса подбора опыта", 0.1, 0.15, 0.2, 0.3),
    ("BaseXpGain", "xp_gain", 0.2, "+20% опыта", 0.1, 0.2, 0.3, 0.5),
    ("BaseLifesteal", "lifesteal", 0.03, "+3% вампиризма", 0.02, 0.03, 0.05, 0.08),
    ("BaseHealthRegen", "health_regen", 3.0, "+3 HP/сек регенерации", 2.0, 3.0, 5.0, 8.0),
]

rarity_map = {"C": 0, "R": 1, "E": 2, "L": 3}

for base_name, stat, base_amount, base_desc, c_amt, r_amt, e_amt, l_amt in series:
    short = base_name.replace("Base", "")
    amounts = {"C": c_amt, "R": r_amt, "E": e_amt, "L": l_amt}
    
    # Base
    base_uid = f"uid://base{short.lower()}01"
    content = BASE_TEMPLATE.format(uid=base_uid, name=base_name, desc=base_desc, stat=stat, amount=base_amount)
    with open(f"Upgrades/Passives/{base_name}.tres", "w", encoding="utf-8") as f:
        f.write(content)
    
    # C/R/E/L
    for tier in ["C", "R", "E", "L"]:
        name = f"{base_name.replace('Base', '')}_{tier}"
        desc = f"+{abs(amounts[tier])}"
        if stat in ("attack_cooldown",):
            desc = f"{amounts[tier]:+.2f} сек"
        elif stat == "xp_radius":
            desc = f"+{int(amounts[tier]*100)}% радиуса подбора опыта"
        elif stat in ("xp_gain", "damage_multiplier", "crit_chance", "luck", "crit_damage", "lifesteal"):
            desc = f"+{int(amounts[tier]*100)}%"
        elif stat in ("max_health",):
            desc = f"+{int(amounts[tier])} HP"
        elif stat in ("health_regen",):
            desc = f"+{amounts[tier]:.0f} HP/сек"
        
        uid = f"uid://{short.lower()}{tier.lower()}01"
        content = TEMPLATE.format(uid=uid, name=name, desc=desc, stat=stat, amount=amounts[tier], rarity=rarity_map[tier], tag=base_name)
        with open(f"Upgrades/Passives/{name}.tres", "w", encoding="utf-8") as f:
            f.write(content)

print("All files created successfully!")