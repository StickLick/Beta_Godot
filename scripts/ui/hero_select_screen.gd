extends Control
## HeroSelectScreen — выбор героя перед забегом.
## Разблокировка: hero_spearman всегда доступен; hero_archer/hero_monk —
## через MetaProgress.is_hero_unlocked(). Заблокированные показывают прогресс фрагментов
## и не могут быть выбраны. Карточки строятся из HeroData (визуал, пассивка).
## Выбор — кликом по всей карточке (только разблокированные); выделение акцентной рамкой.

const HERO_DATA := preload("res://scripts/hero_data.gd")
const GACHA_DATA := preload("res://scripts/gacha_data.gd")

## Акцентный цвет (золотой) — тот же, что у имён пассивок.
const ACCENT_COLOR := Color(1, 0.85, 0.4, 1)

## Цвета карточек — только оттенки существующей тёмной палитры + акцент.
const CARD_BG := Color(0.1, 0.1, 0.16, 0.55)
const CARD_BG_HOVER := Color(0.15, 0.15, 0.22, 0.85)
const CARD_BG_LOCKED := Color(0.07, 0.07, 0.1, 0.85)
const BORDER_NORMAL := Color(0.22, 0.22, 0.32, 1.0)
const BORDER_HOVER := Color(0.38, 0.38, 0.5, 1.0)

## Порядок героев на экране.
const HERO_ORDER: Array[String] = [
    "hero_spearman",
    "hero_archer",
    "hero_monk",
]

# ── Визуальные стили (настраиваются в Inspector) ──
## Портреты героев (порядок = HERO_ORDER: Копейщик, Лучник, Монах).
@export var hero_portraits: Array[Texture2D] = []
## Стиль обычной (не выбранной, не наведённой) карточки героя.
@export var card_normal: StyleBox = null
## Стиль карточки при наведении мыши.
@export var card_hover: StyleBox = null
## Стиль заблокированной карточки героя. Если не задан — используется card_normal.
@export var card_locked: StyleBox = null
## Стиль кнопки «В БОЙ» (theme_override_styles/normal).
@export var start_button_style: StyleBox = null
## Стиль кнопки «Назад» (theme_override_styles/normal).
@export var back_button_style: StyleBox = null

var _selected_hero_id: String = HERO_DATA.DEFAULT_HERO_ID
var _hovered_index: int = -1


func _ready() -> void:
    for i in HERO_ORDER.size():
        var card := _get_card(i)
        if card == null:
            continue
        var hero_id: String = HERO_ORDER[i]
        card.gui_input.connect(_on_card_gui_input.bind(i, hero_id))
        card.mouse_entered.connect(_on_card_mouse_entered.bind(i, hero_id))
        card.mouse_exited.connect(_on_card_mouse_exited.bind(i, hero_id))

    # Стили кнопок из Inspector (если назначены).
    var start_button := get_node_or_null("ScrollContainer/CenterContainer/HeroArea/VBoxContainer/StartButton") as Button
    if start_button and start_button_style != null:
        start_button.add_theme_stylebox_override("normal", start_button_style)
    var back_button := get_node_or_null("ScrollContainer/CenterContainer/HeroArea/VBoxContainer/BackButton") as Button
    if back_button and back_button_style != null:
        back_button.add_theme_stylebox_override("normal", back_button_style)

    _refresh()


## Обновление карточек героев при открытии экрана.
func refresh() -> void:
    _refresh()


func _refresh() -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    if meta == null:
        return

    var gm := get_node_or_null("/root/GameManager")
    var current: String = HERO_DATA.DEFAULT_HERO_ID
    if gm and gm.get("selected_hero_id") != "":
        current = String(gm.get("selected_hero_id"))
    _selected_hero_id = current

    for i in HERO_ORDER.size():
        var hero_id: String = HERO_ORDER[i]
        var unlocked: bool = hero_id == HERO_DATA.DEFAULT_HERO_ID or meta.is_hero_unlocked(hero_id)
        _update_card(i, hero_id, unlocked, current, meta)


func _get_card(index: int) -> PanelContainer:
    return get_node_or_null("ScrollContainer/CenterContainer/HeroArea/VBoxContainer/HeroCard_%d" % index) as PanelContainer


