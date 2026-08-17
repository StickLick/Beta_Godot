# -*- coding: utf-8 -*-
"""Migration for Upgrade .tres resources: fill display_name and icon.

Safety:
- By default only fills MISSING display_name/icon (never overwrites hand-tuned data).
- Pass --force to rebuild display_name from the file name for all resources.
  (Even with --force the previous display_name is erased; icon is always repaired
  since icons are derived deterministically.)

Run:  python migrate_upgrade_ui_data.py [--force]
"""
import os
import re
import sys

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Upgrades")
ICON_BASE = "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons"

ICONS = {
    "Icon_01.png": "uid://dt2qm4mn16um6",
    "Icon_02.png": "uid://cm0cj4qp2yavv",
    "Icon_03.png": "uid://v3gjs1ocmwan",
    "Icon_04.png": "uid://7llh2q50tyw1",
    "Icon_05.png": "uid://dpqrpuiwniy76",
    "Icon_06.png": "uid://dlvjrq437wlnr",
    "Icon_07.png": "uid://b6a67pvhxiafg",
    "Icon_08.png": "uid://blf7275hddv0b",
    "Icon_09.png": "uid://casgmipscsl3w",
    "Icon_10.png": "uid://cmorx2bpv3n5d",
    "Icon_11.png": "uid://cckkytbx4c6f2",
    "Icon_12.png": "uid://dperigo5u4vvu",
}

TIERS = {"_C": " I", "_R": " II", "_E": " III", "_L": " IV", "_1": " I", "_2": " II"}

WEAPON_TAGS = {
    "Spear": "Копьё",
    "Aura": "Аура",
    "Bow": "Лук",
    "Staff": "Посох",
    "Banner": "Знамя",
    "WarBanner": "Знамя",
    "SiegeCrossbow": "Осадный арбалет",
    "SpectralVolley": "Спектральный залп",
    "SkyPiercer": "Небесный пронзатель",
    "LightningStaff": "Молния",
    "SingularityStaff": "Сингулярность",
    "StarStaff": "Звёздные осколки",
    "BannerArcher": "Лучник",
    "BannerTank": "Танк",
    "BannerMarshal": "Маршал",
    "Spear_Evolved": "Копьё",
    "Aura_Evolved": "Аура",
}

TAG_ICON = {
    "Spear": "Icon_09.png",
    "Aura": "Icon_04.png",
    "Bow": "Icon_02.png",
    "Staff": "Icon_10.png",
    "Banner": "Icon_06.png",
    "WarBanner": "Icon_06.png",
    "SiegeCrossbow": "Icon_09.png",
    "SpectralVolley": "Icon_11.png",
    "SkyPiercer": "Icon_08.png",
    "LightningStaff": "Icon_08.png",
    "SingularityStaff": "Icon_10.png",
    "StarStaff": "Icon_10.png",
    "BannerArcher": "Icon_02.png",
    "BannerTank": "Icon_06.png",
    "BannerMarshal": "Icon_06.png",
    "Spear_Evolved": "Icon_09.png",
    "Aura_Evolved": "Icon_04.png",
}

PASSIVE_DATA = {
    "Damage": ("Урон", "Icon_01.png"),
    "MoveSpeed": ("Скорость передвижения", "Icon_02.png"),
    "MaxHP": ("Максимальное здоровье", "Icon_04.png"),
    "CritChance": ("Критический шанс", "Icon_08.png"),
    "Luck": ("Удача", "Icon_07.png"),
    "HPRegen": ("Регенерация здоровья", "Icon_05.png"),
    "AttackSpeed": ("Скорость атаки", "Icon_08.png"),
    "AttackRange": ("Радиус атаки", "Icon_11.png"),
    "ProjectileAmount": ("Снаряды", "Icon_10.png"),
    "XP": ("Опыт", "Icon_07.png"),
    "GoldGain": ("Золото", "Icon_03.png"),
}

