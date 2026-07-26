# -*- coding: utf-8 -*-
"""Regenerate UpgradeMenu.tscn after Stage 9B migration."""
import os

KNOWN_UID = {
    # Scripts
    "1_4svoh": ("uid://qyfqmoirdewb", "res://scripts/UpgradeMenu.gd"),
    "2_ujqmm": ("uid://dshfc0npo0r8o", "res://scripts/Upgrade.gd"),
    
    # Spear
    "3_q316m": ("uid://c01spearbase", "res://Upgrades/Spear/BaseSpear.tres"),
    "4_qnfig": ("uid://cspearcrit", "res://Upgrades/Spear/Spear_CRIT.tres"),
    "5_r1lcf": ("uid://cspeardmg1", "res://Upgrades/Spear/Spear_DMG_1.tres"),
    "6_enbbt": ("uid://cspeardmg2", "res://Upgrades/Spear/Spear_DMG_2.tres"),
    "7_sr5m3": ("uid://cspearrch1", "res://Upgrades/Spear/Spear_RCH_1.tres"),
    "8_etw03": ("uid://cspearrch2", "res://Upgrades/Spear/Spear_RCH_2.tres"),
    "9_nskpl": ("uid://cspearspd1", "res://Upgrades/Spear/Spear_SPD_1.tres"),
    "10_02wya": ("uid://cspearspd2", "res://Upgrades/Spear/Spear_SPD_2.tres"),
    
    # Aura
    "31_7jsac": ("uid://cauracrit0", "res://Upgrades/Aura/Aura_CRIT.tres"),
    "32_ithuu": ("uid://cauradmg01", "res://Upgrades/Aura/Aura_DMG_1.tres"),
    "33_i0mdu": ("uid://cauradmg02", "res://Upgrades/Aura/Aura_DMG_2.tres"),
    "34_3tpp6": ("uid://caurarad01", "res://Upgrades/Aura/Aura_RAD_1.tres"),
    "35_q4pf1": ("uid://caurarad02", "res://Upgrades/Aura/Aura_RAD_2.tres"),
    "36_qv1yp": ("uid://cauraspd01", "res://Upgrades/Aura/Aura_SPD_1.tres"),
    "37_e64cy": ("uid://cauraspd02", "res://Upgrades/Aura/Aura_SPD_2.tres"),
    "38_cpbi3": ("uid://caurabase01", "res://Upgrades/Aura/BaseAura.tres"),

    # Aura Evolved
    "11_dcp01": ("uid://cevaucd001", "res://Upgrades/Aura_Evolved/EvoAura_COOLDOWN.tres"),
    "12_8wbw6": ("uid://cevaudmgc1", "res://Upgrades/Aura_Evolved/EvoAura_DMG_C.tres"),
    "13_m4xjv": ("uid://cevaudur01", "res://Upgrades/Aura_Evolved/EvoAura_DURATION.tres"),
    "14_cqj6p": ("uid://cevaupuls01", "res://Upgrades/Aura_Evolved/EvoAura_PULSE_RATE.tres"),
    "15_vbsml": ("uid://cevaurrad01", "res://Upgrades/Aura_Evolved/EvoAura_RADIUS.tres"),

    # Spear Evolved
    "53_2u42m": ("uid://cevsparea1", "res://Upgrades/Spear_Evolved/EvoSpear_AREA.tres"),
    "54_o5ovi": ("uid://cevspacd01", "res://Upgrades/Spear_Evolved/EvoSpear_COOLDOWN.tres"),
    "55_xq1ro": ("uid://cevspdmgc1", "res://Upgrades/Spear_Evolved/EvoSpear_DMG_C.tres"),
    "56_1hsge": ("uid://cevspdmgr1", "res://Upgrades/Spear_Evolved/EvoSpear_DMG_R.tres"),
    "57_bk3fe": ("uid://cevsprng01", "res://Upgrades/Spear_Evolved/EvoSpear_RANGE.tres"),
    "58_sgq24": ("uid://cevspaspd1", "res://Upgrades/Spear_Evolved/EvoSpear_SPEED.tres"),

    # Evolutions
    "29_fna0k": ("uid://cauraevo001", "res://Upgrades/Evolutions/AuraEvolution.tres"),
    "15_rtwst": ("uid://fqfur6jy4jp1", "res://Upgrades/Evolutions/SpearEvolution.tres"),

    # Global (only Area remains)
    "5_itudg": ("uid://cglare001", "res://Upgrades/Global/Global_Area_I.tres"),
    
    # AttackRange (was Book)
    "14_fna0k": ("uid://cbasebook01", "res://Upgrades/Passives/BaseBook.tres"),
    "17_ithuu": ("uid://cbookradc1", "res://Upgrades/Passives/Book_RAD_C.tres"),
    "20_q4pf1": ("uid://cbookradr1", "res://Upgrades/Passives/Book_RAD_R.tres"),
    "18_i0mdu": ("uid://cbookrade1", "res://Upgrades/Passives/Book_RAD_E.tres"),
    "19_3tpp6": ("uid://cbookradl1", "res://Upgrades/Passives/Book_RAD_L.tres"),
    
    # MaxHP (was Stone)
    "15_7jsac": ("uid://cbasestone01", "res://Upgrades/Passives/BaseStone.tres"),
    "34_qv1yp": ("uid://cstonec01", "res://Upgrades/Passives/Stone_HP_C.tres"),
    "37_3fleo": ("uid://cstoner01", "res://Upgrades/Passives/Stone_HP_R.tres"),
    "35_e64cy": ("uid://cstonee01", "res://Upgrades/Passives/Stone_HP_E.tres"),
    "36_cpbi3": ("uid://cstonel01", "res://Upgrades/Passives/Stone_HP_L.tres"),
}