func _update_card(index: int, hero_id: String, unlocked: bool, current: String, meta: Node) -> void:
    var card := _get_card(index)
    if card == null:
        return

    var hero: Dictionary = HERO_DATA.get_hero(hero_id)
    var name_label: Label = card.get_node_or_null("VBox/Header/NameLabel")
    var passive_name_label: Label = card.get_node_or_null("VBox/Passive/PassiveNameLabel")
    var passive_desc_label: Label = card.get_node_or_null("VBox/Passive/PassiveDescLabel")
    var lock_label: Label = card.get_node_or_null("VBox/LockHeader/LockLabel")
    var visual_texture: TextureRect = card.get_node_or_null("VBox/Header/VisualTexture")

    # Портрет героя — экспортированный Texture2D из Inspector (порядок = HERO_ORDER).
    # Если массив пуст или элемент не назначен — текстура очищается (слот остаётся пустым).
    if visual_texture:
        if index < hero_portraits.size() and hero_portraits[index] != null:
            visual_texture.texture = hero_portraits[index]
            visual_texture.visible = true
        else:
            visual_texture.texture = null
        visual_texture.custom_minimum_size = Vector2(88, 88)
        visual_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        visual_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    # с центрированным текстом (автоперенос естественный, не по словам).
    _center_hbox(card.get_node_or_null("VBox/Header"))
    _fill_vbox_items(card.get_node_or_null("VBox/Passive"))
    _fill_vbox_items(card.get_node_or_null("VBox/LockHeader"))
    _center_label(passive_name_label)
    _center_label(passive_desc_label)
    _center_label(lock_label)

    if name_label:
        name_label.text = str(hero.get("display_name", hero_id))
    if passive_name_label:
        passive_name_label.text = str(hero.get("passive_name", ""))
    if passive_desc_label:
        passive_desc_label.text = str(hero.get("passive_description", ""))

    if unlocked:
        if lock_label:
            lock_label.visible = false
    else:
        var have: int = meta.get_fragment_count(hero_id)
        var req: int = int(GACHA_DATA.CONTENT.get(hero_id, {}).get("req_fragments", 0))
        if lock_label:
            lock_label.text = "🔒 ЗАБЛОКИРОВАН — фрагменты: %d/%d" % [have, req]
            lock_label.visible = true

    _apply_visual_state(card, unlocked, hero_id == current, index == _hovered_index)


## Центрирует заголовок (Header: спрайт + имя) по горизонтали.
func _center_hbox(header: Control) -> void:
    if header == null:
        return
    header.alignment = BoxContainer.ALIGNMENT_CENTER


## Растягивает каждый дочерний элемент VBox на всю ширину карточки.
## Так автоперенос использует доступную ширину, а текст центрируется
## через horizontal_alignment — без узких колонок и переноса по словам.
func _fill_vbox_items(vbox: Control) -> void:
    if vbox == null:
        return
    for child in vbox.get_children():
        if child is Control:
            child.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Центрирует текст лейбла по горизонтали.
func _center_label(label: Label) -> void:
    if label == null:
        return
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Применяет визуальное состояние карточки: заблокирована / выбрана / наведена / обычная.
## ВЫБОР отображается золотой рамкой 2px ПО КРАЮ панели карточки (как в коллекции героев) —
## фон остаётся обычным, рамка из ACCENT_COLOR. Hover — отдельный стиль card_hover.
## Логика заблокированности (modulate) сохраняется.
func _apply_visual_state(card: Control, unlocked: bool, selected: bool, hovered: bool) -> void:
    # SelectionFrame больше не используется — рамка рисуется напрямую на панели.
    var frame: Panel = card.get_node_or_null("SelectionFrame") as Panel
    if frame:
        frame.visible = false

    if not unlocked:
        card.modulate = Color(0.72, 0.72, 0.78, 1.0)
        card.add_theme_stylebox_override("panel", _get_card_style(card, _state_locked()))
        return

    card.modulate = Color.WHITE
    # Выбранная карточка — золотая рамка 2px по краю панели (как в коллекции).
    if selected:
        card.add_theme_stylebox_override("panel", _make_selected_style(card))
    elif hovered:
        card.add_theme_stylebox_override("panel", _get_card_style(card, _state_hover()))
    else:
        card.add_theme_stylebox_override("panel", _get_card_style(card, _state_normal()))


