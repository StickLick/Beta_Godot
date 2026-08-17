extends VBoxContainer
class_name WeaponCollectionView
## WeaponCollectionView — самостоятельное представление вкладки «Оружие» в CollectionScreen.
## Формат: симметричная сетка карточек (2 колонки).
## Каждая карточка: иконка 32x32 (без растяжки), название, статус,
## для заблокированных — прогресс-бар фрагментов X/80.

const GACHA_DATA := preload("res://scripts/gacha_data.gd")

## Порядок оружий в коллекции. Первое — стартовое Копьё (всегда открыто).
const WEAPON_ORDER: Array[String] = [
    "weapon_spear",
    "weapon_aura",
    "weapon_bow",
    "weapon_staff",
    "weapon_banner",
]

## Иконки оружий: из базовых ресурсов Upgrade (поле icon).
const WEAPON_ICON_PATHS: Dictionary = {
    "weapon_spear": "res://Upgrades/Weapons/Spear/BaseSpear.tres",
    "weapon_aura": "res://Upgrades/Weapons/Aura/BaseAura.tres",
    "weapon_bow": "res://Upgrades/Weapons/Bow/BaseBow.tres",
    "weapon_staff": "res://Upgrades/Weapons/Staff/BaseStaff.tres",
    "weapon_banner": "res://Upgrades/Weapons/Banner/BaseBanner.tres",
}

## Русские имена оружий.
const WEAPON_NAMES: Dictionary = {
    "weapon_spear": "Копьё",
    "weapon_aura": "Аура",
    "weapon_bow": "Лук",
    "weapon_staff": "Посох",
    "weapon_banner": "Знамя",
}

## Описания оружий (короткие, 1-2 строки).
const WEAPON_DESCRIPTIONS: Dictionary = {
    "weapon_spear": "Копьё ближнего боя",
    "weapon_aura": "Урон по области",
    "weapon_bow": "Стрелы по врагам",
    "weapon_staff": "Магические заклинания",
    "weapon_banner": "Поддержка союзников",
}

# ── Палитра (тема коллекции) ──
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

# ── Цвета мини-карточек (полупрозрачные, те же, что в коллекции) ──
const CARD_BG := Color(0.1, 0.1, 0.16, 0.55)
const CARD_BG_LOCKED := Color(0.07, 0.07, 0.1, 0.85)
const CARD_BORDER := Color(0.22, 0.22, 0.32, 1)
const CARD_BORDER_LOCKED := Color(0.16, 0.16, 0.24, 1)

# ── Узлы сцены ──
@onready var grid: GridContainer = %WeaponGrid

## Локальное состояние выбранного оружия.
var _selected_weapon_id: String = "weapon_spear"
var _cards: Array[Control] = []


func _ready() -> void:
    _build_cards()
    _refresh_view()


func _current_weapon_id() -> String:
    return _selected_weapon_id


# ── Построение сетки карточек ──

func _build_cards() -> void:
    for i in WEAPON_ORDER.size():
        var weapon_id: String = WEAPON_ORDER[i]
        var card := PanelContainer.new()
        # Жёсткий фиксированный размер: открытые и заблокированные карточки
        # одинаковой высоты (прогресс-бар + счётчик фрагментов вмещаются).
        card.custom_minimum_size = Vector2(0, 123)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

        var vbox := VBoxContainer.new()
        vbox.name = "VBox"
        vbox.add_theme_constant_override("separation", 3)
        vbox.alignment = BoxContainer.ALIGNMENT_CENTER
        vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        card.add_child(vbox)

        # Иконка 32x32 строго в оригинальном размере (KEEP_CENTERED, не растягиваем).
        var icon_rect := TextureRect.new()
        icon_rect.name = "WeaponIcon"
        icon_rect.custom_minimum_size = ICON_SIZE
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        icon_rect.texture = _load_weapon_icon(weapon_id)
        icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        vbox.add_child(icon_rect)

        # Название.
        var name_label := Label.new()
        name_label.name = "NameLabel"
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.add_theme_font_size_override("font_size", 14)
        name_label.add_theme_color_override("font_color", ACCENT_COLOR)
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

        # Текст X/80 под полоской.
        var frag_label := Label.new()
        frag_label.name = "FragLabel"
        frag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        frag_label.add_theme_font_size_override("font_size", 11)
        frag_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
        frag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(frag_label)

        card.gui_input.connect(_on_card_gui_input.bind(i))
        card.set_meta("weapon_id", weapon_id)
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


func _load_weapon_icon(weapon_id: String) -> Texture2D:
    var path: String = String(WEAPON_ICON_PATHS.get(weapon_id, ""))
    if path == "":
        return null
    var up := load(path) as Upgrade
    return up.icon if up != null else null


func _on_card_gui_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _selected_weapon_id = WEAPON_ORDER[index]
        _refresh_view()


# ── Данные оружия ──

func _is_unlocked(weapon_id: String, meta: Node) -> bool:
    if weapon_id == "weapon_spear":
        return true
    return meta != null and meta.is_weapon_unlocked(weapon_id)


func _get_fragments(weapon_id: String, meta: Node) -> int:
    if meta == null:
        return 0
    return meta.get_fragment_count(weapon_id)


func _get_req_fragments(weapon_id: String) -> int:
    var entry: Variant = GACHA_DATA.CONTENT.get(weapon_id, {})
    if typeof(entry) == TYPE_DICTIONARY:
        return int(entry.get("req_fragments", 0))
    return 0


# ── Обновление представления ──

func _refresh_view() -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    _refresh_cards(meta)


## Обновляет карточки: редкость открытых (✔ Открыто + описание),
## заблокированные — 🔒 Фрагменты + ProgressBar + X/80.
func _refresh_cards(meta: Node) -> void:
    for i in _cards.size():
        var card := _cards[i] as PanelContainer
        var weapon_id: String = WEAPON_ORDER[i]
        var unlocked: bool = _is_unlocked(weapon_id, meta)
        var active: bool = weapon_id == _selected_weapon_id

        card.add_theme_stylebox_override("panel", _make_card_style(active, unlocked))
        card.modulate = Color.WHITE if unlocked else LOCKED_DIM

        var icon_rect := card.get_node_or_null("VBox/WeaponIcon") as TextureRect
        if icon_rect:
            icon_rect.modulate = Color.WHITE if unlocked else LOCKED_DIM

        var name_label := card.get_node_or_null("VBox/NameLabel") as Label
        if name_label:
            name_label.text = String(WEAPON_NAMES.get(weapon_id, weapon_id))

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
            var have: int = _get_fragments(weapon_id, meta)
            var req: int = _get_req_fragments(weapon_id)
            progress_bar.visible = true
            frag_label.visible = true
            progress_bar.max_value = 1.0
            progress_bar.value = float(have) / float(req) if req > 0 else 0.0
            frag_label.text = "%d/%d" % [have, req]
            status_label.text = "🔒 Фрагменты"
            status_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
            status_label.add_theme_font_size_override("font_size", 12)


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
