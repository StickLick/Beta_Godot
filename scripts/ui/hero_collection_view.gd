extends VBoxContainer
class_name HeroCollectionView
## HeroCollectionView — самостоятельное представление вкладки «Герои» в CollectionScreen.
##
## Просмотр героев: стрелки prev/next и клики по мини-карточкам меняют
## ЛОКАЛЬНОЕ состояние _viewed_hero_index. Экрану просмотра запрещено изменять
## GameManager.selected_hero_id — реально выбранный герой читается только
## для первоначальной инициализации.
##
## Финальная визуальная стилизация по целевому макету коллекции:
## - у заблокированных героев под мини-карточкой компактный прогресс-бар фрагментов.

const HERO_DATA := preload("res://scripts/hero_data.gd")
const GACHA_DATA := preload("res://scripts/gacha_data.gd")

## Явный порядок героев (совпадает с HeroSelectScreen.HERO_ORDER и HERO_DATA.HEROES).
const HERO_ORDER: Array[String] = [
    "hero_spearman",
    "hero_archer",
    "hero_monk",
]

## Портреты героев — те же, что в CollectionScreen/HeroSelectScreen.
const HERO_ICON_PATHS: Dictionary = {
    "hero_spearman": "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_Lancer.png",
    "hero_archer": "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_Archer.png",
    "hero_monk": "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_Monk.png",
}

## Иконки стартового оружия по weapon_tag (из ресурсов Upgrade).
const WEAPON_ICON_PATHS: Dictionary = {
    "Spear": "res://Upgrades/Weapons/Spear/BaseSpear.tres",
    "Aura": "res://Upgrades/Weapons/Aura/BaseAura.tres",
    "Bow": "res://Upgrades/Weapons/Bow/BaseBow.tres",
    "Staff": "res://Upgrades/Weapons/Staff/BaseStaff.tres",
}

## Иконки пассивок героев (сопоставление по смыслу существующих ресурсов Upgrade).
const PASSIVE_ICON_BY_HERO: Dictionary = {
    "hero_spearman": "res://Upgrades/Passives/Damage_C.tres",
    "hero_archer": "res://Upgrades/Passives/CritChance_C.tres",
    "hero_monk": "res://Upgrades/Passives/Book_RAD_C.tres",
}

## Русские имена тегов оружий (тот же источник, что у WEAPON_TAG_NAMES в collection_screen.gd).
const WEAPON_TAG_NAMES: Dictionary = {
    "Spear": "Копьё",
    "Aura": "Аура",
    "Bow": "Лук",
    "Staff": "Посох",
    "Banner": "Знамя",
}

# ── Палитра (тема коллекции) ──
const ACCENT_COLOR := Color(1, 0.85, 0.4, 1)
const MUTED_TEXT_COLOR := Color(0.62, 0.62, 0.68, 1.0)
const GREEN_OK := Color(0.29, 0.72, 0.39, 1.0)
const LOCKED_DIM := Color(0.72, 0.72, 0.78, 1.0)

# ── Размеры мини-карточек ──
const MINI_CARD_SIZE := Vector2(80, 95)
const MINI_ICON_SIZE := Vector2(52, 52)

# ── Цвета прогресс-бара фрагментов ──
# Трек сделай контрастным (светлый фон + золотая заливка + рамка),
# чтобы пустая шкала (0/100) была отчётливо видна под заблокированными героями.
const PROGRESS_BG_COLOR := Color(0.3, 0.32, 0.42, 0.9)
const PROGRESS_FILL_COLOR := Color(1, 0.85, 0.4, 0.95)
const PROGRESS_BORDER_COLOR := Color(0.45, 0.46, 0.58, 0.9)
const PROGRESS_BAR_HEIGHT := 10

# ── Цвета мини-карточек (полупрозрачные, см. _make_mini_style) ──
const MINI_CARD_BG := Color(0.1, 0.1, 0.16, 0.55)
const MINI_CARD_BORDER := Color(0.22, 0.22, 0.32, 0.9)

# ── Узлы сцены ──
@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var status_label: Label = %StatusLabel
@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var passive_icon: TextureRect = %PassiveIcon
@onready var passive_name_label: Label = %PassiveNameLabel
@onready var passive_desc_label: Label = %PassiveDescLabel
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var minis_box: HBoxContainer = %OtherHeroes

# Локальное состояние просмотра героя коллекцией.
var _viewed_hero_index: int = 0
var _mini_cards: Array[Control] = []


