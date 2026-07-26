# Generate UpgradeMenu.tscn with new passive references
# We keep all weapon/spear/aura/evo/global references, only replace passives

lines = []
passives = []

# Helper to add ext_resource
def add_resource(uid, path, ref_id):
    lines.append(f'[ext_resource type="Resource" uid="{uid}" path="{path}" id="{ref_id}"]')

# === EXISTING REFERENCES TO KEEP ===
refs = {
    # Scripts
    "1_4svoh": ("uid://qyfqmoirdewb", "res://scripts/UpgradeMenu.gd"),
    "2_ujqmm": ("uid://dshfc0npo0r8o", "res://scripts/Upgrade.gd"),
    
    # Spear weapons + modifiers
    "3_q316m": ("uid://c01spearbase", "res://Upgrades/Spear/BaseSpear.tres"),
    "4_qnfig": ("uid://cspearcrit", "res://Upgrades/Spear/Spear_CRIT.tres"),
    "5_r1lcf": ("uid://cspeardmg1", "res://Upgrades/Spear/Spear_DMG_1.tres"),
    "6_enbbt": ("uid://cspeardmg2", "res://Upgrades/Spear/Spear_DMG_2.tres"),
    "7_sr5m3": ("uid://cspearrch1", "res://Upgrades/Spear/Spear_RCH_1.tres"),
    "8_etw03": ("uid://cspearrch2", "res://Upgrades/Spear/Spear_RCH_2.tres"),
    "9_nskpl": ("uid://cspearspd1", "res://Upgrades/Spear/Spear_SPD_1.tres"),
    "10_02wya": ("uid://cspearspd2", "res://Upgrades/Spear/Spear_SPD_2.tres"),
    
    # Aura weapons + modifiers
    "31_7jsac": ("uid://cauracrit0", "res://Upgrades/Aura/Aura_CRIT.tres"),
    "32_ithuu": ("uid://cauradmg01", "res://Upgrades/Aura/Aura_DMG_1.tres"),
    "33_i0mdu": ("uid://cauradmg02", "res://Upgrades/Aura/Aura_DMG_2.tres"),
    "34_3tpp6": ("uid://caurarad01", "res://Upgrades/Aura/Aura_RAD_1.tres"),
    "35_q4pf1": ("uid://caurarad02", "res://Upgrades/Aura/Aura_RAD_2.tres"),
    "36_qv1yp": ("uid://cauraspd01", "res://Upgrades/Aura/Aura_SPD_1.tres"),
    "37_e64cy": ("uid://cauraspd02", "res://Upgrades/Aura/Aura_SPD_2.tres"),
    "38_cpbi3": ("uid://caurabase01", "res://Upgrades/Aura/BaseAura.tres"),
    
    # Aura Evolved modifiers
    "11_dcp01": ("uid://cevaucd001", "res://Upgrades/Aura_Evolved/EvoAura_COOLDOWN.tres"),
    "12_8wbw6": ("uid://cevaudmgc1", "res://Upgrades/Aura_Evolved/EvoAura_DMG_C.tres"),
    "13_m4xjv": ("uid://cevaudur01", "res://Upgrades/Aura_Evolved/EvoAura_DURATION.tres"),
    "14_cqj6p": ("uid://cevaupuls01", "res://Upgrades/Aura_Evolved/EvoAura_PULSE_RATE.tres"),
    "15_vbsml": ("uid://cevaurrad01", "res://Upgrades/Aura_Evolved/EvoAura_RADIUS.tres"),
    
    # Spear Evolved modifiers
    "53_2u42m": ("uid://cevsparea1", "res://Upgrades/Spear_Evolved/EvoSpear_AREA.tres"),
    "54_o5ovi": ("uid://cevspacd01", "res://Upgrades/Spear_Evolved/EvoSpear_COOLDOWN.tres"),
    "55_xq1ro": ("uid://cevspdmgc1", "res://Upgrades/Spear_Evolved/EvoSpear_DMG_C.tres"),
    "56_1hsge": ("uid://cevspdmgr1", "res://Upgrades/Spear_Evolved/EvoSpear_DMG_R.tres"),
    "57_bk3fe": ("uid://cevsprng01", "res://Upgrades/Spear_Evolved/EvoSpear_RANGE.tres"),
    "58_sgq24": ("uid://cevspaspd1", "res://Upgrades/Spear_Evolved/EvoSpear_SPEED.tres"),
    
    # Evolutions
    "29_fna0k": ("uid://cauraevo001", "res://Upgrades/Evolutions/AuraEvolution.tres"),
    "15_rtwst": ("uid://fqfur6jy4jp1", "res://Upgrades/Evolutions/SpearEvolution.tres"),
    
    # Globals
    "3_cjoxr": ("uid://cgldmg001", "res://Upgrades/Global/Global_Damage_I.tres"),
    "4_1cnya": ("uid://cglspd001", "res://Upgrades/Global/Global_MoveSpeed_I.tres"),
    "5_itudg": ("uid://cglare001", "res://Upgrades/Global/Global_Area_I.tres"),
}

