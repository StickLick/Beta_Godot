extends Node

@export var upgrade_menu_scene: PackedScene
@onready var _ui_container: Control = %UpgradePanel
@export var all_available_upgrades: Array[Upgrade]

## Визуальные параметры карточек апгрейдов (настраиваются через Inspector).
@export var card_size: Vector2 = Vector2(400, 160)
@export var card_spacing: int = 20
@export_group("Card Style")
@export var card_normal_style: StyleBox = null
@export var card_hover_style: StyleBox = null
@export var card_pressed_style: StyleBox = null
@export var card_focus_style: StyleBox = null

@export_group("Card Flat Style")
## Радиус скругления углов карточки. 0 = использовать стили из Inspector (PNG-текстуры).
@export var card_corner_radius: int = 8
@export var card_flat_bg_color: Color = Color(0.08, 0.1, 0.16, 0.82)
@export var card_flat_hover_bg_color: Color = Color(0.14, 0.18, 0.28, 0.9)
@export var card_flat_pressed_bg_color: Color = Color(0.05, 0.06, 0.1, 0.9)
@export var card_flat_border_width: int = 2
## Прозрачность рамки. Цвет рамки берётся из редкости улучшения (RARITY_COLORS).
@export var card_flat_border_alpha: float = 0.9

@export_group("Card Content")
@export var icon_size: Vector2 = Vector2(64, 64)
@export var card_padding: int = 16
@export var card_inner_spacing: int = 12
@export var card_content_spacing: int = 6
@export var card_name_font: Font = null
@export var card_name_font_size: int = 20
@export var card_name_color: Color = Color.WHITE
@export var card_desc_font: Font = null
@export var card_desc_font_size: int = 14
@export var card_desc_color: Color = Color(0.85, 0.85, 0.85)
@export var card_level_font_size: int = 14
@export var card_level_color: Color = Color(1.0, 0.85, 0.3)

@export_group("Menu Title")
@export var menu_title_text: String = "ВЫБЕРИ УЛУЧШЕНИЕ"
@export var menu_title_font: Font = null
@export var menu_title_font_size: int = 28
@export var menu_title_color: Color = Color.WHITE
@export var menu_title_spacing: int = 24

var _active_menu: Control = null
var _pending_upgrades: int = 0


const BASE_WEIGHTS = {
    Upgrade.Rarity.COMMON: 100.0,
    Upgrade.Rarity.RARE: 35.0,
    Upgrade.Rarity.EPIC: 10.0,
    Upgrade.Rarity.LEGENDARY: 2.0
}

const RARITY_COLORS = {
    Upgrade.Rarity.COMMON: Color.WHITE,
    Upgrade.Rarity.RARE: Color(0.2, 0.5, 1.0),
    Upgrade.Rarity.EPIC: Color(0.7, 0.2, 1.0),
    Upgrade.Rarity.LEGENDARY: Color(1.0, 0.8, 0.0)
}

const EVOLUTION_FAMILIES := {
    "Bow": ["SiegeCrossbow", "SpectralVolley", "SkyPiercer"],
    "Banner": ["BannerArcher", "BannerTank", "BannerMarshal"],
}

const GACHA_DATA := preload("res://scripts/gacha_data.gd")

## Маппинг тегов/имён апгрейдов на content_id гачи (gacha_data.CONTENT).
## Ключ = weapon_tag (для базовых оружий) или passive_id/name (для пассивок).
## Теги, отсутствующие в словаре (эволюционные оружия, модификаторы),
## НЕ фильтруются — они доступны только при уже имеющемся оружии/эволюции.
const UPGRADE_TAG_TO_CONTENT_ID := {
    # Базовые оружия (is_weapon=true). «Spear» — стартовое, всегда открыто.
    "Aura": "weapon_aura",
    "Bow": "weapon_bow",
    "Staff": "weapon_staff",
    "Banner": "weapon_banner",
    # Пассивки (passive_id / базовое имя). «Damage» — стартовая, всегда открыта.
    "AttackRange": "passive_attack_range",
    "ProjectileAmount": "passive_amount",
    "MaxHP": "passive_max_hp",
    "CritChance": "passive_crit_chance",
    "MoveSpeed": "passive_move_speed",
    "Luck": "passive_luck",
    "HPRegen": "passive_hp_regen",
    "AttackSpeed": "passive_attack_speed",
    "XP": "passive_experience",
    "GoldGain": "passive_gold",
}

