extends Control
## CollectionScreen — экран коллекции в стиле Hero Selection.
## Герои — крупные карточки; Оружия/Пассивки/Эволюции — 2 колонки.
## Источники данных: hero_data.gd (имена/стартовое оружие/бонусы) и
## gacha_data.CONTENT (оружия/пассивки). Только отображение — логика открытия
## и системы гачи/сохранения не меняются.

const HERO_DATA := preload("res://scripts/hero_data.gd")
const GACHA_DATA := preload("res://scripts/gacha_data.gd")

## Пути к эволюциям (ресурсы Upgrade). Все эволюции всегда видны в коллекции.
const EVOLUTION_PATHS: Array[String] = [
    "res://Upgrades/Evolutions/SpearEvolution.tres",
    "res://Upgrades/Evolutions/AuraEvolution.tres",
    "res://Upgrades/Evolutions/BowSiegeEvolution.tres",
    "res://Upgrades/Evolutions/BowSkyEvolution.tres",
    "res://Upgrades/Evolutions/BowSpectralEvolution.tres",
    "res://Upgrades/Evolutions/BannerEvolution.tres",
    "res://Upgrades/Evolutions/BannerArcherEvolution.tres",
    "res://Upgrades/Evolutions/BannerGrandMarshalEvolution.tres",
    "res://Upgrades/Evolutions/BannerIronBulwarkEvolution.tres",
    "res://Upgrades/Evolutions/StaffLightningEvolution.tres",
    "res://Upgrades/Evolutions/StaffSingularityEvolution.tres",
    "res://Upgrades/Evolutions/StaffStarEvolution.tres",
]

## Стартовое оружие Копейщика — всегда открыто в коллекции.
const STARTING_WEAPON_UPGRADE_PATH: String = "res://Upgrades/Weapons/Spear/BaseSpear.tres"

## Стартовая пассивка «Урон» — всегда открыта в коллекции.
const STARTING_PASSIVE_ID: String = "passive_damage"

## Русские имена тегов оружий (тот же источник ид, что у hero_data.weapon_tag).
const WEAPON_TAG_NAMES: Dictionary = {
    "Spear": "Копьё",
    "Aura": "Аура",
    "Bow": "Лук",
    "Staff": "Посох",
    "Banner": "Знамя",
}

## Русские имена тегов пассивок.
const PASSIVE_TAG_NAMES: Dictionary = {
    "AttackRange": "Радиус атаки",
    "ProjectileAmount": "Количество",
    "MaxHP": "Максимальное здоровье",
    "CritChance": "Критический шанс",
    "Speed": "Скорость передвижения",
    "Damage": "Урон",
    "Luck": "Удача",
    "HealthRegen": "Регенерация здоровья",
    "AttackSpeed": "Скорость атаки",
    "MoveSpeed": "Скорость передвижения",
    "ExperienceGain": "Опыт",
    "GoldGain": "Золото",
}

# ── Палитра (та же, что в HeroSelectScreen) ──
const ACCENT_COLOR := Color(1, 0.85, 0.4, 1)
const CARD_BG := Color(0.1, 0.1, 0.16, 1.0)
const CARD_BG_LOCKED := Color(0.07, 0.07, 0.1, 1.0)
const BORDER_NORMAL := Color(0.22, 0.22, 0.32, 1.0)
const BORDER_LOCKED := Color(0.16, 0.16, 0.24, 1.0)
const LOCKED_TEXT_COLOR := Color(0.62, 0.62, 0.68, 1.0)
const SECTION_COLOR := Color(1, 0.85, 0.4, 1)

# Внутренние отступы карточек. PanelContainer НЕ использует
# theme_override_constants/margin_* — он берёт отступы из StyleBox content margins.
const CARD_PAD_H: int = 6
const CARD_PAD_V: int = 6

var cards_container: VBoxContainer
var _cards: Array[Control] = []

# Текущая строка для 2-колоночной сетки (оружия/пассивки/эволюции).
var _current_row: HBoxContainer = null
var _row_count: int = 0


func _ready() -> void:
    cards_container = %CardsContainer as VBoxContainer
    refresh()


## Обновление коллекции: перестраивает карточки.
func refresh() -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    if meta == null:
        return
    _clear_cards()
    _build_collection_cards(meta)


func _clear_cards() -> void:
    _current_row = null
    _row_count = 0
    for c in _cards:
        if is_instance_valid(c):
            c.queue_free()
    _cards.clear()


