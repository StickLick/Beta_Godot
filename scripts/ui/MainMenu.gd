extends Control
class_name MainMenu

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var shop_button: Button = %ShopButton
@onready var shop_panel: Control = %ShopPanel
@onready var luck_button: Button = %LuckButton
@onready var gacha_screen: Control = get_node_or_null("GachaScreen")
@onready var hero_select_screen: Control = get_node_or_null("HeroSelectScreen")
@onready var collection_screen: Control = get_node_or_null("CollectionScreen")
@onready var main_menu_ui: Control = $CenterContainer

# Контейнер карточек магазина. Все элементы магазина строятся динамически
# из данных MetaProgress (ничего не захардкожено).
var _dynamic_shop_cards: Array[Control] = []

# Секции магазина и их русские заголовки.
const SHOP_SECTION_HERO: String = "РАЗВИТИЕ ГЕРОЯ"
const SHOP_SECTION_EXT: String = "РАСШИРЕНИЯ"
const SHOP_SECTION_MINE: String = "РАЗВИТИЕ ШАХТЫ"

## Иконки 7 улучшений героя (секция «РАЗВИТИЕ ГЕРОЯ»).
## Ключ = upgrade_id из MetaProgress.HERO_UPGRADES, значение = res:// путь Upgrade.
## Для слотов оружия/пассивок и уровня шахты иконок НЕТ (icon = null).
const HERO_UPGRADE_ICON_PATHS: Dictionary = {
    "hp": "res://Upgrades/Passives/Stone_HP_C.tres",
    "damage": "res://Upgrades/Passives/Damage_C.tres",
    "move_speed": "res://Upgrades/Passives/Speed_C.tres",
    "luck": "res://Upgrades/Passives/Luck_C.tres",
    "attack_speed": "res://Upgrades/Passives/AttackSpeed_C.tres",
    "attack_range": "res://Upgrades/Passives/Book_RAD_C.tres",
    "hp_regen": "res://Upgrades/Passives/HPRegen_C.tres",
}

## Короткое имя HP-апгрейда, чтобы помещалось в одну строку (meta_progress.gd не меняем).
const HEALTH_UPGRADE_FULL_NAME: String = "Максимальное здоровье"
const HEALTH_UPGRADE_SHORT_NAME: String = "Макс. здоровье"

# ── Палитра (в стиле Hero Selection / Collection) ──
const ACCENT_COLOR := Color(1, 0.85, 0.4, 1)
const CARD_BG := Color(0.1, 0.1, 0.16, 0.55)
const CARD_BG_LOCKED := Color(0.07, 0.07, 0.1, 0.85)
const BORDER_NORMAL := Color(0.22, 0.22, 0.32, 1.0)
const BORDER_LOCKED := Color(0.16, 0.16, 0.24, 1.0)
const TEXT_DIM := Color(0.62, 0.62, 0.68, 1.0)
const CARD_PAD_H: int = 8
const CARD_PAD_V: int = 8

# ── Визуальные стили (настраиваются в Inspector) ──
## Стиль доступной карточки улучшения. StyleBoxTexture/StyleBoxFlat.
@export var shop_card_style: StyleBox = null
## Стиль недоступной (заблокированной) карточки. Если не задан — используется shop_card_style.
@export var shop_card_locked_style: StyleBox = null
## Стиль заголовков секций магазина («РАЗВИТИЕ ГЕРОЯ», «РАСШИРЕНИЯ», «РАЗВИТИЕ ШАХТЫ»).
@export var shop_section_style: StyleBox = null
## Стиль кнопки «Купить» (theme_override_styles/normal). StyleBoxTexture/StyleBoxFlat.
@export var buy_button_style: StyleBox = null