func open_upgrade_menu() -> void:    
    # Закрыть открытую панель паузы, чтобы она не оставалась поверх меню апгрейдов.
    var hud = get_tree().get_first_node_in_group("hud")
    if hud and hud.has_method("close_pause"):
        hud.close_pause()

    var player = get_tree().get_first_node_in_group("player") as Player
    if not player: return

    print("[SYNC] Upgrade Menu | Slots refreshed. Active Weapons: %d" % player.active_weapons.size())
    var eligible_pool = _get_eligible_upgrades(player)
    
    get_tree().paused = true
    var selected_upgrades: Array[Upgrade] = []
    var temp_pool = eligible_pool.duplicate()
    var picked_tags: Array[String] = []
    
    for i in range(3):
        if temp_pool.is_empty():
            var fallback = _create_fallback_upgrade(player)
            selected_upgrades.append(fallback)
            continue
        
        var up = _pick_weighted_upgrade(temp_pool, player)
        selected_upgrades.append(up)
        
        var tag = up.weapon_tag
        if tag == "" or tag == "General":
            tag = up.passive_id
        if tag == "":
            tag = up.name
        picked_tags.append(tag)
        temp_pool = temp_pool.filter(func(u): return _get_tag(u) != tag)
    
    _spawn_menu(selected_upgrades, player)


func _get_tag(u: Upgrade) -> String:
    if u.weapon_tag != "" and u.weapon_tag != "General":
        return u.weapon_tag
    if u.passive_id != "":
        return u.passive_id
    return u.name


func _get_eligible_upgrades(player: Player) -> Array[Upgrade]:
    var weapons_full = player.active_weapons.size() >= player.unlocked_weapon_slots
    var passives_full = player.active_passives.size() >= player.unlocked_passive_slots
    var pool: Array[Upgrade] = []
    
    for u in all_available_upgrades:
        if _already_taken(u, player): continue
        if not _prerequisites_met(u, player): continue
        # Мета-фильтр: новые оружия/пассивки доступны только после разблокировки.
        if not _is_meta_unlocked(u): continue
        
        if u.change_mechanic_on_apply:
            if _can_take_evolution(u, player): pool.append(u)
        elif u.is_weapon:
            if _can_take_weapon(u, player, weapons_full): pool.append(u)
        elif u.passive_id != "":
            if _can_take_passive_by_id(u, player, passives_full): pool.append(u)
        elif u.weapon_tag != "" and u.weapon_tag != "General":
            if _can_take_modifier(u, player): pool.append(u)
        else:
            if _can_take_passive(u, player, passives_full): pool.append(u)
    
    return pool