## Создаёт секционный заголовок коллекции.
func _add_section(title: String) -> void:
    # Каждая секция начинает новую сетку (предотвращает смешение колонок между секциями).
    _current_row = null
    _row_count = 0
    var label := Label.new()
    label.text = title
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 22)
    label.add_theme_color_override("font_color", SECTION_COLOR)
    label.custom_minimum_size = Vector2(300, 30)
    cards_container.add_child(label)
    _cards.append(label)


## Начинает новую строку для 2-колоночной сетки (фиксированная ширина = ширина секции героев).
func _begin_row() -> void:
    _current_row = HBoxContainer.new()
    _current_row.add_theme_constant_override("separation", 10)
    _current_row.custom_minimum_size = Vector2(383, 0)
    cards_container.add_child(_current_row)
    _cards.append(_current_row)
    _row_count = 0


## Добавляет карточку. Если dual_column — раскладывает по 2 в строку.
func _add_item_card(unlocked: bool, name_lines: Array[String], lines: Array[String], dual_column: bool) -> void:
    var card := PanelContainer.new()
    if dual_column:
        if _current_row == null or _row_count >= 2:
            _begin_row()
        card.custom_minimum_size = Vector2(155, 0)
        _current_row.add_child(card)
        _row_count += 1
    else:
        card.custom_minimum_size = Vector2(320, 0)
        cards_container.add_child(card)
        _cards.append(card)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_child(vbox)
    # Карточки в 2-колоночной сетке занимают всю ширину строки поровну.
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    # Имя — всегда видно, по центру. Длинные имена переносятся на 2 строки.
    for ln in name_lines:
        var name_label := Label.new()
        name_label.text = ln
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name_label.add_theme_font_size_override("font_size", 17)
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        vbox.add_child(name_label)

    # Описание / статус. Статус ("Разблокировано") — всегда первая строка.
    for i in range(lines.size()):
        var ln: String = lines[i]
        var desc_label := Label.new()
        desc_label.text = ln
        desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc_label.add_theme_font_size_override("font_size", 13)
        desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if i == 0 and unlocked:
            # Статус "Разблокировано" — золотой акцент (как заголовки секций).
            desc_label.add_theme_color_override("font_color", ACCENT_COLOR)
        elif not unlocked:
            desc_label.add_theme_color_override("font_color", LOCKED_TEXT_COLOR)
        vbox.add_child(desc_label)

    # Визуальное состояние карточки.
    if unlocked:
        card.add_theme_stylebox_override("panel", _make_card_style(CARD_BG, BORDER_NORMAL, 1))
        card.modulate = Color.WHITE
    else:
        card.add_theme_stylebox_override("panel", _make_card_style(CARD_BG_LOCKED, BORDER_LOCKED, 1))
        card.modulate = Color(0.72, 0.72, 0.78, 1.0)

    if not dual_column:
        _cards.append(card)


## Стиль прямоугольной карточки со скруглёнными углами (как в HeroSelectScreen).
## ВАЖНО: PanelContainer берёт внутренние отступы ИЗ CONTENT MARGINS StyleBox,
## а не из theme_override_constants/margin_*. Без этих значений VBox прилипает
## к верхней границе и правки "margin_*" не дают видимого эффекта.
func _make_card_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(width)
    sb.set_corner_radius_all(8)
    sb.content_margin_left = CARD_PAD_H
    sb.content_margin_top = CARD_PAD_V
    sb.content_margin_right = CARD_PAD_H
    sb.content_margin_bottom = CARD_PAD_V
    return sb


## Сборка всех карточек коллекции по категориям.
func _build_collection_cards(meta: Node) -> void:
    _build_hero_section(meta)
    _build_weapon_section(meta)
    _build_passive_section(meta)
    _build_evolution_section(meta)


# ── ГЕРОИ (крупные карточки; данные из hero_data.gd) ──

func _build_hero_section(meta: Node) -> void:
    _add_section("ГЕРОИ")
    for cid in HERO_DATA.HEROES:
        var hero: Dictionary = HERO_DATA.get_hero(cid)
        var display_name: String = String(hero.get("display_name", cid))
        var unlocked: bool = cid == HERO_DATA.DEFAULT_HERO_ID or meta.is_hero_unlocked(cid)

        # Статус.
        var status: String
        if unlocked:
            status = "Разблокировано"
        else:
            var have: int = meta.get_fragment_count(cid)
            var req: int = 0
            var entry: Variant = GACHA_DATA.CONTENT.get(cid, {})
            if typeof(entry) == TYPE_DICTIONARY:
                req = int(entry.get("req_fragments", 0))
            status = "🔒 ЗАБЛОКИРОВАН — фрагменты: %d/%d" % [have, req]

        # Стартовое оружие из hero_data.weapon_tag (единый источник с Hero Selection).
        var weapon_name: String = WEAPON_TAG_NAMES.get(String(hero.get("weapon_tag", "")), String(hero.get("weapon_tag", "")))

        # Бонус героя из hero_data.passive_description (единый источник с Hero Selection).
        var bonus: String = String(hero.get("passive_description", ""))

        var lines: Array[String] = [status]
        if weapon_name != "":
            lines.append("Стартовое оружие: %s" % weapon_name)
        if bonus != "":
            lines.append("Бонус героя: %s" % bonus)
        _add_item_card(unlocked, [display_name], lines, false)