func _ready() -> void:
    GameManager.stop_game()
    quit_button.pressed.connect(_on_quit_pressed)
    if is_instance_valid(shop_panel):
        shop_panel.hide()
        _refresh_shop()
    if is_instance_valid(gacha_screen):
        gacha_screen.hide()
    if is_instance_valid(hero_select_screen):
        hero_select_screen.hide()
    if is_instance_valid(collection_screen):
        collection_screen.hide()
    for s in [shop_panel, gacha_screen, hero_select_screen, collection_screen]:
        if is_instance_valid(s) and not s.visibility_changed.is_connected(_on_sub_screen_visibility_changed):
            s.visibility_changed.connect(_on_sub_screen_visibility_changed)


func _meta() -> Node:
    return get_node_or_null("/root/MetaProgress")


## Скрывает/показывает контейнер UI главного меню (CenterContainer с Title и кнопками)
## по фактической видимости подэкранов. Срабатывает только при изменении visible.
func _on_sub_screen_visibility_changed() -> void:
    if not is_instance_valid(main_menu_ui):
        return
    var any_open: bool = false
    if is_instance_valid(shop_panel) and shop_panel.visible: any_open = true
    elif is_instance_valid(gacha_screen) and gacha_screen.visible: any_open = true
    elif is_instance_valid(hero_select_screen) and hero_select_screen.visible: any_open = true
    elif is_instance_valid(collection_screen) and collection_screen.visible: any_open = true
    main_menu_ui.visible = not any_open


func _on_start_pressed() -> void:
    if is_instance_valid(hero_select_screen):
        hero_select_screen.visible = true
        if hero_select_screen.has_method("refresh"):
            hero_select_screen.refresh()


func _on_quit_pressed() -> void:
    get_tree().quit()


# --- МАГАЗИН ---

func _on_shop_pressed() -> void:
    if is_instance_valid(shop_panel):
        shop_panel.visible = not shop_panel.visible
        if shop_panel.visible:
            _refresh_shop()


func _on_luck_pressed() -> void:
    if is_instance_valid(gacha_screen):
        gacha_screen.visible = not gacha_screen.visible
        if gacha_screen.visible and gacha_screen.has_method("refresh"):
            gacha_screen.refresh()


func _on_collection_pressed() -> void:
    if is_instance_valid(collection_screen):
        collection_screen.visible = not collection_screen.visible
        if collection_screen.visible and collection_screen.has_method("refresh"):
            collection_screen.refresh()


## Обновление панели магазина: валюта + карточки по секциям.
func _refresh_shop() -> void:
    var meta: Node = _meta()
    if meta == null:
        return
    var currency_label: Label = shop_panel.get_node_or_null("OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/CurrencyDisplay/CurrencyLabel")
    if currency_label:
        currency_label.text = "%d" % GameManager.get_meta_currency()

    var dyn_box: VBoxContainer = shop_panel.get_node_or_null("OuterMargin/ModalCenter/Layout/ContentMargin/ShopScroll/ShopDynamicBox") as VBoxContainer
    if dyn_box == null:
        return
    _clear_dynamic_shop(dyn_box)

    _build_hero_section(dyn_box, meta)
    _build_extensions_section(dyn_box, meta)
    _build_mine_section(dyn_box, meta)


func _clear_dynamic_shop(dyn_box: VBoxContainer) -> void:
    for c in _dynamic_shop_cards:
        if is_instance_valid(c):
            c.queue_free()
    _dynamic_shop_cards.clear()


## Добавляет заголовок секции магазина — простой золотой Label по центру,
## как заголовки секций в коллекции (без фоновой панели).
func _add_section_label(dyn_box: VBoxContainer, title: String) -> void:
    var label := Label.new()
    label.text = title
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", ACCENT_COLOR)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dyn_box.add_child(label)
    _dynamic_shop_cards.append(label)