## Возвращает стиль карточки по состоянию: экспортированный (> приоритет) → стандартный StyleBoxFlat.
## Заглушки для состояний: пустые StyleBox означают «не назначен в Inspector».
func _get_card_style(card: Control, style: StyleBox) -> StyleBox:
    if style != null:
        return style
    return _make_card_style(card, CARD_BG, BORDER_NORMAL, 1)


func _state_normal() -> StyleBox:
    return card_normal


func _state_hover() -> StyleBox:
    if card_hover != null:
        return card_hover
    return _make_fallback_hover()


func _state_locked() -> StyleBox:
    if card_locked != null:
        return card_locked
    if card_normal != null:
        return card_normal
    # Fallback: тёмный StyleBoxFlat (как было до рефакторинга).
    return _make_card_style(null, CARD_BG_LOCKED, BORDER_NORMAL, 1)


func _make_fallback_hover() -> StyleBox:
    return _make_card_style(null, CARD_BG_HOVER, BORDER_HOVER, 1)


## Стиль ВЫБРАННОЙ карточки — золотая рамка 2px по краю панели (как в коллекции героев).
func _make_selected_style(card: Control) -> StyleBox:
    return _make_card_style(card, CARD_BG, ACCENT_COLOR, 2)


## Собирает стандартный StyleBoxFlat карточки (fallback), сохраняя отступы контента (12/10/12/10).
func _make_card_style(card: Control, bg: Color, border: Color, width: int) -> StyleBoxFlat:
    var base := card.get_theme_stylebox("panel") if card != null else null
    var sb: StyleBoxFlat
    if base is StyleBoxFlat:
        sb = base.duplicate() as StyleBoxFlat
    else:
        sb = StyleBoxFlat.new()
        sb.set_corner_radius_all(8)
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(width)
    sb.content_margin_left = 12
    sb.content_margin_top = 10
    sb.content_margin_right = 12
    sb.content_margin_bottom = 10
    return sb


## Клик левой кнопкой мыши по карточке — выбор героя (только разблокированные).
func _on_card_gui_input(event: InputEvent, index: int, hero_id: String) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _select_hero(hero_id)


func _on_card_mouse_entered(index: int, hero_id: String) -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    if meta == null:
        return
    if hero_id != HERO_DATA.DEFAULT_HERO_ID and not meta.is_hero_unlocked(hero_id):
        return
    _hovered_index = index
    var card := _get_card(index)
    if card:
        _apply_visual_state(card, true, hero_id == _selected_hero_id, true)


func _on_card_mouse_exited(index: int, hero_id: String) -> void:
    if _hovered_index != index:
        return
    _hovered_index = -1
    var card := _get_card(index)
    if card == null:
        return
    var meta := get_node_or_null("/root/MetaProgress")
    var unlocked: bool = hero_id == HERO_DATA.DEFAULT_HERO_ID or (meta != null and meta.is_hero_unlocked(hero_id))
    _apply_visual_state(card, unlocked, hero_id == _selected_hero_id, false)


func _select_hero(hero_id: String) -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    if meta == null:
        return
    if hero_id != HERO_DATA.DEFAULT_HERO_ID and not meta.is_hero_unlocked(hero_id):
        return
    _selected_hero_id = hero_id
    var gm := get_node_or_null("/root/GameManager")
    if gm:
        gm.set("selected_hero_id", hero_id)
    refresh()


func _on_start_pressed() -> void:
    # Защита: нельзя стартовать с заблокированным героем.
    var meta := get_node_or_null("/root/MetaProgress")
    if meta == null:
        return
    if _selected_hero_id != HERO_DATA.DEFAULT_HERO_ID and not meta.is_hero_unlocked(_selected_hero_id):
        return
    var gm := get_node_or_null("/root/GameManager")
    if gm and gm.has_method("start_new_game"):
        gm.start_new_game()
