extends Node
## SaveManager — персистентное сохранение мета-прогрессии.
## Дисковые операции изолированы здесь: GameManager/UI не работают с файлами напрямую.
## Формат JSON — простой и переносимый; позже сюда же подключится Yandex cloud save.

const SAVE_PATH: String = "user://save.json"

## Значения по умолчанию — единое место для всех полей мета-прогрессии.
const DEFAULTS: Dictionary = {
	"meta_currency": 0,
	"unlocked_weapon_slots": 1,
	"unlocked_passive_slots": 1,
	"unlocked_weapons": [],
	"unlocked_passives": [],
	"unlocked_heroes": [],
	# Казино-система фрагментов:
	"fragments": {},
	"luck_streak": 0,
	# Будущее (не реализовано, только структура):
	# "chest_keys": 0,
	# "rts_camp_levels": {},
}

var _data: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	_data = DEFAULTS.duplicate(true)
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	# Сохраняем только известные ключи (устойчивость к устаревшим/чужим данным).
	for key in DEFAULTS:
		if key in parsed:
			_data[key] = parsed[key]


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: не удалось открыть файл для записи: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.flush()


func get_value(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default if default != null else DEFAULTS.get(key))


func set_value(key: String, value: Variant, autosave: bool = true) -> void:
	_data[key] = value
	if autosave:
		save_data()