## Создаёт карточку-кнопку улучшения магазина.
## Данные передаются построчно: [имя, уровень, описание, цена].
## icon — текстура иконки (null = без иконки, как у слотов и шахты).
## Стили карточек — из Inspector (shop_card_style / shop_card_locked_style);
## если они не назначены — создаётся стандартный StyleBoxFlat (fallback).
func _add_shop_card(container: Container, name_text: String, level_text: String,
    desc_text: String, price_text: String, enabled: bool, on_buy: Callable,
    icon: Texture2D = null) -> void:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 0)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # Стиль карточки: экспортированный (если назначен) → стандартный StyleBoxFlat (fallback).
    card.add_theme_stylebox_override("panel", _get_shop_card_style(enabled))
    if enabled:
        card.modulate = Color.WHITE
    else:
        card.modulate = Color(0.72, 0.72, 0.78, 1.0)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_child(vbox)

    # Иконка 32x32 (только для hero-улучшений, как в карточках коллекции).
    # Если icon == null (слот/шахта) — TextureRect не создаётся, пустого места нет.
    if icon != null:
        var icon_rect := TextureRect.new()
        icon_rect.custom_minimum_size = Vector2(32, 32)
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        icon_rect.texture = icon
        icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        vbox.add_child(icon_rect)

    # Имя — по центру сверху (как NameLabel в коллекции).
    var name_label := Label.new()
    name_label.text = name_text
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name_label.add_theme_font_size_override("font_size", 14)
    name_label.add_theme_color_override("font_color", ACCENT_COLOR)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(name_label)

    # Текущий уровень.
    var level_label := Label.new()
    level_label.text = level_text
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    level_label.add_theme_color_override("font_color", ACCENT_COLOR)
    level_label.add_theme_font_size_override("font_size", 13)
    level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(level_label)

    # Описание эффекта (как описание в коллекции — по левому краю).
    var desc_label := Label.new()
    desc_label.text = desc_text
    desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_label.add_theme_font_size_override("font_size", 11)
    desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if not enabled:
        desc_label.add_theme_color_override("font_color", TEXT_DIM)
    vbox.add_child(desc_label)

    # Распорка: прижимает цену и кнопку «Купить» к нижнему краю карточки,
    # чтобы строка «Цена» у всех карточек одной строки была на одном уровне,
    # независимо от длины описания.
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(spacer)

    # Цена — по центру над кнопкой «Купить», на одной высоте у всех карточек.
    var price_label := Label.new()
    price_label.text = price_text
    price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    price_label.add_theme_font_size_override("font_size", 12)
    price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if not enabled:
        price_label.add_theme_color_override("font_color", TEXT_DIM)
    vbox.add_child(price_label)

    # Кнопка «Купить» — золотая рамка 1px, как кнопки коллекции (без текстуры-подложки).
    var buy_btn := Button.new()
    buy_btn.text = "Купить"
    buy_btn.custom_minimum_size = Vector2(0, 34)
    buy_btn.size_flags_vertical = Control.SIZE_SHRINK_END
    buy_btn.add_theme_font_size_override("font_size", 14)
    var buy_style := StyleBoxFlat.new()
    buy_style.set_corner_radius_all(6)
    buy_style.content_margin_left = 8
    buy_style.content_margin_top = 6
    buy_style.content_margin_right = 8
    buy_style.content_margin_bottom = 6
    buy_style.bg_color = Color(0.12, 0.13, 0.19, 0.6)
    buy_style.border_color = ACCENT_COLOR
    buy_style.set_border_width_all(1)
    var buy_hover := buy_style.duplicate()
    buy_hover.bg_color = Color(0.17, 0.18, 0.26, 0.65)
    buy_btn.add_theme_stylebox_override("normal", buy_style)
    buy_btn.add_theme_stylebox_override("hover", buy_hover)
    buy_btn.add_theme_stylebox_override("pressed", buy_hover)
    if enabled:
        buy_btn.pressed.connect(on_buy)
    else:
        buy_btn.disabled = true
    vbox.add_child(buy_btn)

    container.add_child(card)
    _dynamic_shop_cards.append(card)
    _dynamic_shop_cards.append(buy_btn)


## Загружает иконку hero-улучшения по upgrade_id (как в коллекции: load(path) as Upgrade → icon).
## Для не-hero элементов (слоты/шахта) не используется — всегда передавать null.
func _load_hero_upgrade_icon(upgrade_id: String) -> Texture2D:
    var path: String = String(HERO_UPGRADE_ICON_PATHS.get(upgrade_id, ""))
    if path == "":
        return null
    var up := load(path) as Upgrade
    return up.icon if up != null else null


