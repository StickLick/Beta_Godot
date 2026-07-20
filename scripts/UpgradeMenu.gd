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
        get_tree().paused = false; return

    get_tree().paused = true
    
    var selected_upgrades: Array[Upgrade] = []
    var temp_pool = eligible_pool.duplicate()
    
    for i in range(min(3, temp_pool.size())):
        var up = _pick_weighted_upgrade(temp_pool, player)
        selected_upgrades.append(up)
        temp_pool.erase(up)

    _spawn_menu(selected_upgrades)

func _get_eligible_upgrades(player: Player) -> Array[Upgrade]:
    return all_available_upgrades.filter(func(u):
        # 1. Проверка уникальности
        if u.is_unique and player.applied_upgrade_names.has(u.name): return false
        
        # 2. Проверка ВСЕХ пререквизитов (Синергии)
        for p in u.prerequisites:
            if not player.applied_upgrade_names.has(p): return false
            
        return true
    )

func _pick_weighted_upgrade(pool: Array[Upgrade], player: Player) -> Upgrade:
    var total_weight = 0.0
    var weights = []
    
    for u in pool:
        var w = BASE_WEIGHTS[u.rarity]
        # Удача влияет на веса редких предметов
        if u.rarity >= Upgrade.Rarity.RARE:
            w *= player.luck
        weights.append(w)
        total_weight += w
    
    var roll = randf() * total_weight
    var cursor = 0.0
    for i in range(pool.size()):
        cursor += weights[i]
        if roll <= cursor: return pool[i]
    return pool[0]

func _spawn_menu(upgrades: Array[Upgrade]) -> void:
    _active_menu = upgrade_menu_scene.instantiate()
    _ui_container.add_child(_active_menu)
    
    var container = _active_menu.get_node_or_null("UpgradeOptions")
    for i in range(upgrades.size()):
        var up = upgrades[i]
        var btn = Button.new()
        btn.text = up.name + "\n" + up.description
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
    else:
        get_tree().paused = false

func _on_player_level_up(_lvl) -> void:
    if _active_menu: _pending_upgrades += 1
    else: open_upgrade_menu()