## Проверка мета-разблокировки апгрейда.
## Фильтруются ТОЛЬКО получение новых оружий и новых пассивок:
##   - базовые оружия (BaseAura/BaseBow/BaseStaff/BaseBanner) — через is_weapon_unlocked();
##   - пассивки (улучшенные по passive_id, базовые по имени) — через is_passive_unlocked().
## НЕ фильтруются: стартовые Копьё/Spear и Урон/Damage, эволюции,
## модификаторы оружий (Aura_DMG и т.п.), эволюционные оружия,
## а также любые апгрейды, чей тег/имя отсутствует в словаре маппинга.
func _is_meta_unlocked(u: Upgrade) -> bool:
    var meta := get_node_or_null("/root/MetaProgress")

    # Эволюции — не трогаем.
    if u.change_mechanic_on_apply:
        return true

    # Новое базовое оружие (is_weapon=true).
    if u.is_weapon:
        # Стартовое копьё всегда доступно.
        if u.weapon_tag == "Spear":
            return true
        var content_id: String = UPGRADE_TAG_TO_CONTENT_ID.get(u.weapon_tag, "")
        # Неизвестный тег (эволюционное оружие и т.п.) — не фильтруем.
        if content_id == "":
            return true
        return meta == null or meta.is_weapon_unlocked(content_id)

    # Пассивки с passive_id (улучшенные варианты, Book/Stone-серии и т.д.).
    if u.passive_id != "":
        # Стартовая пассивка «Урон» всегда доступна.
        if u.passive_id == "Damage":
            return true
        var content_id: String = UPGRADE_TAG_TO_CONTENT_ID.get(u.passive_id, "")
        if content_id == "":
            return true
        return meta == null or meta.is_passive_unlocked(content_id)

    # Базовые пассивки без тега (BaseDamage/BaseSpeed/BaseBook/BaseStone...).
    if u.weapon_tag == "" or u.weapon_tag == "General":
        if u.name == "Damage":
            return true
        var content_id: String = UPGRADE_TAG_TO_CONTENT_ID.get(u.name, "")
        if content_id == "":
            return true
        return meta == null or meta.is_passive_unlocked(content_id)

    # Модификаторы оружия (weapon_tag != "" и не пассивка) — не фильтруем:
    # они выпадают только когда соответствующее оружие уже есть у игрока.
    return true


func _already_taken(u: Upgrade, player: Player) -> bool:
    return u.is_unique and player.applied_upgrade_names.has(u.name)


func _prerequisites_met(u: Upgrade, player: Player) -> bool:
    for p in u.prerequisites:
        if not player.applied_upgrade_names.has(p):
            return false
    return true


func _can_take_evolution(u: Upgrade, player: Player) -> bool:
    var owns_weapon = false
    for w in player.active_weapons:
        if w.weapon_tag == u.weapon_tag:
            owns_weapon = true
            break
    if not owns_weapon:
        return false
    
    if player.tag_levels.get(u.weapon_tag, 0) < u.max_level_for_evo:
        return false
    
    if u.required_passive_tag != "":
        var has_passive = false
        for p in player.active_passives:
            if p.get("passive_id") == u.required_passive_tag:
                has_passive = true
                break
        if not has_passive:
            return false
        var passive_level = player.tag_levels.get(u.required_passive_tag, 0)
        if passive_level < u.required_passive_level:
            return false
    
    var family: Array = EVOLUTION_FAMILIES.get(u.weapon_tag, [])
    if family.size() > 0:
        for w in player.active_weapons:
            if w.weapon_tag in family:
                return false
    
    return true


func _can_take_weapon(u: Upgrade, player: Player, weapons_full: bool) -> bool:
    for w in player.active_weapons:
        if w.name == u.name:
            return false
    if weapons_full:
        return false
    return true


func _can_take_modifier(u: Upgrade, player: Player) -> bool:
    if u.is_global_modifier:
        return true
    for w in player.active_weapons:
        if w.weapon_tag == u.weapon_tag:
            return player.tag_levels.get(u.weapon_tag, 0) < 8
    for p in player.active_passives:
        if p.name == u.weapon_tag:
            return player.tag_levels.get(u.weapon_tag, 0) < 8
    return false


func _can_take_passive_by_id(u: Upgrade, player: Player, passives_full: bool) -> bool:
    for p in player.active_passives:
        if p.get("passive_id") == u.passive_id:
            return player.tag_levels.get(u.passive_id, 0) < 8
    return not passives_full

func _can_take_passive(u: Upgrade, player: Player, passives_full: bool) -> bool:
    for p in player.active_passives:
        if p.name == u.name:
            return false
    if passives_full:
        return false
    return true