func _ready() -> void:
    prev_button.pressed.connect(_navigate_prev)
    next_button.pressed.connect(_navigate_next)
    _build_mini_cards()
    _init_viewed_hero()
    _refresh_view()


## Возвращает реально выбранного героя игры. Только чтение — никогда не пишет.
func get_current_selected_hero_id() -> String:
    var gm := get_node_or_null("/root/GameManager")
    var hero_id: String = ""
    if gm and gm.get("selected_hero_id") != "":
        hero_id = String(gm.get("selected_hero_id"))
    if hero_id == "" or not HERO_DATA.HEROES.has(hero_id):
        hero_id = HERO_DATA.DEFAULT_HERO_ID
    return hero_id


func _current_hero_id() -> String:
    return HERO_ORDER[_viewed_hero_index]


## Первоначальный просматриваемый герой = реально выбранный в игре.
func _init_viewed_hero() -> void:
    var idx := HERO_ORDER.find(get_current_selected_hero_id())
    _viewed_hero_index = idx if idx >= 0 else HERO_ORDER.find(HERO_DATA.DEFAULT_HERO_ID)


## Стрелка «предыдущий» — циклическая навигация по списку героев.
func _navigate_prev() -> void:
    _viewed_hero_index = (_viewed_hero_index - 1 + HERO_ORDER.size()) % HERO_ORDER.size()
    _refresh_view()


## Стрелка «следующий» — циклическая навигация по списку героев.
func _navigate_next() -> void:
    _viewed_hero_index = (_viewed_hero_index + 1) % HERO_ORDER.size()
    _refresh_view()


# ── Мини-карточки (динамический ряд) ──

func _build_mini_cards() -> void:
    for i in HERO_ORDER.size():
        var hero_id: String = HERO_ORDER[i]
        var card := PanelContainer.new()
        card.custom_minimum_size = MINI_CARD_SIZE
        card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

        var vbox := VBoxContainer.new()
        vbox.name = "VBox"
        vbox.add_theme_constant_override("separation", 3)
        vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        vbox.alignment = BoxContainer.ALIGNMENT_CENTER
        card.add_child(vbox)

        var icon_rect := TextureRect.new()
        icon_rect.name = "MiniIcon"
        icon_rect.custom_minimum_size = MINI_ICON_SIZE
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon_rect.texture = _load_hero_icon(hero_id)
        icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        vbox.add_child(icon_rect)

        # Компактный прогресс-бар фрагментов (только для заблокированных).
        var progress_bar := ProgressBar.new()
        progress_bar.name = "FragProgress"
        progress_bar.custom_minimum_size = Vector2(MINI_CARD_SIZE.x - 16, PROGRESS_BAR_HEIGHT)
        progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        progress_bar.show_percentage = false
        progress_bar.value = 0
        progress_bar.max_value = 1
        progress_bar.add_theme_stylebox_override("background", _make_progress_bg_style())
        progress_bar.add_theme_stylebox_override("fill", _make_progress_fill_style())
        vbox.add_child(progress_bar)

        var frag_label := Label.new()
        frag_label.name = "FragLabel"
        frag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        frag_label.add_theme_font_size_override("font_size", 11)
        frag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(frag_label)

        card.gui_input.connect(_on_mini_gui_input.bind(i))
        card.set_meta("hero_id", hero_id)
        card.set_meta("index", i)

        minis_box.add_child(card)
        _mini_cards.append(card)


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


func _load_hero_icon(hero_id: String) -> Texture2D:
    var path: String = String(HERO_ICON_PATHS.get(hero_id, ""))
    if path == "":
        return null
    return load(path) as Texture2D


func _load_weapon_icon(weapon_tag: String) -> Texture2D:
    var path: String = String(WEAPON_ICON_PATHS.get(weapon_tag, ""))
    if path == "":
        return null
    var up := load(path) as Upgrade
    return up.icon if up != null else null


func _load_passive_icon(hero_id: String) -> Texture2D:
    var path: String = String(PASSIVE_ICON_BY_HERO.get(hero_id, ""))
    if path == "":
        return null
    var up := load(path) as Upgrade
    return up.icon if up != null else null


func _on_mini_gui_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _viewed_hero_index = index
        _refresh_view()


# ── Обновление представления ──

