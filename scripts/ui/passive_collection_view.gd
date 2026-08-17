extends VBoxContainer
class_name PassiveCollectionView
## PassiveCollectionView — самостоятельное представление вкладки «Пассивки» в CollectionScreen.
## Формат (аналогичен вкладке «Оружие»): симметричная сетка 2 колонки,
## карточки фиксированного размера с иконкой 32x32, названием, статусом
## и прогресс-баром фрагментов X/50 у заблокированных.

const GACHA_DATA := preload("res://scripts/gacha_data.gd")

## Порядок пассивок в коллекции. Первая — стартовая «Урон» (всегда открыта).
const PASSIVE_ORDER: Array[String] = [
    "passive_damage",
    "passive_max_hp",
    "passive_hp_regen",
    "passive_attack_speed",
    "passive_move_speed",
    "passive_attack_range",
    "passive_amount",
    "passive_crit_chance",
    "passive_luck",
    "passive_experience",
    "passive_gold",
]

## Иконки пассивок: из ресурсов Upgrade (поле icon).
const PASSIVE_ICON_PATHS: Dictionary = {
    "passive_damage": "res://Upgrades/Passives/Damage_C.tres",
    "passive_max_hp": "res://Upgrades/Passives/Stone_HP_C.tres",
    "passive_hp_regen": "res://Upgrades/Passives/HPRegen_C.tres",
    "passive_attack_speed": "res://Upgrades/Passives/AttackSpeed_C.tres",
    "passive_move_speed": "res://Upgrades/Passives/Speed_C.tres",
    "passive_attack_range": "res://Upgrades/Passives/Book_RAD_C.tres",
    "passive_amount": "res://Upgrades/Passives/Amount/Amount_C.tres",
    "passive_crit_chance": "res://Upgrades/Passives/CritChance_C.tres",
    "passive_luck": "res://Upgrades/Passives/Luck_C.tres",
    "passive_experience": "res://Upgrades/Passives/ExperienceGain_C.tres",
    "passive_gold": "res://Upgrades/Passives/GoldGain_C.tres",
}

## Стартовая пассивка (всегда открыта) — как в collection_screen.gd.
const STARTING_PASSIVE_ID: String = "passive_damage"

# ── Палитра (та же, что во вкладке «Оружие») ──
const ACCENT_COLOR := Color(1, 0.85, 0.4, 1)
const MUTED_TEXT_COLOR := Color(0.62, 0.62, 0.68, 1.0)
const GREEN_OK := Color(0.29, 0.72, 0.39, 1.0)
const LOCKED_DIM := Color(0.72, 0.72, 0.78, 1.0)

# ── Размеры иконок (строго 32x32, без растяжки пиксель-арта) ──
const ICON_SIZE := Vector2(32, 32)

# ── Цвета прогресс-бара фрагментов ──
const PROGRESS_BG_COLOR := Color(0.3, 0.32, 0.42, 0.9)
const PROGRESS_FILL_COLOR := Color(0.29, 0.72, 0.39, 1.0)
const PROGRESS_BORDER_COLOR := Color(0.45, 0.46, 0.58, 0.9)
const PROGRESS_BAR_HEIGHT := 10

# ── Цвета карточек (полупрозрачные, те же, что в коллекции) ──
const CARD_BG := Color(0.1, 0.1, 0.16, 0.55)
const CARD_BG_LOCKED := Color(0.07, 0.07, 0.1, 0.85)
const CARD_BORDER := Color(0.22, 0.22, 0.32, 1)
const CARD_BORDER_LOCKED := Color(0.16, 0.16, 0.24, 1)

# ── Жёсткий размер карточек — выше, чем в «Оружии» (123), чтобы название
# ── пассивки (до 2 строк с переносом) помещалось без выхода за рамку. ──
const CARD_HEIGHT := 145

# ── Узлы сцены ──
@onready var grid: GridContainer = %PassiveGrid

## Локальное состояние выбранной пассивки.
var _selected_passive_id: String = STARTING_PASSIVE_ID
var _cards: Array[Control] = []


func _ready() -> void:
    _build_cards()
    _refresh_view()


# ── Построение сетки карточек ──

func _build_cards() -> void:
    for i in PASSIVE_ORDER.size():
        var passive_id: String = PASSIVE_ORDER[i]
        var card := PanelContainer.new()
        # Жёсткий фиксированный размер — открытые и заблокированные карточки одинаковой высоты.
        card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

        var vbox := VBoxContainer.new()
        vbox.name = "VBox"
        vbox.add_theme_constant_override("separation", 3)
        vbox.alignment = BoxContainer.ALIGNMENT_CENTER
        vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        card.add_child(vbox)

        # Иконка 32x32 строго в оригинальном размере (KEEP_CENTERED).
        var icon_rect := TextureRect.new()
        icon_rect.name = "PassiveIcon"
        icon_rect.custom_minimum_size = ICON_SIZE
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        icon_rect.texture = _load_passive_icon(passive_id)
        icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        vbox.add_child(icon_rect)

        # Название — до 2 строк с переносом (длинные русские названия
        # не распирают карточку по ширине).
        var name_label := Label.new()
        name_label.name = "NameLabel"
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.add_theme_font_size_override("font_size", 14)
        name_label.add_theme_color_override("font_color", ACCENT_COLOR)
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(name_label)

        # Статус (✔ Открыто / 🔒).
        var status_label := Label.new()
        status_label.name = "StatusLabel"
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        status_label.add_theme_font_size_override("font_size", 12)
        status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(status_label)

        # Прогресс-бар фрагментов (только для заблокированных).
        var progress_bar := ProgressBar.new()
        progress_bar.name = "FragProgress"
        progress_bar.custom_minimum_size = Vector2(0, PROGRESS_BAR_HEIGHT)
        progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        progress_bar.show_percentage = false
        progress_bar.max_value = 1.0
        progress_bar.value = 0.0
        progress_bar.add_theme_stylebox_override("background", _make_progress_bg_style())
        progress_bar.add_theme_stylebox_override("fill", _make_progress_fill_style())
        vbox.add_child(progress_bar)

        # Текст X/50 под полоской.
        var frag_label := Label.new()
        frag_label.name = "FragLabel"
        frag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        frag_label.add_theme_font_size_override("font_size", 11)
        frag_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
        frag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(frag_label)

        card.gui_input.connect(_on_card_gui_input.bind(i))
        card.set_meta("passive_id", passive_id)
        card.set_meta("index", i)

        grid.add_child(card)
        _cards.append(card)


