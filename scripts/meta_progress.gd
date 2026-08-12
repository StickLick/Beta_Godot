extends Node
## MetaProgress — бизнес-логика мета-прогрессии (покупки, слоты, разблокировки).
## Хранение данных — в SaveManager (диск), рантайм-курс — в GameManager.
## Здесь только правила: цены, лимиты, методы покупки/разблокировки.

## Лимиты слотов (максимум).
const MAX_WEAPON_SLOTS: int = 3
const MAX_PASSIVE_SLOTS: int = 3

## Цены улучшения слотов по шагам: [1->2, 2->3].
const WEAPON_SLOT_PRICES: Array[int] = [100, 250]
const PASSIVE_SLOT_PRICES: Array[int] = [100, 250]

## Постоянные улучшения героя (7 статов × 5 уровней).
## Ключ = upgrade_id. Значения:
##   display_name  — русское имя для UI
##   description   — русское описание для UI
##   stat          — стат Player, к которому применяется бонус
##   per_level     — прирост за уровень
##   prices        — цены за уровни [1->2, 2->3, 3->4, 4->5, 5->MAX]
const HERO_UPGRADES: Dictionary = {
	"hp": {
		"display_name": "Максимальное здоровье",
		"description": "Увеличивает максимальное здоровье героя.",
		"stat": "max_health",
		"per_level": 100.0,
		"prices": [100, 200, 350, 550, 800],
	},
	"damage": {
		"display_name": "Урон",
		"description": "Увеличивает урон всех оружий.",
		"stat": "damage_multiplier",
		"per_level": 0.05,
		"prices": [100, 200, 350, 550, 800],
	},
	"move_speed": {
		"display_name": "Скорость передвижения",
		"description": "Увеличивает скорость передвижения героя.",
		"stat": "max_speed",
		"per_level": 15.0,
		"prices": [80, 160, 280, 450, 700],
	},
	"luck": {
		"display_name": "Удача",
		"description": "Увеличивает шанс выпадения редких улучшений.",
		"stat": "luck",
		"per_level": 0.1,
		"prices": [120, 240, 400, 650, 950],
	},
	"attack_speed": {
		"display_name": "Скорость атаки",
		"description": "Увеличивает скорость атаки всех оружий.",
		"stat": "attack_speed",
		"per_level": 0.1,
		"prices": [150, 300, 500, 800, 1200],
	},
	"attack_range": {
		"display_name": "Радиус атаки",
		"description": "Увеличивает радиус действия всех оружий.",
		"stat": "radius_weapons",
		"per_level": 0.1,
		"prices": [120, 240, 400, 650, 950],
	},
	"hp_regen": {
		"display_name": "Регенерация здоровья",
		"description": "Восстанавливает % от максимального здоровья в секунду.",
		"stat": "health_regen",
		"per_level": 0.005,
		"prices": [150, 300, 500, 800, 1200],
	},
}

## Максимальный уровень каждого постоянного улучшения героя.
const MAX_HERO_UPGRADE_LEVEL: int = 5

## Цены разблокировки уровней шахты: [1->2, 2->3, 3->4, 4->5].
const MINE_LEVEL_PRICES: Array[int] = [150, 300, 500, 800]

## Максимальный уровень шахты (Mine + Outpost — единая система).
const MAX_MINE_LEVEL: int = 5


func _ready() -> void:
	pass


# --- ВАЛЮТА (рантайм-источник — GameManager, персистенция — SaveManager) ---

func get_currency() -> int:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_meta_currency"):
		return gm.get_meta_currency()
	var sm := get_node_or_null("/root/SaveManager")
	return int(sm.get_value("meta_currency", 0)) if sm else 0


func can_afford(price: int) -> bool:
	return get_currency() >= price


func spend_currency(price: int) -> bool:
	if price <= 0:
		return true
	if not can_afford(price):
		return false
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("set_meta_currency"):
		gm.set_meta_currency(get_currency() - price)
		return true
	return false


# --- СЛОТЫ ---

func get_weapon_slots() -> int:
	var sm := get_node_or_null("/root/SaveManager")
	return int(sm.get_value("unlocked_weapon_slots", 1)) if sm else 1


func get_passive_slots() -> int:
	var sm := get_node_or_null("/root/SaveManager")
	return int(sm.get_value("unlocked_passive_slots", 1)) if sm else 1


