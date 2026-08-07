class_name SkyPiercer
extends BaseWeapon

const ARROW_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/SkyArrow.tscn")
const RELOAD_INDICATOR_SCENE: PackedScene = preload("res://Assets/Scenes/UI/ReloadIndicator.tscn")
const LEAD_TIME: float = 0.75

@export var max_ammo_base: int = 4
@export var burst_rate: float = 0.15
@export var aoe_radius: float = 120.0

var _drum_ammo: int = 0
var _drum_max: int = 4
var _burst_acc: float = 0.0
var _reloading: bool = false
var _target_index: int = 0
var _reload_indicator: Node = null


func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_reload_complete)
    cooldown_timer.wait_time = attack_cooldown  # reload duration
    _refill_drum()
    _spawn_reload_indicator()


func _spawn_reload_indicator() -> void:
    var indicator = RELOAD_INDICATOR_SCENE.instantiate()
    if not indicator:
        return
    # Attach to player so it follows
    if is_instance_valid(player):
        player.add_child(indicator)
        indicator.position = Vector2(18, -18)
    _reload_indicator = indicator
    if indicator is CanvasItem:
        indicator.visible = false


func _weapon_process(delta: float) -> void:
    # Update reload indicator
    _update_reload_indicator()
    
    if _reloading:
        return
    
    if _drum_ammo <= 0:
        _start_reload()
        return
    
    var enemies = _get_all_enemies_in_range()
    if enemies.is_empty():
        return  # save ammo, no auto-reload
    
    _burst_acc += delta
    while _burst_acc >= burst_rate and _drum_ammo > 0:
        _burst_acc -= burst_rate
        _fire_one_shot(enemies)


func _update_reload_indicator() -> void:
    if not _reload_indicator:
        return
    var ri = _reload_indicator
    if _reloading:
        if ri is CanvasItem:
            ri.visible = true
        var progress = (attack_cooldown - cooldown_timer.time_left) / max(0.01, attack_cooldown) * 100.0
        if ri.has_method("set_value"):
            ri.set_value(progress)


func _show_reload_indicator() -> void:
    if not _reload_indicator:
        return
    var ri = _reload_indicator
    ri.visible = true
    ri.modulate = Color(1, 1, 1, 0.0)
    var tw = create_tween()
    tw.tween_property(ri, "modulate:a", 0.9, 0.2)


func _hide_reload_indicator() -> void:
    if not _reload_indicator:
        return
    var ri = _reload_indicator
    ri.modulate.a = 0.0
    ri.visible = false


func _refill_drum() -> void:
    _drum_max = max_ammo_base + max(0, (player.projectile_amount if player else 1) - 1)
    _drum_ammo = _drum_max
    _reloading = false
    _burst_acc = 0.0
    _hide_reload_indicator()


func _start_reload() -> void:
    if _reloading:
        return
    _reloading = true
    cooldown_timer.start()
    print("[SKY PIERCER] RELOAD START: ", attack_cooldown, "s")
    _show_reload_indicator()


func _on_reload_complete() -> void:
    _refill_drum()
    _flash_indicator()


func _flash_indicator() -> void:
    if not _reload_indicator:
        return
    var ri = _reload_indicator
    ri.visible = true
    ri.modulate = Color(1, 1, 1, 1.0)
    var tw = create_tween()
    tw.tween_property(ri, "modulate:a", 0.0, 0.3)
    tw.tween_callback(func(): ri.visible = false)


func _fire_one_shot(enemies: Array) -> void:
    # Cycle targeting: even damage distribution
    var idx = _target_index % enemies.size()
    _target_index += 1
    var enemy = enemies[idx]
    var impact_pos = _predict_impact(enemy)
    if is_instance_valid(player):
        player.play_attack_animation(enemy.global_position)
    _spawn_arrow(impact_pos)
    _drum_ammo -= 1


func _spawn_arrow(target_pos: Vector2) -> void:
    var arrow = ARROW_SCENE.instantiate() as SkyArrow
    if not arrow:
        return
    
    var world_root = player.get_parent() if player else get_tree().current_scene
    arrow.target_pos = target_pos
    world_root.add_child(arrow)
    arrow.damage = final_damage
    arrow.aoe_radius = aoe_radius


func _predict_impact(enemy: Area2D) -> Vector2:
    var predicted = enemy.global_position
    var parent = enemy.get_parent()
    if parent and parent is CharacterBody2D:
        predicted += parent.velocity * LEAD_TIME
    return predicted


func _get_all_enemies_in_range() -> Array[Area2D]:
    var enemies: Array[Area2D] = []
    var space_state = get_world_2d().direct_space_state
    if space_state == null:
        return enemies
    
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = max_attack_distance * 2.5
    query.shape = circle
    query.transform = Transform2D(0, global_position)
    query.collision_mask = 12
    query.collide_with_areas = true
    query.collide_with_bodies = false
    
    var results = space_state.intersect_shape(query)
    for result in results:
        var collider = result.collider
        if collider.has_method("_apply_damage") and collider.get("faction") != "player":
            if not enemies.has(collider):
                enemies.append(collider)
    
    return enemies
