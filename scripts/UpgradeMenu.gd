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

const EVOLUTION_FAMILIES := {
    "Bow": ["SiegeCrossbow", "SpectralVolley", "SkyPiercer"],
    "Banner": ["BannerArcher", "BannerTank", "BannerMarshal"],
}

func open_upgrade_menu() -> void:    
    var player = get_tree().get_first_node_in_group("player") as Player
    if not player: return

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
    f.description = "Восстанавливает 50 HP"
    f.rarity = Upgrade.Rarity.COMMON
    f.weapon_tag = "Fallback"
    f.amount = 50.0
    if is_instance_valid(player) and is_instance_valid(player.health_component):
        player.health_component.heal(50.0)
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


func _spawn_menu(upgrades: Array[Upgrade], player: Player) -> void:
    _active_menu = upgrade_menu_scene.instantiate()
    _ui_container.add_child(_active_menu)
    var container = _active_menu.get_node_or_null("UpgradeOptions")
    for i in range(upgrades.size()):
        var up = upgrades[i]
        var btn = Button.new()
        var level_tag = up.passive_id if up.passive_id != "" else up.weapon_tag
        var cur_lvl = player.tag_levels.get(level_tag, 0)
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
