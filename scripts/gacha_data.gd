extends RefCounted
class_name GachaData
## GachaData — конфигурация слот-машины фрагментов.
## Только данные/константы. Никакой логики.
## Доступ через preload("res://scripts/gacha_data.gd") — безопасно к кешу
## глобальных классов редактора (паттерн как с автозагрузками).

# Редкости (совпадают по смыслу с Upgrade.Rarity).
const RARITY_COMMON: int = 0
const RARITY_RARE: int = 1
const RARITY_EPIC: int = 2
const RARITY_LEGENDARY: int = 3

# Названия редкостей для UI/результата спина.
const RARITY_NAMES: Dictionary = {
	RARITY_COMMON: "common",
	RARITY_RARE: "rare",
	RARITY_EPIC: "epic",
	RARITY_LEGENDARY: "legendary",
}

# Количество горизонтальных реалов (максимум продолжений + 1).
const REEL_COUNT: int = 5

# Стоимость каждого шага. Индекс 0 = первый спин, 1 = продолжение на 2-й реал и т.д.
const SPIN_COSTS: Array[int] = [50, 60, 75, 90, 110]

# Шанс провала каждого реала. Индекс 0 = первый спин (всегда успех).
const FAIL_CHANCES: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6]

# Возврат при провале продолжения: часть стоимости шага (не фрагменты).
const CONTINUE_COMPENSATION_PCT: float = 0.35

# Базовые фрагменты за успешный символ (цвет = редкость).
const COLOR_FRAGMENTS: Dictionary = {
	RARITY_COMMON: 1,
	RARITY_RARE: 2,
	RARITY_EPIC: 3,
	RARITY_LEGENDARY: 5,
}

# Множитель комбо по суммарному числу символов одного цвета (не обязательно подряд).
# 1-2 символа = x1 (без бонуса). 3+ даёт множитель ниже.
const COMBO_MULTIPLIERS: Dictionary = {
	3: 2.0,
	4: 3.0,
	5: 5.0,
}

# Базовая выдаваемость фрагментов предмета за один успешный реал.
# Ключ = rarity. Значение = (min, max) фрагментов.
const FRAGMENT_DROP_RANGE: Dictionary = {
	RARITY_COMMON: [1, 1],
	RARITY_RARE: [1, 2],
	RARITY_EPIC: [2, 3],
	RARITY_LEGENDARY: [3, 5],
}

# Базовые веса цветов (редкостей) для ролла символа.
const BASE_WEIGHT: Dictionary = {
	RARITY_COMMON: 60,
	RARITY_RARE: 25,
	RARITY_EPIC: 12,
	RARITY_LEGENDARY: 3,
}

# Серия удачи: +STREAK_BONUS_PER_STEP к весу EPIC/LEGENDARY за каждый неудачный финальный результат.
const STREAK_BONUS_PER_STEP: float = 0.05

# Редкости, при выпадении которых streak сбрасывается в 0.
const STREAK_RESET_RARITIES: Array[int] = [RARITY_EPIC, RARITY_LEGENDARY]

# Символы цветов для отображения в UI реалов.
const COLOR_SYMBOLS: Dictionary = {
	RARITY_COMMON: "⚪",
	RARITY_RARE: "🔵",
	RARITY_EPIC: "🟣",
	RARITY_LEGENDARY: "🟡",
}

# Отображаемые имена цветов.
const COLOR_DISPLAY_NAMES: Dictionary = {
	RARITY_COMMON: "Белый",
	RARITY_RARE: "Синий",
	RARITY_EPIC: "Фиолетовый",
	RARITY_LEGENDARY: "Золотой",
}

# Цвета для отображения реалов в UI.
const COLOR_HEX: Dictionary = {
	RARITY_COMMON: Color("dddddd"),
	RARITY_RARE: Color("4499ff"),
	RARITY_EPIC: Color("aa55ff"),
	RARITY_LEGENDARY: Color("ffcc33"),
}

# Символ провала.
const FAIL_SYMBOL: String = "✕"

## Контент, разблокируемый фрагментами.
## Ключ = content_id (строка). Категория = куда попадает разблокировка.
## v1: только heroes. В будущем: weapon / passive / rts_upgrade.
const CONTENT: Dictionary = {
	"hero_archer": {
		"category": "hero",
		"rarity": RARITY_RARE,
		"req_fragments": 10,
		"display_name": "Лучник",
	},
	"hero_monk": {
		"category": "hero",
		"rarity": RARITY_EPIC,
		"req_fragments": 20,
		"display_name": "Монах",
	},
}