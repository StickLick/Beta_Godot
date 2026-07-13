extends CharacterBody2D
class_name Player

# --- Сигналы ---
signal xp_changed(current_xp: int, next_level_xp: int)
signal level_up(new_level: int)

# --- Настройки базовых характеристик (Legion Architecture) ---
@export_group("Base Stats")
@export var base_mass: float = 100.0
@export var base_stability: float = 100.0

# --- Свойства движения и боя ---
@export_group("Movement & Combat")
@export var max_speed: float = 250.0:
    set(value):
        var old_speed = max_speed
        max_speed = value
        print("[DEBUG] Speed Upgrade: %.1f -> %.1f" % [old_speed, max_speed])

@export var acceleration: float = 1800.0
@export var friction: float = 1500.0

@export var damage_multiplier: float = 1.0:
    set(value):
        damage_multiplier = value
        print("[DEBUG] Damage Multiplier: %.2f" % damage_multiplier)

# --- Сеттеры характеристик ---
@export var max_health: float = 100.0:
    set(value):
        max_health = value
        if is_instance_valid(health_component):
            health_component.update_max_health(value)

@export var radius_weapons: float = 1.0:
    set(value):
        radius_weapons = value
        var weapons: Array[Node] = find_children("*", "WeaponComponent", true)
        for weapon in weapons:
            if weapon.has_method("update_weapon_range"):
                weapon.call("update_weapon_range", value)

@export var xp_radius: float = 1.0:
    set(value):
        xp_radius = value
        if is_instance_valid(magnet_area):
            var col_shape: CollisionShape2D = magnet_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
            if col_shape:
                col_shape.scale = Vector2.ONE * value

@export var xp_gain: float = 1.0

# --- Динамические характеристики ---
var stability: float = 100.0
var applied_zone_speed_modifier: float = 1.0
var active_zones: Array[Area2D] = []
var mass: float = 100.0
const MAX_MASS: float = 500.0

# --- Характеристики уровня ---
var current_level: int = 1
var current_xp: int = 90
var xp_to_next_level: int = 100

# --- Ссылки на компоненты ---
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var polygon: Polygon2D = $Polygon2D
@onready var magnet_area: Area2D = %MagnetArea

func _ready() -> void:
    mass = base_mass
    stability = base_stability
    add_to_group("player")
    
    if health_component:
        health_component.health_depleted.connect(_on_death)
    if hurtbox_component:
        hurtbox_component.hit_received.connect(_on_hit_received)
    if magnet_area:
        magnet_area.area_entered.connect(_on_magnet_area_entered)

func _physics_process(delta: float) -> void:
    _process_zone_influences(delta)
    _move_player(delta)

func _move_player(delta: float) -> void:
    var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    
    var mass_penalty: float = base_mass / mass
    var current_speed: float = max_speed * applied_zone_speed_modifier * mass_penalty
    
    if input_vector != Vector2.ZERO:
        velocity = velocity.move_toward(input_vector * current_speed, acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
    
    move_and_slide()

func apply_custom_upgrade(upgrade: Upgrade) -> void:
    # Здесь можно добавить специфическую логику
    pass

func _process_zone_influences(delta: float) -> void:
    var speed_modifier: float = 1.0
    active_zones = active_zones.filter(func(zone: Area2D) -> bool: return is_instance_valid(zone))
    
    for zone in active_zones:
        if not zone.has_method("get_influence_factor"): continue
        
        var influence: float = zone.get_influence_factor(global_position)
        var zone_type: String = zone.get("zone_type") if "zone_type" in zone else "Acceleration"
        
        var dominance: float = zone.get("dominance") if "dominance" in zone else 1.0
        var resonance_target: float = base_stability if dominance > 1.0 else 0.0
        stability = lerp(stability, resonance_target, delta * 0.5)
        
        match zone_type:
            "Acceleration": speed_modifier += influence * 1.0
            "Pressure": stability -= influence * 15.0 * (mass / base_mass) * delta
            "Stabilization": stability += influence * 10.0 * delta
            "Flux": speed_modifier += (randf_range(-0.5, 1.5)) * influence
    
    applied_zone_speed_modifier = speed_modifier * get_movement_penalty()
    stability = clamp(stability, 0.0, base_stability * 2.0)

func get_movement_penalty() -> float:
    var stability_normalized: float = stability / base_stability
    return lerp(0.2, 1.0, stability_normalized) if stability_normalized < 0.3 else 1.0

func collect_mass(amount: float) -> void:
    mass = clamp(mass + amount, base_mass, MAX_MASS)
    var scale_factor: float = 1.0 + ((mass / base_mass) - 1.0) * 0.5
    scale = scale.lerp(Vector2.ONE * scale_factor, 0.1)

func collect_xp(amount: int) -> void:
    var final_amount: int = int(amount * xp_gain)
    current_xp += final_amount
    while current_xp >= xp_to_next_level:
        current_xp -= xp_to_next_level
        current_level += 1
        xp_to_next_level = int(xp_to_next_level * 1.5)
        level_up.emit(current_level)
    xp_changed.emit(current_xp, xp_to_next_level)

func register_zone(zone: Area2D) -> void:
    if is_instance_valid(zone) and not active_zones.has(zone): active_zones.append(zone)

func unregister_zone(zone: Area2D) -> void:
    active_zones.erase(zone)

func _on_death() -> void:
    GameManager.reset_game()
    get_tree().call_deferred("reload_current_scene")

func _on_hit_received(_damage: float) -> void:
    _flash_damage()

func _flash_damage() -> void:
    if is_instance_valid(polygon):
        polygon.modulate = Color.RED
        var tween: Tween = create_tween()
        tween.tween_property(polygon, "modulate", Color.WHITE, 0.15)

func _on_magnet_area_entered(area: Area2D) -> void:
    if area.has_method("attract"): area.call("attract", self)
