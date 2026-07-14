extends CharacterBody2D
class_name Player

signal xp_changed(current_xp: int, next_level_xp: int)
signal level_up(new_level: int)

@export_group("Base Stats")
@export var base_mass: float = 100.0
@export var base_stability: float = 100.0

@export_group("Movement & Combat")
@export var max_speed: float = 250.0:
    set(value):
        print("[UPGRADE] Speed: %.1f -> %.1f" % [max_speed, value])
        max_speed = value

@export var acceleration: float = 1800.0
@export var friction: float = 1500.0

@export var damage_multiplier: float = 1.0:
    set(value):
        print("[UPGRADE] Damage Multiplier: %.2f -> %.2f" % [damage_multiplier, value])
        damage_multiplier = value

# --- Сеттеры характеристик ---
@export var max_health: float = 1000.0:
    set(value):
        if is_node_ready() and is_instance_valid(health_component):
            var diff = value - max_health
            health_component.update_max_health(value)
            if diff > 0:
                health_component.current_health += diff
        print("[UPGRADE] Max Health: %.1f -> %.1f" % [max_health, value])
        max_health = value

@export var radius_weapons: float = 1.0:
    set(value):
        print("[UPGRADE] Weapon Radius: %.2f -> %.2f" % [radius_weapons, value])
        radius_weapons = value
        var weapons = find_children("*", "WeaponComponent", true)
        for weapon in weapons:
            if weapon.has_method("update_weapon_range"):
                weapon.update_weapon_range(value)

@export var xp_radius: float = 1.0:
    set(value):
        print("[UPGRADE] XP Magnet: %.2f -> %.2f" % [xp_radius, value])
        xp_radius = value
        if is_node_ready() and is_instance_valid(magnet_area):
            var col = magnet_area.get_node_or_null("CollisionShape2D")
            if col: col.scale = Vector2.ONE * value

@export var xp_gain: float = 1.0

# --- Динамические характеристики ---
var stability: float = 100.0
var applied_zone_speed_modifier: float = 1.0
var active_zones: Array[Area2D] = []
var mass: float = 100.0
const MAX_MASS: float = 500.0
var camp_buffs = {"speed": 0.0, "damage": 0.0, "stability": 0.0, "regen": 0.0}

@onready var polygon: Polygon2D = $Polygon2D
@onready var magnet_area: Area2D = %MagnetArea
@onready var health_component: HealthComponent = $HealthComponent

# --- Состояние ---
var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 10
var current_camp: Node2D = null 

func _ready() -> void:
    mass = base_mass
    stability = base_stability
    add_to_group("player")
    
    if is_instance_valid(health_component):
        health_component.update_max_health(max_health)
        health_component.health_depleted.connect(_on_death)
    
    if is_instance_valid(magnet_area):
        magnet_area.add_to_group("player_magnet")

func _physics_process(delta: float) -> void:
    if is_instance_valid(health_component) and health_component.current_health <= 0:
        _on_death()
        return

    _process_zone_influences(delta)
    _move_player(delta)
    _process_territory_interaction(delta)
    
    if camp_buffs.regen > 0 and health_component.current_health < max_health:
        health_component.current_health = min(health_component.current_health + camp_buffs.regen * delta, max_health)

func _move_player(delta: float) -> void:
    var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var mass_penalty = base_mass / mass
    var current_speed = max_speed * (1.0 + camp_buffs.speed) * applied_zone_speed_modifier * mass_penalty
    
    if input_vector != Vector2.ZERO:
        velocity = velocity.move_toward(input_vector * current_speed, acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
    move_and_slide()

func register_zone(zone: Area2D) -> void:
    if not active_zones.has(zone): active_zones.append(zone)

func unregister_zone(zone: Area2D) -> void:
    active_zones.erase(zone)

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
            if zone.get("current_state") == 2: # ACTIVE
                var z_inv = 20.0 * delta
                if spend_mass(z_inv): zone.inject_mass(z_inv)

func spend_mass(amount: float) -> bool:
    if mass > (base_mass + 1.0):
        var actual = min(amount, mass - base_mass)
        mass -= actual
        _update_visual_scale()
        return true
    return false

func collect_mass(amount: float) -> void:
    mass = clamp(mass + amount, base_mass, MAX_MASS)
    _update_visual_scale()

func _update_visual_scale() -> void:
    var s = 1.0 + ((mass / base_mass) - 1.0) * 0.7
    scale = scale.lerp(Vector2.ONE * s, 0.15)

func collect_xp(amount: int) -> void:
    current_xp += int(amount * xp_gain)
    while current_xp >= xp_to_next_level:
        current_xp -= xp_to_next_level
        current_level += 1
        xp_to_next_level = int(xp_to_next_level * 1.5)
        print("[DEBUG] Level Up triggered. New Level: ", current_level)
        level_up.emit(current_level)
    xp_changed.emit(current_xp, xp_to_next_level)

func apply_complex_camp_buffs(data: Dictionary) -> void:
    camp_buffs = data
    modulate = Color(0.8, 0.8, 1.5)

func remove_camp_buffs() -> void:
    camp_buffs = {"speed": 0.0, "damage": 0.0, "stability": 0.0, "regen": 0.0}
    modulate = Color.WHITE

func get_final_damage_multiplier() -> float:
    return damage_multiplier * (1.0 + camp_buffs.damage)

func apply_custom_upgrade(_upgrade) -> void:
    pass

func _on_death() -> void:
    if GameManager.has_method("reset_game"): GameManager.reset_game()
    get_tree().reload_current_scene()

func _on_magnet_area_entered(area: Area2D) -> void:
    if area.has_method("attract"): area.attract(self)
