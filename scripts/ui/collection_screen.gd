extends Control
## CollectionScreen — экран коллекции.
## Показывает статус героев (разблокирован / прогресс фрагментов).
## Структура готова под будущие категории (оружия, пассивки) — расширяется
## добавлением секций в _build_collection_text().

const HERO_DATA := preload("res://scripts/hero_data.gd")
const GACHA_DATA := preload("res://scripts/gacha_data.gd")

@onready var collection_label: Label = %CollectionLabel


func _ready() -> void:
	refresh()


## Обновление текста коллекции.
func refresh() -> void:
	var meta := get_node_or_null("/root/MetaProgress")
	if meta == null:
		collection_label.text = "Мета-данные недоступны"
		return
	collection_label.text = _build_collection_text(meta)


## Сборка текста коллекции по категориям.
func _build_collection_text(meta: Node) -> String:
	var lines: Array[String] = []
	# Секция героев.
	for cid in HERO_DATA.HEROES:
		var hero: Dictionary = HERO_DATA.get_hero(cid)
		var display_name: String = String(hero.get("display_name", cid))
		# Редкость из GachaData (та же, что использует Slot-Luck).
		var entry: Variant = GACHA_DATA.CONTENT.get(cid, {})
		var rarity_name: String = "COMMON"
		if typeof(entry) == TYPE_DICTIONARY:
			rarity_name = String(GACHA_DATA.RARITY_NAMES.get(int(entry.get("rarity", GACHA_DATA.RARITY_COMMON)), "common")).to_upper()
		if cid == HERO_DATA.DEFAULT_HERO_ID:
			lines.append("%s [%s]: разблокирован" % [display_name, rarity_name])
		elif meta.is_hero_unlocked(cid):
			lines.append("%s [%s]: разблокирован" % [display_name, rarity_name])
		else:
			var have: int = meta.get_fragment_count(cid)
			var req: int = int(entry.get("req_fragments", 0)) if typeof(entry) == TYPE_DICTIONARY else 0
			lines.append("%s [%s]: %d/%d фрагментов" % [display_name, rarity_name, have, req])
	if lines.is_empty():
		lines.append("Нет героев")
	return "\n".join(lines)


func _on_close_pressed() -> void:
	hide()