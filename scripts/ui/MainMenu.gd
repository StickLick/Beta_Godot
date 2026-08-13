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

# Контейнер карточек магазина. Все элементы магазина строятся динамически
# из данных MetaProgress (ничего не захардкожено).
var _dynamic_shop_cards: Array[Control] = []

# Секции магазина и их русские заголовки.
const SHOP_SECTION_HERO: String = "РАЗВИТИЕ ГЕРОЯ"
const SHOP_SECTION_EXT: String = "РАСШИРЕНИЯ"
const SHOP_SECTION_MINE: String = "РАЗВИТИЕ ШАХТЫ"

# ── Палитра (в стиле Hero Selection / Collection) ──
const ACCENT_COLOR := Color(1, 0.85, 0.4, 1)
const CARD_BG := Color(0.1, 0.1, 0.16, 1.0)
const CARD_BG_LOCKED := Color(0.07, 0.07, 0.1, 1.0)
const BORDER_NORMAL := Color(0.22, 0.22, 0.32, 1.0)
const BORDER_LOCKED := Color(0.16, 0.16, 0.24, 1.0)
const TEXT_DIM := Color(0.62, 0.62, 0.68, 1.0)
const CARD_PAD_H: int = 14
const CARD_PAD_V: int = 12


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


func _meta() -> Node:
    return get_node_or_null("/root/MetaProgress")


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
    var currency_label: Label = shop_panel.get_node_or_null("CenterContainer/VBoxContainer/CurrencyDisplay/CurrencyLabel")
    if currency_label:
        currency_label.text = "%d" % GameManager.get_meta_currency()

    var dyn_box: VBoxContainer = shop_panel.get_node_or_null("CenterContainer/VBoxContainer/ShopScroll/ShopDynamicBox") as VBoxContainer
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


## Добавляет заголовок секции магазина.
func _add_section_label(dyn_box: VBoxContainer, title: String) -> void:
    var label := Label.new()
    label.text = title
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 20)
    label.add_theme_color_override("font_color", ACCENT_COLOR)
    label.custom_minimum_size = Vector2(300, 28)
    dyn_box.add_child(label)
    _dynamic_shop_cards.append(label)


## Создаёт карточку-кнопку улучшения магазина.
## Данные передаются построчно: [имя, уровень, описание, цена].
func _add_shop_card(dyn_box: VBoxContainer, name_text: String, level_text: String,
    desc_text: String, price_text: String, enabled: bool, on_buy: Callable) -> void:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(300, 0)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # Content margins — реальный источник отступов PanelContainer.
    var style := StyleBoxFlat.new()
    style.set_corner_radius_all(8)
    style.content_margin_left = CARD_PAD_H
    style.content_margin_top = CARD_PAD_V
    style.content_margin_right = CARD_PAD_H
    style.content_margin_bottom = CARD_PAD_V
    if enabled:
        style.bg_color = CARD_BG
        style.border_color = BORDER_NORMAL
        style.set_border_width_all(1)
        card.modulate = Color.WHITE
    else:
        style.bg_color = CARD_BG_LOCKED
        style.border_color = BORDER_LOCKED
        style.set_border_width_all(1)
        card.modulate = Color(0.72, 0.72, 0.78, 1.0)
    card.add_theme_stylebox_override("panel", style)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_child(vbox)

    # Имя — по центру сверху.
    var name_label := Label.new()
    name_label.text = name_text
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name_label.add_theme_font_size_override("font_size", 16)
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

    # Описание эффекта.
    var desc_label := Label.new()
    desc_label.text = desc_text
    desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_label.add_theme_font_size_override("font_size", 12)
    desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if not enabled:
        desc_label.add_theme_color_override("font_color", TEXT_DIM)
    vbox.add_child(desc_label)

    # Цена — снизу по центру.
    var price_label := Label.new()
    price_label.text = price_text
    price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    price_label.add_theme_font_size_override("font_size", 14)
    price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if not enabled:
        price_label.add_theme_color_override("font_color", TEXT_DIM)
    vbox.add_child(price_label)

    # Кнопка покупки.
    var buy_btn := Button.new()
    buy_btn.text = "Купить"
    buy_btn.custom_minimum_size = Vector2(0, 28)
    if enabled:
        buy_btn.pressed.connect(on_buy)
    else:
        buy_btn.disabled = true
    vbox.add_child(buy_btn)

    dyn_box.add_child(card)
    _dynamic_shop_cards.append(card)
    _dynamic_shop_cards.append(buy_btn)


