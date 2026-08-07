extends RefCounted
class_name HeroData
## HeroData — конфигурация героев (данные, без логики).
## Доступ через preload("res://scripts/hero_data.gd").

## Ид героя по умолчанию (всегда разблокирован).
const DEFAULT_HERO_ID: String = "hero_spearman"

## Справочник героев.
## Ключ = hero_id. Значения:
##   display_name     — имя для UI
##   description      — описание для UI
##   starting_weapon_upgrade — res:// путь к базовому ресурсу оружия (Upgrade)
##   weapon_tag       — оружейный тег (для tag_levels и фильтрации UpgradeMenu)
##   stat_modifiers   — аддитивные бонусы к статам персонажа
##   visual           — res:// путь к SpriteFrames визуала героя
##   hero_passive     — пассивка героя: stat + percent_per_level
##   passive_name     — название пассивки для UI
##   passive_description — описание пассивки для UI
const HEROES: Dictionary = {
	"hero_spearman": {
		"display_name": "Копейщик",
		"description": "Сбалансированный боец. Стартовое оружие: копьё.",
		"starting_weapon_upgrade": "res://Upgrades/Weapons/Spear/BaseSpear.tres",
		"weapon_scene": "res://Assets/Scenes/Weapons/SpearWeapon.tscn",
		"weapon_tag": "Spear",
		"stat_modifiers": {
			"damage_multiplier": 0.0,
			"radius_weapons": 0.0,
			"max_speed": 0.0,
			"max_health": 0.0,
			"xp_gain": 0.0,
		},
		"hero_passive": {
			"stat": "damage_multiplier",
			"percent_per_level": 0.01,
		},
		"passive_name": "Воинская подготовка",
		"passive_description": "+1% к урону всех оружий за уровень героя.",
		"visual": "res://Assets/SpriteFrames/SpearmanFrames.tres",
	},
	"hero_archer": {
		"display_name": "Лучник",
		"description": "Дальний бой. Стартовое оружие: лук. Бонус к дальности.",
		"starting_weapon_upgrade": "res://Upgrades/Weapons/Bow/BaseBow.tres",
		"weapon_scene": "res://Assets/Scenes/Weapons/BowWeapon.tscn",
		"weapon_tag": "Bow",
		"stat_modifiers": {
			"damage_multiplier": 0.0,
			"radius_weapons": 0.25,
			"max_speed": 0.0,
			"max_health": 0.0,
			"xp_gain": 0.0,
		},
		"hero_passive": {
			"stat": "crit_chance",
			"percent_per_level": 0.005,
		},
		"passive_name": "Меткость",
		"passive_description": "+0.5% к шансу критического удара за уровень героя.",
		"visual": "res://Assets/SpriteFrames/ArcherFrames.tres",
	},
	"hero_monk": {
		"display_name": "Монах",
		"description": "Мастер ауры. Стартовое оружие: аура. Бонус к радиусу ауры.",
		"starting_weapon_upgrade": "res://Upgrades/Weapons/Aura/BaseAura.tres",
		"weapon_scene": "res://Assets/Scenes/Weapons/AuraWeapon.tscn",
		"weapon_tag": "Aura",
		"stat_modifiers": {
			"damage_multiplier": 0.0,
			"radius_weapons": 0.5,
			"max_speed": 0.0,
			"max_health": 0.0,
			"xp_gain": 0.0,
		},
		"hero_passive": {
			"stat": "radius_weapons",
			"percent_per_level": 0.01,
		},
		"passive_name": "Расширение сознания",
		"passive_description": "+1% к размеру области оружия за уровень героя.",
		"visual": "res://Assets/SpriteFrames/MonkFrames.tres",
	},
}


## Вернуть конфиг героя по id; если нет — героя по умолчанию.
static func get_hero(hero_id: String) -> Dictionary:
	if HEROES.has(hero_id):
		return HEROES[hero_id]
	return HEROES[DEFAULT_HERO_ID]