# ── ОРУЖИЯ (2 колонки; стартовое Копьё всегда открыто) ──

func _build_weapon_section(meta: Node) -> void:
    _add_section("ОРУЖИЕ")

    # Стартовое оружие Копейщика — всегда открыто (из ресурса BaseSpear.tres).
    var spear_up: Upgrade = load(STARTING_WEAPON_UPGRADE_PATH) as Upgrade
    var spear_name: String = WEAPON_TAG_NAMES.get("Spear", "Копьё")
    var spear_desc: String = spear_up.description if spear_up != null and spear_up.description != "" else ""
    var spear_lines: Array[String] = ["Разблокировано"]
    if spear_desc != "":
        spear_lines.append(spear_desc)
    _add_item_card(true, [spear_name], spear_lines, true)

    # Gacha-оружия (из GACHA_DATA.CONTENT) — без изменения логики.
    for cid in GACHA_DATA.CONTENT:
        var g_entry: Dictionary = GACHA_DATA.CONTENT[cid]
        if String(g_entry.get("category", "")) != "weapon":
            continue
        var display_name: String = String(g_entry.get("display_name", cid))
        var description: String = String(g_entry.get("description", ""))
        var unlocked: bool = meta.is_weapon_unlocked(cid)
        var lines: Array[String]
        if unlocked:
            lines = ["Разблокировано"]
            if description != "":
                lines.append(description)
        else:
            var have: int = meta.get_fragment_count(cid)
            var req: int = int(g_entry.get("req_fragments", 0))
            lines = ["🔒 ЗАБЛОКИРОВАНО — фрагменты: %d/%d" % [have, req]]
        _add_item_card(unlocked, [display_name], lines, true)


# ── ПАССИВКИ (2 колонки; стартовая «Урон» всегда открыта) ──

func _build_passive_section(meta: Node) -> void:
    _add_section("ПАССИВКИ")
    for cid in GACHA_DATA.CONTENT:
        var g_entry: Dictionary = GACHA_DATA.CONTENT[cid]
        if String(g_entry.get("category", "")) != "passive":
            continue
        var display_name: String = String(g_entry.get("display_name", cid))
        var description: String = String(g_entry.get("description", ""))
        var unlocked: bool = (cid == STARTING_PASSIVE_ID) or meta.is_passive_unlocked(cid)
        var lines: Array[String]
        if unlocked:
            lines = ["Разблокировано"]
            if description != "":
                lines.append(description)
        else:
            var have: int = meta.get_fragment_count(cid)
            var req: int = int(g_entry.get("req_fragments", 0))
            lines = ["🔒 ЗАБЛОКИРОВАНА — фрагменты: %d/%d" % [have, req]]
        _add_item_card(unlocked, [display_name], lines, true)


# ── ЭВОЛЮЦИИ (2 колонки) ──

func _build_evolution_section(meta: Node) -> void:
    _add_section("ЭВОЛЮЦИИ")
    for path in EVOLUTION_PATHS:
        var up: Upgrade = load(path) as Upgrade
        if up == null:
            continue
        var evo_name: String = up.name if up.name != "" else path.get_file().get_basename()
        var unlocked: bool = meta.is_evolution_unlocked(evo_name)
        var lines: Array[String]
        if unlocked:
            lines = ["Разблокировано"]
            if up.description != "":
                lines.append(up.description)
            # Требования: оружие + пассивка (только после разблокировки).
            var req_parts: Array[String] = []
            var w_name: String = WEAPON_TAG_NAMES.get(up.weapon_tag, up.weapon_tag)
            if w_name != "" and w_name != "General":
                req_parts.append("Требуется: %s" % w_name)
            if up.required_passive_tag != "":
                var p_name: String = PASSIVE_TAG_NAMES.get(up.required_passive_tag, up.required_passive_tag)
                if req_parts.is_empty():
                    req_parts.append("Требуется: %s" % p_name)
                else:
                    req_parts.append("+ %s" % p_name)
            if not req_parts.is_empty():
                lines.append(" ".join(req_parts))
        else:
            lines = ["????"]
        _add_item_card(unlocked, [evo_name], lines, true)


func _on_close_pressed() -> void:
    hide()