func _create_fallback_upgrade(player: Player) -> Upgrade:
    var f = Upgrade.new()
    f.name = "Minor Heal"
    f.display_name = "Восстановление"
    f.description = "Восстанавливает 50 HP"
    f.rarity = Upgrade.Rarity.COMMON
    f.weapon_tag = "Fallback"
    f.amount = 50.0
    return f


func _pick_weighted_upgrade(pool: Array[Upgrade], player: Player) -> Upgrade:
    var total_weight = 0.0
    var weights = []
    for u in pool:
        var w = BASE_WEIGHTS[u.rarity]
        if u.rarity >= Upgrade.Rarity.RARE: w *= player.luck
        weights.append(w)
        total_weight += w
    var roll = randf() * total_weight
    var cursor = 0.0
    for i in range(pool.size()):
        cursor += weights[i]
        if roll <= cursor: return pool[i]
    return pool[0]


## Создаёт плоский стиль скруглённой карточки с рамкой.
func _make_flat_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg_color
    sb.border_color = border_color
    sb.set_border_width_all(card_flat_border_width)
    sb.set_corner_radius_all(card_corner_radius)
    return sb


func _build_card(up: Upgrade, player: Player) -> Button:
    var btn := Button.new()
    btn.custom_minimum_size = card_size
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.focus_mode = Control.FOCUS_ALL
    if card_corner_radius > 0:
        # Рамка окрашивается цветом редкости (как и весь вид карточки сейчас).
        var border_color: Color = RARITY_COLORS[up.rarity]
        border_color.a = card_flat_border_alpha
        btn.add_theme_stylebox_override("normal", _make_flat_style(card_flat_bg_color, border_color))
        btn.add_theme_stylebox_override("hover", _make_flat_style(card_flat_hover_bg_color, border_color))
        btn.add_theme_stylebox_override("pressed", _make_flat_style(card_flat_pressed_bg_color, border_color))
    else:
        if card_normal_style:
            btn.add_theme_stylebox_override("normal", card_normal_style)
        if card_hover_style:
            btn.add_theme_stylebox_override("hover", card_hover_style)
        if card_pressed_style:
            btn.add_theme_stylebox_override("pressed", card_pressed_style)
    if card_focus_style:
        btn.add_theme_stylebox_override("focus", card_focus_style)
    btn.self_modulate = RARITY_COLORS[up.rarity]

    # Внутренний контейнер с отступами.
    var margin := MarginContainer.new()
    margin.name = "CardMargin"
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", card_padding)
    margin.add_theme_constant_override("margin_top", card_padding)
    margin.add_theme_constant_override("margin_right", card_padding)
    margin.add_theme_constant_override("margin_bottom", card_padding)
    btn.add_child(margin)

    # Внешний вертикальный блок: название сверху, контент (иконка + уровень + описание) снизу.
    var vbox := VBoxContainer.new()
    vbox.name = "CardVBox"
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_theme_constant_override("separation", card_content_spacing)
    margin.add_child(vbox)

    # Название (display_name, fallback на name) — центрируется по всей ширине карточки.
    var name_label := Label.new()
    name_label.name = "NameLabel"
    name_label.text = up.display_name if up.display_name != "" else up.name
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if card_name_font:
        name_label.add_theme_font_override("font", card_name_font)
    name_label.add_theme_font_size_override("font_size", card_name_font_size)
    name_label.add_theme_color_override("font_color", card_name_color)
    vbox.add_child(name_label)

    # Горизонтальный блок контента: иконка сбоку от уровня и описания (по центру карточки).
    var content_hbox := HBoxContainer.new()
    content_hbox.name = "CardContentHBox"
    content_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content_hbox.add_theme_constant_override("separation", card_inner_spacing)
    content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(content_hbox)

    # Иконка — вертикально по центру блока (примерно посередине уровня и описания).
    var icon_width := 0.0
    if up.icon:
        var icon_rect := TextureRect.new()
        icon_rect.name = "Icon"
        icon_rect.texture = up.icon
        icon_rect.custom_minimum_size = icon_size
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        content_hbox.add_child(icon_rect)
        icon_width = icon_size.x

    # Текстовый блок: уровень / описание
    var text_vbox := VBoxContainer.new()
    text_vbox.name = "CardTextVBox"
    text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    text_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    text_vbox.add_theme_constant_override("separation", card_content_spacing)
    # Ширина группы (иконка + текст) — 70% доступной ширины карточки,
    # чтобы вокруг неё оставались равные отступы и группа центрировалась.
    var content_available := maxf(0.0, card_size.x - card_padding * 2)
    var text_width := maxf(0.0, content_available * 0.7 - icon_width - card_inner_spacing)
    text_vbox.custom_minimum_size = Vector2(text_width, 0)
    content_hbox.add_child(text_vbox)

    # Уровень / статус (LVL X -> Y)
    var level_tag = up.passive_id if up.passive_id != "" else up.weapon_tag
    var cur_lvl = player.tag_levels.get(level_tag, 0)
    var lvl_info := ""
    if up.change_mechanic_on_apply:
        lvl_info = "ЭВОЛЮЦИЯ"
    elif cur_lvl >= 8:
        lvl_info = "МАКС. УРОВЕНЬ"
    else:
        lvl_info = "LVL %d → %d" % [cur_lvl, cur_lvl + 1]

    var level_label := Label.new()
    level_label.name = "LevelLabel"
    level_label.text = lvl_info
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    level_label.add_theme_font_size_override("font_size", card_level_font_size)
    level_label.add_theme_color_override("font_color", card_level_color)
    text_vbox.add_child(level_label)

    # Описание
    var desc_label := Label.new()
    desc_label.name = "DescLabel"
    desc_label.text = up.description
    desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    if card_desc_font:
        desc_label.add_theme_font_override("font", card_desc_font)
    desc_label.add_theme_font_size_override("font_size", card_desc_font_size)
    desc_label.add_theme_color_override("font_color", card_desc_color)
    text_vbox.add_child(desc_label)

    return btn