# --- СЕКЦИЯ: РАЗВИТИЕ ГЕРОЯ ---

func _build_hero_section(dyn_box: VBoxContainer, meta: Node) -> void:
    _add_section_label(dyn_box, SHOP_SECTION_HERO)
    for upgrade_id: String in meta.HERO_UPGRADES:
        var cfg: Dictionary = meta.get_hero_upgrade_config(upgrade_id)
        if cfg.is_empty():
            continue
        var display_name: String = String(cfg.get("display_name", upgrade_id))
        var desc: String = String(cfg.get("description", ""))
        var level: int = meta.get_hero_upgrade_level(upgrade_id)
        var max_lvl: int = meta.MAX_HERO_UPGRADE_LEVEL
        var price: int = meta.get_hero_upgrade_price(upgrade_id)
        var enabled: bool = price >= 0 and meta.can_afford(price)
        var level_text: String = "Lv.%d/%d" % [level, max_lvl]
        var price_text: String
        if price < 0:
            price_text = "МАКСИМУМ"
        else:
            price_text = "Цена: %d" % price
        _add_shop_card(dyn_box, display_name, level_text, desc, price_text, enabled,
            _on_hero_upgrade_pressed.bind(upgrade_id))


# --- СЕКЦИЯ: РАСШИРЕНИЯ (слоты оружия и пассивок) ---

func _build_extensions_section(dyn_box: VBoxContainer, meta: Node) -> void:
    _add_section_label(dyn_box, SHOP_SECTION_EXT)

    # Слот оружия.
    var w_cur: int = meta.get_weapon_slots()
    var w_max: int = meta.MAX_WEAPON_SLOTS
    var w_price: int = meta.get_weapon_slot_upgrade_price()
    var w_enabled: bool = w_price >= 0 and meta.can_afford(w_price)
    var w_level_text: String = "Слотов: %d/%d" % [w_cur, w_max]
    var w_price_text: String = "Цена: %d" % w_price if w_price >= 0 else "МАКСИМУМ"
    _add_shop_card(dyn_box, "Слот оружия", w_level_text,
        "Увеличивает количество одновременно использованных оружий.",
        w_price_text, w_enabled, _on_weapon_slot_pressed)

    # Слот пассивок.
    var p_cur: int = meta.get_passive_slots()
    var p_max: int = meta.MAX_PASSIVE_SLOTS
    var p_price: int = meta.get_passive_slot_upgrade_price()
    var p_enabled: bool = p_price >= 0 and meta.can_afford(p_price)
    var p_level_text: String = "Слотов: %d/%d" % [p_cur, p_max]
    var p_price_text: String = "Цена: %d" % p_price if p_price >= 0 else "МАКСИМУМ"
    _add_shop_card(dyn_box, "Слот пассивок", p_level_text,
        "Увеличивает количество одновременно активных пассивок.",
        p_price_text, p_enabled, _on_passive_slot_pressed)


# --- СЕКЦИЯ: РАЗВИТИЕ ШАХТЫ (Mine + Outpost — единая система) ---

func _build_mine_section(dyn_box: VBoxContainer, meta: Node) -> void:
    _add_section_label(dyn_box, SHOP_SECTION_MINE)
    var level: int = meta.get_mine_level()
    var max_lvl: int = meta.MAX_MINE_LEVEL
    var price: int = meta.get_mine_level_upgrade_price()
    var enabled: bool = price >= 0 and meta.can_afford(price)
    var level_text: String = "Уровень: %d/%d" % [level, max_lvl]
    var price_text: String = "Цена: %d" % price if price >= 0 else "МАКСИМУМ"
    _add_shop_card(dyn_box, "Уровень шахты", level_text,
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