func _refresh_view() -> void:
    var hero_id := _current_hero_id()
    var hero: Dictionary = HERO_DATA.get_hero(hero_id)
    var meta := get_node_or_null("/root/MetaProgress")
    var unlocked: bool = hero_id == HERO_DATA.DEFAULT_HERO_ID or (meta != null and meta.is_hero_unlocked(hero_id))

    # Портрет и имя.
    portrait.texture = _load_hero_icon(hero_id)
    portrait.modulate = Color.WHITE if unlocked else LOCKED_DIM
    name_label.text = String(hero.get("display_name", hero_id))

    # Статус разблокировки.
    if unlocked:
        status_label.text = "✔ Открыт"
        status_label.add_theme_color_override("font_color", GREEN_OK)
    else:
        var have: int = meta.get_fragment_count(hero_id) if meta else 0
        var req: int = _get_req_fragments(hero_id)
        status_label.text = "🔒 Заблокирован — фрагменты: %d/%d" % [have, req]
        status_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)

    # Стартовое оружие: лаконичная строка «Стартовое оружие: <Название>».
    var weapon_tag: String = String(hero.get("weapon_tag", ""))
    var weapon_name: String = WEAPON_TAG_NAMES.get(weapon_tag, weapon_tag)
    weapon_name_label.text = "Стартовое оружие: %s" % weapon_name if weapon_name != "" else "Стартовое оружие: —"
    weapon_icon.texture = _load_weapon_icon(weapon_tag)

    # Пассивный бонус.
    passive_icon.texture = _load_passive_icon(hero_id)
    passive_name_label.text = String(hero.get("passive_name", ""))
    passive_desc_label.text = String(hero.get("passive_description", ""))

    # Подсветка мини-карточек.
    _refresh_mini_cards(meta)


func _get_req_fragments(hero_id: String) -> int:
    var entry: Variant = GACHA_DATA.CONTENT.get(hero_id, {})
    if typeof(entry) == TYPE_DICTIONARY:
        return int(entry.get("req_fragments", 0))
    return 0


## Обновляет визуальное состояние мини-карточек: выделение просматриваемого,
## затемнение заблокированных, прогресс-бар и счётчик фрагментов.
func _refresh_mini_cards(meta: Node) -> void:
    for i in _mini_cards.size():
        var card := _mini_cards[i] as PanelContainer
        var hero_id: String = HERO_ORDER[i]
        var unlocked: bool = hero_id == HERO_DATA.DEFAULT_HERO_ID or (meta != null and meta.is_hero_unlocked(hero_id))
        var active: bool = i == _viewed_hero_index

        card.add_theme_stylebox_override("panel", _make_mini_style(active))
        card.modulate = Color.WHITE if unlocked else LOCKED_DIM

        var icon_rect := card.get_node_or_null("VBox/MiniIcon") as TextureRect
        if icon_rect:
            icon_rect.modulate = Color.WHITE if unlocked else LOCKED_DIM

        var progress_bar := card.get_node_or_null("VBox/FragProgress") as ProgressBar
        if progress_bar == null:
            continue
        var frag_label := card.get_node_or_null("VBox/FragLabel") as Label
        if frag_label == null:
            continue

        if unlocked:
            # Прогресс-бар не нужен для открытых героев.
            progress_bar.visible = false
            if active:
                # Активный разблокированный — зелёная галочка-бейдж.
                frag_label.text = "✔"
                frag_label.add_theme_font_size_override("font_size", 14)
                frag_label.add_theme_color_override("font_color", GREEN_OK)
            else:
                frag_label.text = ""
        else:
            var have: int = meta.get_fragment_count(hero_id) if meta else 0
            var req: int = _get_req_fragments(hero_id)
            # Полоска прогресса 0..1 (доля собранных фрагментов).
            progress_bar.visible = true
            progress_bar.max_value = 1.0
            progress_bar.value = float(have) / float(req) if req > 0 else 0.0
            frag_label.text = "🔒 %d/%d" % [have, req]
            frag_label.add_theme_font_size_override("font_size", 11)
            frag_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)


## Стиль мини-карточки: активная (просматриваемая) — золотая рамка 2px,
## неактивная — серая рамка 1px. Приглушение заблокированных делается
## через card.modulate в _refresh_mini_cards().
func _make_mini_style(active: bool) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = MINI_CARD_BG
    if active:
        sb.border_color = ACCENT_COLOR
        sb.set_border_width_all(2)
    else:
        sb.border_color = MINI_CARD_BORDER
        sb.set_border_width_all(1)
    sb.set_corner_radius_all(8)
    return sb