# (uppercase token, russian modifier word) — checked in order.
MODIFIER_WORDS = [
    ("DMG", "Урон"),
    ("STARBURST", "Звёздный взрыв"),
    ("ARROWCOUNT", "Число стрел"),
    ("RICOCHETRANGE", "Рикошет"),
    ("RICOCHET", "Рикошет"),
    ("COOLDOWN", "Перезарядка"),
    ("RELOAD", "Перезарядка"),
    ("REINFORCE", "Подкрепление"),
    ("EXPLOSION", "Взрыв"),
    ("CHAINBOUNCE", "Отскок"),
    ("BOUNCE", "Отскок"),
    ("GUARDSLOTS", "Слоты стражи"),
    ("GUARD", "Стража"),
    ("MORALE", "Боевой дух"),
    ("RALLY", "Сбор"),
    ("DRILL", "Учения"),
    ("BATTERY", "Батарея"),
    ("CADENCE", "Темп"),
    ("DURATION", "Длительность"),
    ("PIERCE", "Пробитие"),
    ("CRIT", "Критический урон"),
    ("GRIP", "Притяжение"),
    ("JUMP", "Перескок"),
    ("TICK", "Тик"),
    ("PULSE", "Пульс"),
    ("KB", "Отброс"),
    ("HP", "Здоровье"),
    ("SQUAD", "Отряд"),
    ("SPD", "Скорость"),
    ("SPEED", "Скорость"),
    ("RANGE", "Дальность"),
    ("RAD", "Радиус"),
    ("RCH", "Дальность"),
    ("AREA", "Площадь"),
    ("AOE", "Радиус взрыва"),
    ("SHARD", "Осколки"),
    ("BURST", "Залп"),
    ("DMG", "Урон"),
    ("COUNT", "Число"),
    ("CRY", "Клич"),
]

BOOK_NAMES = {"BaseBook", "Book_RAD_C", "Book_RAD_R", "Book_RAD_E", "Book_RAD_L", "AttackRange"}
STONE_NAMES = {"BaseStone", "Stone_HP_C", "Stone_HP_R", "Stone_HP_E", "Stone_HP_L", "MaxHP"}


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def read_str(text, key, default=""):
    m = re.search(r'^%s\s*=\s*"((?:[^"\\]|\\.)*)"' % key, text, re.MULTILINE)
    if not m:
        return default
    return re.sub(r'\\(.)', r'\1', m.group(1))


def read_bool(text, key):
    m = re.search(r'^%s\s*=\s*(true|false)' % key, text, re.MULTILINE)
    return m.group(1) == "true" if m else False


def tier_suffix(upper):
    for suf, rom in TIERS.items():
        if upper.endswith(suf):
            return rom
    return ""


def strip_tier(name):
    for suf in TIERS:
        if name.upper().endswith(suf):
            return name[:-len(suf)]
    return name


def modifier_word(upper):
    """Return (stem_without_tier, russian_word)."""
    stem = strip_tier(upper)
    for token, ru in MODIFIER_WORDS:
        if token in stem:
            return token, ru
    return "", ""


EVOLUTION_NAMES = {
    "Banner Evolution": "Эволюция Знамени",
    "Aura Evolution": "Эволюция Ауры",
}


def build_display_name(filename, name, weapon_tag, passive_id, is_weapon, path):
    """Build display_name deterministically from the FILE NAME + tags."""
    # Evolutions keep their (already Russian) name field.
    if "Evolution" in os.path.basename(path):
        return EVOLUTION_NAMES.get(name, name)

    # --- Passives (no weapon tag or General) ---
    if passive_id != "":
        base, _ = PASSIVE_DATA.get(passive_id, (passive_id, "Icon_04.png"))
        return base + tier_suffix(filename.upper())

    if weapon_tag in ("", "General", "Damage"):
        stem = strip_tier(filename)
        for base_name, (ru, _ic) in PASSIVE_DATA.items():
            if stem == base_name:
                return ru
            if stem == "Base" + base_name:
                return ru
        if stem in BOOK_NAMES or filename in BOOK_NAMES:
            return "Радиус атаки"
        if stem in STONE_NAMES or filename in STONE_NAMES:
            return "Максимальное здоровье"
        return name

    # --- Weapons ---
    if is_weapon:
        base = WEAPON_TAGS.get(weapon_tag, "")
        if base:
            return base
        if name in WEAPON_TAGS.values():
            return name
        return name

    # --- Weapon modifiers (use file name as source of truth) ---
    base = WEAPON_TAGS.get(weapon_tag, weapon_tag)
    # Base weapon resources: BaseSpear -> "Копьё"
    if filename.startswith("Base"):
        cand = filename[4:]
        if cand in WEAPON_TAGS:
            return WEAPON_TAGS[cand]
    upper = filename.upper()
    token, ru = modifier_word(upper)
    if token:
        return base + ": " + ru + tier_suffix(upper)
    # Fallback for plain weapon-name files (Spear_CRIT etc.)
    if weapon_tag.lower() in upper:
        stem = strip_tier(upper)
        token2, ru2 = modifier_word(stem)
        if token2:
            return base + ": " + ru2 + tier_suffix(upper)
    if weapon_tag in ["Bow", "Spear", "Aura", "Staff", "LightningStaff", "SingularityStaff", "StarStaff"]:
        tier = tier_suffix(upper)
        if tier:
            return base + ": " + "Урон" + tier
    return base + ": " + name


