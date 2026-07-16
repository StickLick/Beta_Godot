extends CharacterBody2D
class_name Player

signal xp_changed(current_xp: int, next_level_xp: int)
signal level_up(new_level: int)

@export_group("Base Stats")
@export var base_mass: float = 100.0
@export var base_stability: float = 100.0

@export_group("Movement & Combat")
@export var max_speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1500.0
@export var damage_multiplier: float = 1.0

@export var max_health: float = 1000.0:
    set(value):
        if is_node_ready() and is_instance_valid(health_component):
            var diff = value - max_health
            health_component.update_max_health(value)
            if diff > 0: health_component.current_health += diff
        max_health = value

@export var radius_weapons: float = 1.0
@export var xp_radius: float = 1.0
@export var xp_gain: float = 1.0

var stability: float = 100.0
var applied_zone_speed_modifier: float = 1.0
var active_zones: Array[Area2D] = []
var mass: float = 100.0
const MAX_MASS: float = 500.0
var camp_buffs = {"speed": 0.0, "damage": 0.0, "stability": 0.0, "regen": 0.0}

var is_attacking: bool = false
var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 10
var current_camp: Node2D = null

@onready var magnet_area: Area2D = %MagnetArea
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    mass = base_mass
    stability = base_stability
    add_to_group("player")
    if animated_sprite: animated_sprite.animation_finished.connect(_on_animation_finished)
    if is_instance_valid(health_component):
        health_component.update_max_health(max_health)
        health_component.health_depleted.connect(_on_death)
    if is_instance_valid(magnet_area): magnet_area.add_to_group("player_magnet")

func _physics_process(delta: float) -> void:
    if is_instance_valid(health_component) and health_component.current_health <= 0:
        _on_death(); return

    _process_zone_influences(delta)
    var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    _move_player(delta, input_vector)
    if not is_attacking: _update_animations(input_vector)
    _process_territory_interaction(delta)
    
    if camp_buffs.regen > 0 and health_component.current_health < max_health:
        health_component.current_health = min(health_component.current_health + camp_buffs.regen * delta, max_health)

func collect_xp(amount: int) -> void:
    var total_gain = int(amount * xp_gain)
    current_xp += total_gain
    GameManager.log_event("xp", total_gain)

    while current_xp >= xp_to_next_level:
        current_xp -= xp_to_next_level
        current_level += 1
        xp_to_next_level = int(xp_to_next_level * 1.2)
        level_up.emit(current_level)
    xp_changed.emit(current_xp, xp_to_next_level)

func apply_complex_camp_buffs(data: Dictionary) -> void:
    camp_buffs = data
    modulate = Color(0.8, 0.8, 1.5)

func remove_camp_buffs() -> void:
    camp_buffs = {"speed": 0.0, "damage": 0.0, "stability": 0.0, "regen": 0.0}
    modulate = Color.WHITE

func play_attack_animation(target_position: Vector2) -> void:
    is_attacking = true
    var direction = (target_position - global_position).normalized()
    var anim_name = _get_attack_animation_name(direction)
    if animated_sprite.animation != anim_name: animated_sprite.play(anim_name)
    animated_sprite.flip_h = (direction.x < 0)

func _get_attack_animation_name(dir: Vector2) -> String:
    var angle = rad_to_deg(dir.angle())
    if angle > -22.5 and angle <= 22.5: return "RightAttack"
    elif angle > 22.5 and angle <= 67.5: return "DownRightAttack"
    elif angle > 67.5 and angle <= 112.5: return "DownAttack"
    elif angle > 112.5 and angle <= 157.5: return "DownRightAttack"
    elif angle > -67.5 and angle <= -22.5: return "UpRightAttack"
    elif angle > -112.5 and angle <= -67.5: return "UpAttack"
    elif angle > -157.5 and angle <= -112.5: return "UpRightAttack"
    else: return "RightAttack"

func _update_animations(input_vector: Vector2) -> void:
    if input_vector != Vector2.ZERO:
        animated_sprite.play("Run"); animated_sprite.flip_h = (input_vector.x < 0)
    else: animated_sprite.play("Idle")

func _on_animation_finished() -> void:
    if animated_sprite.animation in ["RightAttack", "DownRightAttack", "DownAttack", "UpAttack", "UpRightAttack"]:
        is_attacking = false

func _move_player(delta: float, input_vector: Vector2) -> void:
    var mass_penalty = base_mass / mass
    var current_speed = max_speed * (1.0 + camp_buffs.speed) * applied_zone_speed_modifier * mass_penalty
    if input_vector != Vector2.ZERO: velocity = velocity.move_toward(input_vector * current_speed, acceleration * delta)
    else: velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
    move_and_slide()

func register_zone(zone: Area2D) -> void: if not active_zones.has(zone): active_zones.append(zone)
func unregister_zone(zone: Area2D) -> void: active_zones.erase(zone)

func collect_mass(amount: float) -> void:
    mass = clamp(mass + amount, base_mass, MAX_MASS)
    _update_visual_scale()

func _process_zone_influences(delta: float) -> void:
    var speed_mod: float = 1.0
    active_zones = active_zones.filter(func(z): return is_instance_valid(z))
    for zone in active_zones:
        if zone.has_method("get_influence_factor"):
            var influence = zone.get_influence_factor(global_position)
            var type = zone.get("zone_type") if "zone_type" in zone else "Acceleration"
            match type:
                "Acceleration": speed_mod += influence * 1.0
                "Stabilization": stability += influence * 30.0 * delta
                "Pressure": stability -= influence * 30.0 * delta
    applied_zone_speed_modifier = speed_mod
    stability = clamp(stability, 0.0, base_stability * 2.0)

func _process_territory_interaction(delta: float) -> void:
    if is_instance_valid(current_camp) and current_camp.alignment == 1:
        var inv = 50.0 * delta
        if spend_mass(inv): current_camp.upgrade(inv)
    for zone in active_zones:
        if is_instance_valid(zone) and zone.has_method("inject_mass"):
            if zone.get("current_state") == 2:
                var z_inv = 20.0 * delta
                if spend_mass(z_inv): zone.inject_mass(z_inv)

func spend_mass(amount: float) -> bool:
    if mass > (base_mass + 1.0):
        var actual_spend = min(amount, mass - base_mass)
        mass -= actual_spend; _update_visual_scale(); return true
    return false

func get_final_damage_multiplier() -> float: return damage_multiplier * (1.0 + camp_buffs.damage)
func _update_visual_scale() -> void:
    var s = 1.0 + ((mass / base_mass) - 1.0) * 0.7
    scale = scale.lerp(Vector2.ONE * s, 0.15)

func _on_death() -> void:
    if GameManager.has_method("reset_game"): GameManager.reset_game()
    get_tree().reload_current_scene()