## Возвращает стиль карточки магазина.
## Приоритет для доступной: shop_card_style → стандартный StyleBoxFlat.
## Приоритет для недоступной: shop_card_locked_style → shop_card_style → стандартный StyleBoxFlat.
func _get_shop_card_style(enabled: bool) -> StyleBox:
    if enabled:
        if shop_card_style != null:
            return shop_card_style
        return _make_default_shop_card_style(CARD_BG, BORDER_NORMAL)
    if shop_card_locked_style != null:
        return shop_card_locked_style
    if shop_card_style != null:
        return shop_card_style
    return _make_default_shop_card_style(CARD_BG_LOCKED, BORDER_LOCKED)


## Стандартный StyleBoxFlat карточки магазина (fallback, когда @export стили не назначены).
## ВАЖНО: PanelContainer берёт внутренние отступы ИЗ CONTENT MARGINS StyleBox.
func _make_default_shop_card_style(bg: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.set_corner_radius_all(8)
    style.content_margin_left = CARD_PAD_H
    style.content_margin_top = CARD_PAD_V
    style.content_margin_right = CARD_PAD_H
    style.content_margin_bottom = CARD_PAD_V
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    return style


# --- СЕКЦИЯ: РАЗВИТИЕ ГЕРОЯ ---

## Строит описание улучшения одним предложением с числовым значением прироста.
## Если stat неизвестен — возвращает исходное описание без изменений.
func _build_hero_upgrade_description(stat: String, per_level: float, fallback: String) -> String:
    if not is_finite(per_level):
        return fallback
    match stat:
        "max_health":
            return "Увеличивает максимальное здоровье героя на %d единиц за уровень покупки" % int(round(per_level))
        "max_speed":
            return "Увеличивает скорость передвижения героя на %d единиц за уровень покупки" % int(round(per_level))
        "damage_multiplier":
            return "Увеличивает урон всех оружий на %d%% за уровень покупки" % int(round(per_level * 100.0))
        "luck":
            return "Увеличивает шанс выпадения редких улучшений на %d%% за уровень покупки" % int(round(per_level * 100.0))
        "attack_speed":
            return "Увеличивает скорость атаки всех оружий на %d%% за уровень покупки" % int(round(per_level * 100.0))
        "radius_weapons":
            return "Увеличивает радиус действия всех оружий на %d%% за уровень покупки" % int(round(per_level * 100.0))
        "health_regen":
            return "Восстанавливает %.1f%% от максимального здоровья в секунду за уровень покупки" % (per_level * 100.0)
    return fallback


func _build_hero_section(dyn_box: VBoxContainer, meta: Node) -> void:
    _add_section_label(dyn_box, SHOP_SECTION_HERO)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dyn_box.add_child(grid)
    _dynamic_shop_cards.append(grid)
    for upgrade_id: String in meta.HERO_UPGRADES:
        var cfg: Dictionary = meta.get_hero_upgrade_config(upgrade_id)
        if cfg.is_empty():
            continue
        var display_name: String = String(cfg.get("display_name", upgrade_id))
        if display_name == HEALTH_UPGRADE_FULL_NAME:
            display_name = HEALTH_UPGRADE_SHORT_NAME
        var desc: String = String(cfg.get("description", ""))
        # Описание одним предложением со значением прироста из cfg.per_level
        # (только если ключ есть и stat известен).
        if cfg.has("per_level"):
            desc = _build_hero_upgrade_description(
                String(cfg.get("stat", "")), float(cfg.get("per_level", 0.0)), desc)
        var level: int = meta.get_hero_upgrade_level(upgrade_id)
        var max_lvl: int = meta.MAX_HERO_UPGRADE_LEVEL
        var price: int = meta.get_hero_upgrade_price(upgrade_id)
        var enabled: bool = price >= 0 and meta.can_afford(price)
        var level_text: String = "Уровень: %d/%d" % [level, max_lvl]
        var price_text: String
        if price < 0:
            price_text = "МАКСИМУМ"
        else:
            price_text = "Цена: %d" % price
        var icon := _load_hero_upgrade_icon(upgrade_id)
        _add_shop_card(grid, display_name, level_text, desc, price_text, enabled,
            _on_hero_upgrade_pressed.bind(upgrade_id), icon)


# --- СЕКЦИЯ: РАСШИРЕНИЯ (слоты оружия и пассивок) ---

func _build_extensions_section(dyn_box: VBoxContainer, meta: Node) -> void:
    _add_section_label(dyn_box, SHOP_SECTION_EXT)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dyn_box.add_child(grid)
    _dynamic_shop_cards.append(grid)

    # Слот оружия (без иконки).
    var w_cur: int = meta.get_weapon_slots()
    var w_max: int = meta.MAX_WEAPON_SLOTS
    var w_price: int = meta.get_weapon_slot_upgrade_price()
    var w_enabled: bool = w_price >= 0 and meta.can_afford(w_price)
    var w_level_text: String = "Слотов: %d/%d" % [w_cur, w_max]
    var w_price_text: String = "Цена: %d" % w_price if w_price >= 0 else "МАКСИМУМ"
    _add_shop_card(grid, "Слот оружия", w_level_text,
        "Увеличивает количество одновременно использованных оружий.",
        w_price_text, w_enabled, _on_weapon_slot_pressed)

    # Слот пассивок (без иконки).
    var p_cur: int = meta.get_passive_slots()
    var p_max: int = meta.MAX_PASSIVE_SLOTS
    var p_price: int = meta.get_passive_slot_upgrade_price()
    var p_enabled: bool = p_price >= 0 and meta.can_afford(p_price)
    var p_level_text: String = "Слотов: %d/%d" % [p_cur, p_max]
    var p_price_text: String = "Цена: %d" % p_price if p_price >= 0 else "МАКСИМУМ"
    _add_shop_card(grid, "Слот пассивок", p_level_text,
        "Увеличивает количество одновременно активных пассивок.",
        p_price_text, p_enabled, _on_passive_slot_pressed)


# --- СЕКЦИЯ: РАЗВИТИЕ ШАХТЫ (Mine + Outpost — единая система) ---

func _build_mine_section(dyn_box: VBoxContainer, meta: Node) -> void:
    _add_section_label(dyn_box, SHOP_SECTION_MINE)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dyn_box.add_child(grid)
    _dynamic_shop_cards.append(grid)
    var level: int = meta.get_mine_level()
    var max_lvl: int = meta.MAX_MINE_LEVEL
    var price: int = meta.get_mine_level_upgrade_price()
    var enabled: bool = price >= 0 and meta.can_afford(price)
    var level_text: String = "Уровень: %d/%d" % [level, max_lvl]
    var price_text: String = "Цена: %d" % price if price >= 0 else "МАКСИМУМ"
    _add_shop_card(grid, "Уровень шахты", level_text,
        "Открывает новые уровни шахты и развитие аванпоста.",
        price_text, enabled, _on_mine_level_pressed)


# --- ОБРАБОТЧИКИ ПОКУПОК (механика не менялась) ---

func _on_weapon_slot_pressed() -> void:
    var meta: Node = _meta()
    if meta and meta.increase_weapon_slots():
        _refresh_shop()


func _on_passive_slot_pressed() -> void:
    var meta: Node = _meta()
    if meta and meta.increase_passive_slots():
        _refresh_shop()


func _on_hero_upgrade_pressed(upgrade_id: String) -> void:
    var meta: Node = _meta()
    if meta and meta.buy_hero_upgrade(upgrade_id):
        _refresh_shop()


func _on_mine_level_pressed() -> void:
    var meta: Node = _meta()
    if meta and meta.buy_mine_level():
        _refresh_shop()