def build_icon(filename, name, weapon_tag, passive_id, path):
    if "Evolution" in os.path.basename(path):
        return "Icon_12.png"
    if weapon_tag not in ("", "General", "Damage"):
        return TAG_ICON.get(weapon_tag, "Icon_09.png")
    if passive_id != "":
        _, ic = PASSIVE_DATA.get(passive_id, ("", "Icon_04.png"))
        return ic
    if filename in BOOK_NAMES or name in BOOK_NAMES:
        return "Icon_11.png"
    if filename in STONE_NAMES or name in STONE_NAMES:
        return "Icon_04.png"
    for base_name, (_ru, ic) in PASSIVE_DATA.items():
        if filename == base_name or filename == "Base" + base_name:
            return ic
    return "Icon_04.png"


def migrate_file(path, force):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    filename = os.path.splitext(os.path.basename(path))[0]
    name = read_str(text, "name")
    weapon_tag = read_str(text, "weapon_tag")
    passive_id = read_str(text, "passive_id")
    is_weapon = read_bool(text, "is_weapon")

    icon_name = build_icon(filename, name, weapon_tag, passive_id, path)
    uid = ICONS[icon_name]

    existing_disp = read_str(text, "display_name")
    changed = False

    # Icon: always repair (deterministic).
    if "icon = ExtResource(\"ic_upg\")" not in text:
        text = re.sub(r'^icon\s*=.*$', '', text, flags=re.MULTILINE)
        text = re.sub(r'\[ext_resource type="Texture2D".*id="ic_upg"\]\n', '', text, flags=re.MULTILINE)
        ext_line = '[ext_resource type="Texture2D" uid="%s" path="%s/%s" id="ic_upg"]\n' % (uid, ICON_BASE, icon_name)
        if "[resource]" in text:
            text = text.replace("[resource]", ext_line + "[resource]", 1)
        else:
            text += "\n" + ext_line + "[resource]\n"
        m = re.search(r'^script\s*=\s*ExtResource\("[^"]+"\)\s*$', text, re.MULTILINE)
        insert = 'icon = ExtResource("ic_upg")\n'
        if m:
            text = text[:m.end()] + "\n" + insert + text[m.end():]
        else:
            text = text.replace("[resource]\n", "[resource]\n" + insert, 1)
        changed = True

    # display_name: only fill when missing, or rebuild with --force.
    do_disp = existing_disp == ""
    if force and existing_disp != "":
        do_disp = True
    if do_disp:
        # Remove old value/ref if rebuilding.
        text = re.sub(r'^display_name\s*=.*$', '', text, flags=re.MULTILINE)
        disp = build_display_name(filename, name, weapon_tag, passive_id, is_weapon, path)
        insert = 'display_name = "%s"\n' % esc(disp)
        m = re.search(r'^script\s*=\s*ExtResource\("[^"]+"\)\s*$', text, re.MULTILINE)
        if m:
            text = text[:m.end()] + "\n" + insert + text[m.end():]
        else:
            text = text.replace("[resource]\n", "[resource]\n" + insert, 1)
        changed = True

    if changed:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        return True
    return False


def main():
    force = "--force" in sys.argv
    total = updated = 0
    skipped_existing = 0
    for root, _dirs, files in os.walk(BASE):
        for fn in files:
            if not fn.endswith(".tres"):
                continue
            path = os.path.join(root, fn)
            total += 1
            if migrate_file(path, force):
                updated += 1
            else:
                skipped_existing += 1
    print("Done. Total: %d, Updated: %d, Preserved-existing: %d (force=%s)" % (
        total, updated, skipped_existing, force))


if __name__ == "__main__":
    main()