# === NEW PASSIVE REFERENCES ===
passive_refs = {
    # Book series (existing)
    "14_fna0k": ("uid://cbasebook01", "res://Upgrades/Passives/BaseBook.tres"),
    "17_ithuu": ("uid://cbookradc1", "res://Upgrades/Passives/Book_RAD_C.tres"),
    "20_q4pf1": ("uid://cbookradr1", "res://Upgrades/Passives/Book_RAD_R.tres"),
    "18_i0mdu": ("uid://cbookrade1", "res://Upgrades/Passives/Book_RAD_E.tres"),
    "19_3tpp6": ("uid://cbookradl1", "res://Upgrades/Passives/Book_RAD_L.tres"),
    
    # Stone series (existing)
    "15_7jsac": ("uid://cbasestone01", "res://Upgrades/Passives/BaseStone.tres"),
    "34_qv1yp": ("uid://cstonec01", "res://Upgrades/Passives/Stone_HP_C.tres"),
    "37_3fleo": ("uid://cstoner01", "res://Upgrades/Passives/Stone_HP_R.tres"),
    "35_e64cy": ("uid://cstonee01", "res://Upgrades/Passives/Stone_HP_E.tres"),
    "36_cpbi3": ("uid://cstonel01", "res://Upgrades/Passives/Stone_HP_L.tres"),
    
    # NEW SERIES: AttackCooldown
    "100_akcd": ("uid://baseatkcd01", "res://Upgrades/Passives/BaseAttackCooldown.tres"),
    "101_akcd": ("uid://atkcdc01", "res://Upgrades/Passives/AttackCooldown_C.tres"),
    "102_akcd": ("uid://atkcdr01", "res://Upgrades/Passives/AttackCooldown_R.tres"),
    "103_akcd": ("uid://atkcde01", "res://Upgrades/Passives/AttackCooldown_E.tres"),
    "104_akcd": ("uid://atkcdl01", "res://Upgrades/Passives/AttackCooldown_L.tres"),
    
    # NEW SERIES: Damage
    "105_dmg": ("uid://basedmg01", "res://Upgrades/Passives/BaseDamage.tres"),
    "106_dmg": ("uid://dmgc01", "res://Upgrades/Passives/Damage_C.tres"),
    "107_dmg": ("uid://dmgr01", "res://Upgrades/Passives/Damage_R.tres"),
    "108_dmg": ("uid://dmge01", "res://Upgrades/Passives/Damage_E.tres"),
    "109_dmg": ("uid://dmgl01", "res://Upgrades/Passives/Damage_L.tres"),
    
    # NEW SERIES: HP
    "110_hp": ("uid://basehp01", "res://Upgrades/Passives/BaseHP.tres"),
    "111_hp": ("uid://hpc01", "res://Upgrades/Passives/HP_C.tres"),
    "112_hp": ("uid://hpr01", "res://Upgrades/Passives/HP_R.tres"),
    "113_hp": ("uid://hpe01", "res://Upgrades/Passives/HP_E.tres"),
    "114_hp": ("uid://hpl01", "res://Upgrades/Passives/HP_L.tres"),
    
    # NEW SERIES: CritChance
    "115_cc": ("uid://basecritchance01", "res://Upgrades/Passives/BaseCritChance.tres"),
    "116_cc": ("uid://critchancec01", "res://Upgrades/Passives/CritChance_C.tres"),
    "117_cc": ("uid://critchancer01", "res://Upgrades/Passives/CritChance_R.tres"),
    "118_cc": ("uid://critchancee01", "res://Upgrades/Passives/CritChance_E.tres"),
    "119_cc": ("uid://critchancel01", "res://Upgrades/Passives/CritChance_L.tres"),
    
    # NEW SERIES: CritDamage
    "120_cd": ("uid://basecritdamage01", "res://Upgrades/Passives/BaseCritDamage.tres"),
    "121_cd": ("uid://critdamagec01", "res://Upgrades/Passives/CritDamage_C.tres"),
    "122_cd": ("uid://critdamager01", "res://Upgrades/Passives/CritDamage_R.tres"),
    "123_cd": ("uid://critdamagee01", "res://Upgrades/Passives/CritDamage_E.tres"),
    "124_cd": ("uid://critdamagel01", "res://Upgrades/Passives/CritDamage_L.tres"),
    
    # NEW SERIES: Luck
    "125_lk": ("uid://baseluck01", "res://Upgrades/Passives/BaseLuck.tres"),
    "126_lk": ("uid://luckc01", "res://Upgrades/Passives/Luck_C.tres"),
    "127_lk": ("uid://luckr01", "res://Upgrades/Passives/Luck_R.tres"),
    "128_lk": ("uid://lucke01", "res://Upgrades/Passives/Luck_E.tres"),
    "129_lk": ("uid://luckl01", "res://Upgrades/Passives/Luck_L.tres"),
    
    # NEW SERIES: RadiusXp
    "130_rxp": ("uid://baseradiusxp01", "res://Upgrades/Passives/BaseRadiusXp.tres"),
    "131_rxp": ("uid://radiusxpc01", "res://Upgrades/Passives/RadiusXp_C.tres"),
    "132_rxp": ("uid://radiusxpr01", "res://Upgrades/Passives/RadiusXp_R.tres"),
    "133_rxp": ("uid://radiusxpe01", "res://Upgrades/Passives/RadiusXp_E.tres"),
    "134_rxp": ("uid://radiusxpl01", "res://Upgrades/Passives/RadiusXp_L.tres"),
    
    # NEW SERIES: XpGain
    "135_xg": ("uid://basexpgain01", "res://Upgrades/Passives/BaseXpGain.tres"),
    "136_xg": ("uid://xpgainc01", "res://Upgrades/Passives/XpGain_C.tres"),
    "137_xg": ("uid://xpgainr01", "res://Upgrades/Passives/XpGain_R.tres"),
    "138_xg": ("uid://xpgaine01", "res://Upgrades/Passives/XpGain_E.tres"),
    "139_xg": ("uid://xpgainl01", "res://Upgrades/Passives/XpGain_L.tres"),
    
    # NEW SERIES: Lifesteal
    "140_ls": ("uid://baselifesteal01", "res://Upgrades/Passives/BaseLifesteal.tres"),
    "141_ls": ("uid://lifestealc01", "res://Upgrades/Passives/Lifesteal_C.tres"),
    "142_ls": ("uid://lifestealr01", "res://Upgrades/Passives/Lifesteal_R.tres"),
    "143_ls": ("uid://lifesteale01", "res://Upgrades/Passives/Lifesteal_E.tres"),
    "144_ls": ("uid://lifesteall01", "res://Upgrades/Passives/Lifesteal_L.tres"),
    
    # NEW SERIES: HealthRegen
    "145_hr": ("uid://basehealthregen01", "res://Upgrades/Passives/BaseHealthRegen.tres"),
    "146_hr": ("uid://healthregenc01", "res://Upgrades/Passives/HealthRegen_C.tres"),
    "147_hr": ("uid://healthregenr01", "res://Upgrades/Passives/HealthRegen_R.tres"),
    "148_hr": ("uid://healthregen01", "res://Upgrades/Passives/HealthRegen_E.tres"),
    "149_hr": ("uid://healthregenl01", "res://Upgrades/Passives/HealthRegen_L.tres"),
    
    # NEW SERIES: Speed
    "150_sp": ("uid://basespd01", "res://Upgrades/Passives/BaseSpeed.tres"),
    "151_sp": ("uid://spdc01", "res://Upgrades/Passives/Speed_C.tres"),
    "152_sp": ("uid://spdr01", "res://Upgrades/Passives/Speed_R.tres"),
    "153_sp": ("uid://spde01", "res://Upgrades/Passives/Speed_E.tres"),
    "154_sp": ("uid://spdl01", "res://Upgrades/Passives/Speed_L.tres"),
}

