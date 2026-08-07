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