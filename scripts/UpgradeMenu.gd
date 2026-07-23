extends Node

@export var upgrade_menu_scene: PackedScene
@onready var _ui_container: Control = %UpgradePanel
@export var all_available_upgrades: Array[Upgrade]

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

func open_upgrade_menu() -> void:    
    var player = get_tree().get_first_node_in_group("player") as Player
    if not player: return

    var eligible_pool = _get_eligible_upgrades(player)
    if eligible_pool.is_empty():
        # TODO: Gold/resources reward when all builds are maxed
        # player.add_gold(randi_range(50, 150))
        get_tree().paused = false; return

    get_tree().paused = true
    var selected_upgrades: Array[Upgrade] = []
    var temp_pool = eligible_pool.duplicate()
    
    for i in range(min(3, temp_pool.size())):
        var up = _pick_weighted_upgrade(temp_pool, player)
        selected_upgrades.append(up)
        temp_pool.erase(up)

    _spawn_menu(selected_upgrades, player)


# ═══════════════════════════════════════════════════════════
# ОСНОВНОЙ ФИЛЬТР — одна ветка на upgrade
# ═══════════════════════════════════════════════════════════

func _get_eligible_upgrades(player: Player) -> Array[Upgrade]:
    var weapons_full = player.active_weapons.size() >= player.unlocked_weapon_slots
    var passives_full = player.active_passives.size() >= player.unlocked_passive_slots
    var pool: Array[Upgrade] = []
    
    for u in all_available_upgrades:
        if _already_taken(u, player): continue
        if not _prerequisites_met(u, player): continue
        
        if u.change_mechanic_on_apply:
            if _can_take_evolution(u, player): pool.append(u)
        elif u.is_weapon:
            if _can_take_weapon(u, player, weapons_full): pool.append(u)
        elif u.weapon_tag != "" and u.weapon_tag != "General":
            if _can_take_modifier(u, player): pool.append(u)
        else:
            if _can_take_passive(u, player, passives_full): pool.append(u)
    
    return pool


# ═══════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════

func _already_taken(u: Upgrade, player: Player) -> bool:
    return u.is_unique and player.applied_upgrade_names.has(u.name)


func _prerequisites_met(u: Upgrade, player: Player) -> bool:
    for p in u.prerequisites:
        if not player.applied_upgrade_names.has(p):
            return false
    return true


func _can_take_evolution(u: Upgrade, player: Player) -> bool:
    # Оружие должно существовать в active_weapons (источник истины)
    var owns_weapon = false
    for w in player.active_weapons:
        if w.weapon_tag == u.weapon_tag:
            owns_weapon = true
            break
    if not owns_weapon:
        return false
    
    # Уровень оружия ≥ требуемого
    if player.tag_levels.get(u.weapon_tag, 0) < u.max_level_for_evo:
        return false
    
    # Нужная пассивка должна быть в active_passives
    if u.required_passive_tag != "":
        var has_passive = false
        for p in player.active_passives:
            if p.name == u.required_passive_tag:
                has_passive = true
                break
        if not has_passive:
            return false
    
    return true


func _can_take_weapon(u: Upgrade, player: Player, weapons_full: bool) -> bool:
    # Уже есть такое оружие?
    for w in player.active_weapons:
        if w.name == u.name:
            return false
    
    # Слоты полны?
    if weapons_full:
        return false
    
    return true


func _can_take_modifier(u: Upgrade, player: Player) -> bool:
    # Проверяем active_weapons — есть оружие с таким weapon_tag?
    for w in player.active_weapons:
        if w.weapon_tag == u.weapon_tag:
            return player.tag_levels.get(u.weapon_tag, 0) < 8
    
    # Проверяем active_passives — пассивки матчатся по name
    for p in player.active_passives:
        if p.name == u.weapon_tag:
            return player.tag_levels.get(u.weapon_tag, 0) < 8
    
    # Сирота — ни оружия, ни пассивки с таким тегом нет
    return false


func _can_take_passive(u: Upgrade, player: Player, passives_full: bool) -> bool:
    # Уже есть такая пассивка?
    for p in player.active_passives:
        if p.name == u.name:
            return false
    
    # Слоты полны?
    if passives_full:
        return false
    
    return true


# ═══════════════════════════════════════════════════════════
# ВЗВЕШЕННЫЙ СЛУЧАЙНЫЙ ВЫБОР
# ═══════════════════════════════════════════════════════════

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


# ═══════════════════════════════════════════════════════════
# МЕНЮ (визуал)
# ═══════════════════════════════════════════════════════════

func _spawn_menu(upgrades: Array[Upgrade], player: Player) -> void:
    _active_menu = upgrade_menu_scene.instantiate()
    _ui_container.add_child(_active_menu)
    var container = _active_menu.get_node_or_null("UpgradeOptions")
    for i in range(upgrades.size()):
        var up = upgrades[i]
        var btn = Button.new()
        var cur_lvl = player.tag_levels.get(up.weapon_tag, 0)
        var lvl_info = "\n[LVL %d -> %d]" % [cur_lvl, cur_lvl + 1]
        if cur_lvl >= 8:
            lvl_info = "\n[MAX LEVEL]"
        if up.change_mechanic_on_apply:
            lvl_info = "\n[EVOLUTION]"
        
        btn.text = up.name + lvl_info + "\n" + up.description
        btn.custom_minimum_size = Vector2(320, 160)
        btn.self_modulate = RARITY_COLORS[up.rarity]
        btn.scale = Vector2.ZERO
        btn.pivot_offset = Vector2(160, 80)
        var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        t.tween_property(btn, "scale", Vector2.ONE, 0.4).set_delay(i * 0.1)
        btn.pressed.connect(_on_upgrade_selected.bind(up))
        container.add_child(btn)

func _on_upgrade_selected(upgrade: Upgrade) -> void:
    var player = get_tree().get_first_node_in_group("player") as Player
    player.apply_custom_upgrade(upgrade)
    _active_menu.queue_free(); _active_menu = null
    if _pending_upgrades > 0:
        _pending_upgrades -= 1; open_upgrade_menu()
    else: get_tree().paused = false

func _on_player_level_up(_lvl) -> void:
    if _active_menu: _pending_upgrades += 1
    else: open_upgrade_menu()
