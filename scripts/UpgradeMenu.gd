extends Node

@export var upgrade_menu_scene: PackedScene
@onready var _ui_container: Control = %UpgradePanel
@export var all_available_upgrades: Array[Upgrade]

var _active_menu: Control = null
var _pending_upgrades: int = 0

const EVO_RECIPES = { "Spear": "Passive_Stone", "Aura": "Passive_Book" }

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
        get_tree().paused = false; return

    get_tree().paused = true
    var selected_upgrades: Array[Upgrade] = []
    var temp_pool = eligible_pool.duplicate()
    
    for i in range(min(3, temp_pool.size())):
        var up = _pick_weighted_upgrade(temp_pool, player)
        selected_upgrades.append(up)
        temp_pool.erase(up)

    _spawn_menu(selected_upgrades, player)

func _get_eligible_upgrades(player: Player) -> Array[Upgrade]:
    var weapons_full = player.active_weapons.size() >= player.max_weapon_slots
    var passives_full = player.active_passives.size() >= player.max_passive_slots
    var owned_tags = player.active_weapons.map(func(u): return u.weapon_tag)
    var owned_passives = player.active_passives.map(func(u): return u.name)

    var pool = all_available_upgrades.filter(func(u):
        if u.is_unique and player.applied_upgrade_names.has(u.name): return false
        for p in u.prerequisites:
            if not player.applied_upgrade_names.has(p): return false
        
        # Фильтр тегов (Hive-Mind)
        if u.is_weapon:
            if weapons_full and not owned_tags.has(u.weapon_tag): return false
        else:
            if passives_full and not owned_passives.has(u.name): return false
            
        if u.change_mechanic_on_apply: return false # Эволюции добавляются отдельно
        return true
    )
    
    # Проверка Эволюции
    for tag in owned_tags:
        var cur_lvl = player.tag_levels.get(tag, 0)
        var needed = EVO_RECIPES.get(tag, "")
        if cur_lvl >= 8 and player.applied_upgrade_names.has(needed):
            for u in all_available_upgrades:
                if u.change_mechanic_on_apply and u.weapon_tag == tag:
                    pool.append(u)
    return pool

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

func _spawn_menu(upgrades: Array[Upgrade], player: Player) -> void:
    _active_menu = upgrade_menu_scene.instantiate()
    _ui_container.add_child(_active_menu)
    var container = _active_menu.get_node_or_null("UpgradeOptions")
    for i in range(upgrades.size()):
        var up = upgrades[i]
        var btn = Button.new()
        var cur_lvl = player.tag_levels.get(up.weapon_tag, 0)
        var lvl_info = "\n[LVL %d -> %d]" % [cur_lvl, cur_lvl + 1]
        if up.change_mechanic_on_apply: lvl_info = "\n[EVOLUTION]"
        
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