func _spawn_menu(upgrades: Array[Upgrade], player: Player) -> void:
    _active_menu = upgrade_menu_scene.instantiate()
    _ui_container.add_child(_active_menu)
    var container = _active_menu.find_child("UpgradeOptions", true, false) as BoxContainer
    if container:
        container.add_theme_constant_override("separation", card_spacing)

    # Заголовок меню (настраивается через Inspector).
    var title := Label.new()
    title.name = "MenuTitle"
    title.text = menu_title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if menu_title_font:
        title.add_theme_font_override("font", menu_title_font)
    title.add_theme_font_size_override("font_size", menu_title_font_size)
    title.add_theme_color_override("font_color", menu_title_color)
    container.add_child(title)

    for i in range(upgrades.size()):
        var up = upgrades[i]
        var btn := _build_card(up, player)
        btn.scale = Vector2.ZERO
        btn.pivot_offset = card_size * 0.5
        var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        t.tween_property(btn, "scale", Vector2.ONE, 0.4).set_delay(i * 0.1)
        btn.pressed.connect(_on_upgrade_selected.bind(up))
        container.add_child(btn)


func _on_upgrade_selected(upgrade: Upgrade) -> void:
    var player = get_tree().get_first_node_in_group("player") as Player
    if upgrade.weapon_tag == "Fallback" and is_instance_valid(player) and is_instance_valid(player.health_component):
        player.health_component.heal(upgrade.amount)
    player.apply_custom_upgrade(upgrade)
    _active_menu.queue_free(); _active_menu = null
    if _pending_upgrades > 0:
        _pending_upgrades -= 1; open_upgrade_menu()
    else: get_tree().paused = false

func _on_player_level_up(_lvl) -> void:
    if _active_menu: _pending_upgrades += 1
    else: open_upgrade_menu()