func _make_progress_bg_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = PROGRESS_BG_COLOR
    sb.border_color = PROGRESS_BORDER_COLOR
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(5)
    sb.content_margin_left = 0
    sb.content_margin_top = 0
    sb.content_margin_right = 0
    sb.content_margin_bottom = 0
    return sb


func _make_progress_fill_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = PROGRESS_FILL_COLOR
    sb.set_corner_radius_all(5)
    sb.content_margin_left = 0
    sb.content_margin_top = 0
    sb.content_margin_right = 0
    sb.content_margin_bottom = 0
    return sb


func _load_passive_icon(passive_id: String) -> Texture2D:
    var path: String = String(PASSIVE_ICON_PATHS.get(passive_id, ""))
    if path == "":
        return null
    var up := load(path) as Upgrade
    return up.icon if up != null else null


func _on_card_gui_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _selected_passive_id = PASSIVE_ORDER[index]
        _refresh_view()


# ── Данные пассивок ──

func _is_unlocked(passive_id: String, meta: Node) -> bool:
    if passive_id == STARTING_PASSIVE_ID:
        return true
    return meta != null and meta.is_passive_unlocked(passive_id)


func _get_fragments(passive_id: String, meta: Node) -> int:
    if meta == null:
        return 0
    return meta.get_fragment_count(passive_id)


func _get_req_fragments(passive_id: String) -> int:
    var entry: Variant = GACHA_DATA.CONTENT.get(passive_id, {})
    if typeof(entry) == TYPE_DICTIONARY:
        return int(entry.get("req_fragments", 0))
    return 0


# ── Обновление представления ──

func _refresh_view() -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    _refresh_cards(meta)


## Обновляет карточки: открытые — ✔ Открыто, заблокированные — 🔒 Фрагменты + ProgressBar + X/50.
func _refresh_cards(meta: Node) -> void:
    for i in _cards.size():
        var card := _cards[i] as PanelContainer
        var passive_id: String = PASSIVE_ORDER[i]
        var unlocked: bool = _is_unlocked(passive_id, meta)
        var active: bool = passive_id == _selected_passive_id

        card.add_theme_stylebox_override("panel", _make_card_style(active, unlocked))
        card.modulate = Color.WHITE if unlocked else LOCKED_DIM

        var icon_rect := card.get_node_or_null("VBox/PassiveIcon") as TextureRect
        if icon_rect:
            icon_rect.modulate = Color.WHITE if unlocked else LOCKED_DIM

        var name_label := card.get_node_or_null("VBox/NameLabel") as Label
        if name_label:
            name_label.text = _get_passive_name(passive_id)

        var status_label := card.get_node_or_null("VBox/StatusLabel") as Label
        var progress_bar := card.get_node_or_null("VBox/FragProgress") as ProgressBar
        var frag_label := card.get_node_or_null("VBox/FragLabel") as Label
        if status_label == null or progress_bar == null or frag_label == null:
            continue

        if unlocked:
            progress_bar.visible = false
            frag_label.visible = false
            status_label.text = "✔ Открыто"
            status_label.add_theme_color_override("font_color", GREEN_OK)
            status_label.add_theme_font_size_override("font_size", 12)
        else:
            var have: int = _get_fragments(passive_id, meta)
            var req: int = _get_req_fragments(passive_id)
            progress_bar.visible = true
            frag_label.visible = true
            progress_bar.max_value = 1.0
            progress_bar.value = float(have) / float(req) if req > 0 else 0.0
            frag_label.text = "%d/%d" % [have, req]
            status_label.text = "🔒 Фрагменты"
            status_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
            status_label.add_theme_font_size_override("font_size", 12)


func _get_passive_name(passive_id: String) -> String:
    var entry: Variant = GACHA_DATA.CONTENT.get(passive_id, {})
    if typeof(entry) == TYPE_DICTIONARY:
        return String(entry.get("display_name", passive_id))
    return passive_id


## Стиль карточки: активная (выбранная) — золотая рамка 2px,
## неактивная — серая рамка 1px. Заблокированные — тёмный фон.
func _make_card_style(active: bool, unlocked: bool) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = CARD_BG if unlocked else CARD_BG_LOCKED
    if active:
        sb.border_color = ACCENT_COLOR
        sb.set_border_width_all(2)
    else:
        sb.border_color = CARD_BORDER if unlocked else CARD_BORDER_LOCKED
        sb.set_border_width_all(1)
    sb.set_corner_radius_all(8)
    sb.content_margin_left = 8
    sb.content_margin_top = 8
    sb.content_margin_right = 8
    sb.content_margin_bottom = 8
    return sb