## Цена следующего улучшения слота; -1 = уже максимум.
func get_weapon_slot_upgrade_price() -> int:
	return _slot_upgrade_price(get_weapon_slots(), WEAPON_SLOT_PRICES, MAX_WEAPON_SLOTS)


func get_passive_slot_upgrade_price() -> int:
	return _slot_upgrade_price(get_passive_slots(), PASSIVE_SLOT_PRICES, MAX_PASSIVE_SLOTS)


func _slot_upgrade_price(current: int, prices: Array, max_slots: int) -> int:
	if current >= max_slots or current - 1 >= prices.size():
		return -1
	return prices[current - 1]


func increase_weapon_slots() -> bool:
	return _increase_slots("unlocked_weapon_slots", get_weapon_slot_upgrade_price(), MAX_WEAPON_SLOTS)


func increase_passive_slots() -> bool:
	return _increase_slots("unlocked_passive_slots", get_passive_slot_upgrade_price(), MAX_PASSIVE_SLOTS)


func _increase_slots(save_key: String, price: int, max_slots: int) -> bool:
	if price < 0:
		return false
	if not spend_currency(price):
		return false
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return false
	var current := int(sm.get_value(save_key, 1))
	sm.set_value(save_key, min(current + 1, max_slots))
	return true


# --- ФРАГМЕНТЫ (казино-система) ---

## Справочник контента — подключён через preload, как и в GachaManager.
const GACHA_DATA := preload("res://scripts/gacha_data.gd")


## Добавить фрагменты; при достижении порога — авто-разблокировка.
func add_fragments(content_id: String, amount: int) -> void:
	if amount <= 0 or content_id.is_empty():
		return
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return
	var frags: Dictionary = sm.get_value("fragments", {})
	frags[content_id] = int(frags.get(content_id, 0)) + amount
	sm.set_value("fragments", frags)
	_try_auto_unlock(content_id)


## Текущее количество фрагментов контента.
func get_fragment_count(content_id: String) -> int:
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return 0
	var frags: Dictionary = sm.get_value("fragments", {})
	return int(frags.get(content_id, 0))


## Все фрагменты: {content_id: amount}.
func get_all_fragments() -> Dictionary:
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return {}
	var frags: Dictionary = sm.get_value("fragments", {})
	return frags.duplicate()


## Проверка порога: фрагменты >= требуется → списать, разблокировать.
func _try_auto_unlock(content_id: String) -> bool:
	var entry: Variant = GACHA_DATA.CONTENT.get(content_id)
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var req: int = int(entry.get("req_fragments", 0))
	if req <= 0:
		return false
	if get_fragment_count(content_id) < req:
		return false

	# Списать фрагменты (перекрываем порог).
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return false
	var frags: Dictionary = sm.get_value("fragments", {})
	frags[content_id] = int(frags.get(content_id, 0)) - req
	sm.set_value("fragments", frags)

	# Разблокировать по категории.
	var category: String = String(entry.get("category", ""))
	match category:
		"hero":
			return unlock_hero(content_id)
		"weapon":
			return unlock_weapon(content_id)
		"passive":
			return unlock_passive(content_id)
	return false


# --- РАЗБЛОКИРОВКИ (структура для будущего; пулы оружия/пассивок/героев появятся позже) ---

func is_weapon_unlocked(weapon_id: String) -> bool:
	return _is_in_list("unlocked_weapons", weapon_id)


func is_passive_unlocked(passive_id: String) -> bool:
	return _is_in_list("unlocked_passives", passive_id)


func is_hero_unlocked(hero_id: String) -> bool:
	return _is_in_list("unlocked_heroes", hero_id)


func unlock_weapon(weapon_id: String) -> bool:
	return _add_to_list("unlocked_weapons", weapon_id)


func unlock_passive(passive_id: String) -> bool:
	return _add_to_list("unlocked_passives", passive_id)


func unlock_hero(hero_id: String) -> bool:
	return _add_to_list("unlocked_heroes", hero_id)


# --- ЭВОЛЮЦИИ (коллекция; не покупаются, не выпадают из гачи) ---

## Получена ли эволюция игроком (по имени Upgrade).
func is_evolution_unlocked(evolution_name: String) -> bool:
	return _is_in_list("unlocked_evolutions", evolution_name)


## Все полученные эволюции (по имени Upgrade).
func get_unlocked_evolutions() -> Array:
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return []
	return sm.get_value("unlocked_evolutions", [])