# Build the scene
result = '[gd_scene format=3 uid="uid://cj02tarqi3cnf"]\n\n'
result += '[ext_resource type="Script" uid="uid://qyfqmoirdewb" path="res://scripts/UpgradeMenu.gd" id="1_4svoh"]\n'
result += '[ext_resource type="Script" uid="uid://dshfc0npo0r8o" path="res://scripts/Upgrade.gd" id="2_ujqmm"]\n'

# Add all resources (sorted by id key for stability)
all_refs = {}
all_refs.update(refs)
all_refs.update(passive_refs)

for rid in sorted(all_refs.keys()):
    uid, path = all_refs[rid]
    result += f'[ext_resource type="Resource" uid="{uid}" path="{path}" id="{rid}"]\n'

# Build the array
# Weapons first (existing order), then passives (new), then globals
array_order = [
    # Aura (31-38)
    "31_7jsac", "32_ithuu", "33_i0mdu", "34_3tpp6", "35_q4pf1", "36_qv1yp", "37_e64cy", "38_cpbi3",
    # Aura Evolved (11-15)
    "11_dcp01", "12_8wbw6", "13_m4xjv", "14_cqj6p", "15_vbsml",
    # Evolutions
    "29_fna0k", "15_rtwst",
    # Globals
    "3_cjoxr", "4_1cnya", "5_itudg",
    # Book series
    "14_fna0k", "17_ithuu", "20_q4pf1", "18_i0mdu", "19_3tpp6",
    # Stone series
    "15_7jsac", "34_qv1yp", "37_3fleo", "35_e64cy", "36_cpbi3",
    # AttackCooldown series
    "100_akcd", "101_akcd", "102_akcd", "103_akcd", "104_akcd",
    # Damage series
    "105_dmg", "106_dmg", "107_dmg", "108_dmg", "109_dmg",
    # HP series
    "110_hp", "111_hp", "112_hp", "113_hp", "114_hp",
    # CritChance series
    "115_cc", "116_cc", "117_cc", "118_cc", "119_cc",
    # CritDamage series
    "120_cd", "121_cd", "122_cd", "123_cd", "124_cd",
    # Luck series
    "125_lk", "126_lk", "127_lk", "128_lk", "129_lk",
    # RadiusXp series
    "130_rxp", "131_rxp", "132_rxp", "133_rxp", "134_rxp",
    # XpGain series
    "135_xg", "136_xg", "137_xg", "138_xg", "139_xg",
    # Lifesteal series
    "140_ls", "141_ls", "142_ls", "143_ls", "144_ls",
    # HealthRegen series
    "145_hr", "146_hr", "147_hr", "148_hr", "149_hr",
    # Speed series
    "150_sp", "151_sp", "152_sp", "153_sp", "154_sp",
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
result += f'process_mode = 3\n'
result += f'script = ExtResource("1_4svoh")\n'
result += f'all_available_upgrades = {array_str}\n\n'
result += f'[node name="UpgradePanel" type="Panel" parent="." unique_id=1717061613]\n'
result += f'unique_name_in_owner = true\n'
result += f'offset_right = 2.0\n'
result += f'offset_bottom = 2.0\n\n'
result += f'[node name="VBoxContainer" type="VBoxContainer" parent="." unique_id=1882368771]\n'
result += f'offset_right = 40.0\n'
result += f'offset_bottom = 40.0\n'

with open("Assets/Scenes/UpgradeMenu.tscn", "w", encoding="utf-8") as f:
    f.write(result)

print("Generated UpgradeMenu.tscn successfully!")
print(f"Total resources: {len(all_refs)}")
print(f"Total array entries: {len(array_order)}")