# Files without UID (path-only references)
NO_UID = [
    ("res://Upgrades/Passives/BaseDamage.tres", "dmg_base"),
    ("res://Upgrades/Passives/Damage_C.tres", "dmg_c"),
    ("res://Upgrades/Passives/Damage_R.tres", "dmg_r"),
    ("res://Upgrades/Passives/Damage_E.tres", "dmg_e"),
    ("res://Upgrades/Passives/Damage_L.tres", "dmg_l"),
    ("res://Upgrades/Passives/BaseCritChance.tres", "cc_base"),
    ("res://Upgrades/Passives/CritChance_C.tres", "cc_c"),
    ("res://Upgrades/Passives/CritChance_R.tres", "cc_r"),
    ("res://Upgrades/Passives/CritChance_E.tres", "cc_e"),
    ("res://Upgrades/Passives/CritChance_L.tres", "cc_l"),
    ("res://Upgrades/Passives/BaseSpeed.tres", "spd_base"),
    ("res://Upgrades/Passives/Speed_C.tres", "spd_c"),
    ("res://Upgrades/Passives/Speed_R.tres", "spd_r"),
    ("res://Upgrades/Passives/Speed_E.tres", "spd_e"),
    ("res://Upgrades/Passives/Speed_L.tres", "spd_l"),
]

HEADER = '''[gd_scene format=3 uid="uid://cj02tarqi3cnf"]

[ext_resource type="Script" uid="uid://qyfqmoirdewb" path="res://scripts/UpgradeMenu.gd" id="1_4svoh"]
[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="2_ujqmm"]

'''

result = HEADER

# Add known resources
for rid in sorted(KNOWN_UID.keys()):
    uid, path = KNOWN_UID[rid]
    result += f'[ext_resource type="Resource" uid="{uid}" path="{path}" id="{rid}"]\n'

# Add no-UID resources
for path, rid in NO_UID:
    result += f'[ext_resource type="Resource" path="{path}" id="{rid}"]\n'

# Build array
array_order = [
    # Aura modifiers
    "31_7jsac", "32_ithuu", "33_i0mdu", "34_3tpp6", "35_q4pf1", "36_qv1yp", "37_e64cy", "38_cpbi3",
    # Aura Evolved
    "11_dcp01", "12_8wbw6", "13_m4xjv", "14_cqj6p", "15_vbsml",
    # Evolutions
    "29_fna0k", "15_rtwst",
    # Global Area
    "5_itudg",
    # AttackRange (Book)
    "14_fna0k", "17_ithuu", "20_q4pf1", "18_i0mdu", "19_3tpp6",
    # MaxHP (Stone)
    "15_7jsac", "34_qv1yp", "37_3fleo", "35_e64cy", "36_cpbi3",
    # Damage
    "dmg_base", "dmg_c", "dmg_r", "dmg_e", "dmg_l",
    # CritChance
    "cc_base", "cc_c", "cc_r", "cc_e", "cc_l",
    # MoveSpeed
    "spd_base", "spd_c", "spd_r", "spd_e", "spd_l",
    # Spear modifiers
    "3_q316m", "4_qnfig", "5_r1lcf", "6_enbbt", "7_sr5m3", "8_etw03", "9_nskpl", "10_02wya",
    # Spear Evolved
    "53_2u42m", "54_o5ovi", "55_xq1ro", "56_1hsge", "57_bk3fe", "58_sgq24",
]

array_str = "Array[ExtResource(\"2_ujqmm\")](["
for i, rid in enumerate(array_order):
    if i > 0:
        array_str += ", "
    array_str += f'ExtResource("{rid}")'
array_str += "])"

result += f'\n[node name="UpgradeMenu" type="CanvasLayer" unique_id=1070606010]\n'
result += f'process_mode = 3\nscript = ExtResource("1_4svoh")\n'
result += f'all_available_upgrades = {array_str}\n\n'
result += f'[node name="UpgradePanel" type="Panel" parent="." unique_id=1717061613]\n'
result += f'unique_name_in_owner = true\noffset_right = 2.0\noffset_bottom = 2.0\n\n'
result += f'[node name="VBoxContainer" type="VBoxContainer" parent="." unique_id=1882368771]\n'
result += f'offset_right = 40.0\noffset_bottom = 40.0\n'

path = "Assets/Scenes/UpgradeMenu.tscn"
with open(path, "w", encoding="utf-8") as f:
    f.write(result)

print(f"Written {path}")
print(f"Size: {os.path.getsize(path)} bytes")
print(f"Resources: {len(KNOWN_UID) + len(NO_UID)}")
print(f"Array entries: {len(array_order)}")