## Записать эволюцию как полученную (идемпотентно).
func unlock_evolution(evolution_name: String) -> bool:
	if evolution_name.is_empty():
		return false
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return false
	var list: Array = sm.get_value("unlocked_evolutions", [])
	if list.has(evolution_name):
		return false
	list.append(evolution_name)
	sm.set_value("unlocked_evolutions", list)
	return true


func _is_in_list(save_key: String, item_id: String) -> bool:
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return false
	var list: Array = sm.get_value(save_key, [])
	return list.has(item_id)


func _add_to_list(save_key: String, item_id: String) -> bool:
	if item_id.is_empty():
		return false
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return false
	var list: Array = sm.get_value(save_key, [])
	if list.has(item_id):
		return false
	list.append(item_id)
	sm.set_value(save_key, list)
	return true


# --- ПОСТОЯННЫЕ УЛУЧШЕНИЯ ГЕРОЯ (7 статов × 5 уровней) ---

## Текущий уровень улучшения героя (0-5).
func get_hero_upgrade_level(upgrade_id: String) -> int:
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return 0
	var levels: Dictionary = sm.get_value("hero_upgrade_levels", {})
	return int(levels.get(upgrade_id, 0))


## Конфиг улучшения по id (пустой словарь, если нет).
func get_hero_upgrade_config(upgrade_id: String) -> Dictionary:
	var entry: Variant = HERO_UPGRADES.get(upgrade_id)
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return (entry as Dictionary).duplicate()


## Все купленные уровни: {upgrade_id: level}.
func get_all_hero_upgrade_levels() -> Dictionary:
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return {}
	var levels: Dictionary = sm.get_value("hero_upgrade_levels", {})
	return levels.duplicate()


## Текущий уровень улучшения (1-5). Возвращает 0, если не куплено.
func get_hero_upgrade_level_value(upgrade_id: String) -> int:
	return get_hero_upgrade_level(upgrade_id)


## Цена следующего уровня улучшения; -1 = уже максимум.
func get_hero_upgrade_price(upgrade_id: String) -> int:
	var cfg := get_hero_upgrade_config(upgrade_id)
	if cfg.is_empty():
		return -1
	var level: int = get_hero_upgrade_level(upgrade_id)
	return get_hero_upgrade_level_price(upgrade_id, level)


## Цена конкретного уровня (0-based index в prices); -1 = максимум.
func get_hero_upgrade_level_price(upgrade_id: String, level: int) -> int:
	var cfg := get_hero_upgrade_config(upgrade_id)
	if cfg.is_empty():
		return -1
	if level >= MAX_HERO_UPGRADE_LEVEL or level < 0:
		return -1
	var prices: Array = cfg.get("prices", [])
	if level >= prices.size():
		return -1
	return int(prices[level])


## Купить следующий уровень улучшения. Возвращает true при успехе.
func buy_hero_upgrade(upgrade_id: String) -> bool:
	if not HERO_UPGRADES.has(upgrade_id):
		return false
	var price: int = get_hero_upgrade_price(upgrade_id)
	if price < 0:
		return false
	if not spend_currency(price):
		return false
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return false
	var levels: Dictionary = sm.get_value("hero_upgrade_levels", {})
	levels[upgrade_id] = int(levels.get(upgrade_id, 0)) + 1
	sm.set_value("hero_upgrade_levels", levels)
	return true


# --- ШАХТА (Mine + Outpost — единая система) ---

## Текущий разблокированный уровень шахты (1-5).
func get_mine_level() -> int:
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return 1
	return int(sm.get_value("mine_unlocked_level", 1))


## Цена разблокировки следующего уровня шахты; -1 = уже максимум.
func get_mine_level_upgrade_price() -> int:
	var current: int = get_mine_level()
	if current >= MAX_MINE_LEVEL or current - 1 >= MINE_LEVEL_PRICES.size():
		return -1
	return MINE_LEVEL_PRICES[current - 1]


## Купить следующий уровень шахты. Возвращает true при успехе.
func buy_mine_level() -> bool:
	var price: int = get_mine_level_upgrade_price()
	if price < 0:
		return false
	if not spend_currency(price):
		return false
	var sm := get_node_or_null("/root/SaveManager")
	if not sm:
		return false
	var current: int = get_mine_level()
	sm.set_value("mine_unlocked_level", min(current + 1, MAX_MINE_LEVEL))
	return true
