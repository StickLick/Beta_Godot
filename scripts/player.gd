extends CharacterBody2D
class_name Player

# --- Сигналы ---
signal xp_changed(current_xp: int, next_level_xp: int)
signal level_up(new_level: int)

# --- Настройки базовых характеристик ---
@export_group("Base Stats")
@export var base_mass: float = 100.0
@export var base_stability: float = 100.0

# --- Свойства движения и боя ---
@export_group("Movement & Combat")
@export var max_speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1500.0
@export var damage_multiplier: float = 1.0

# --- Сеттеры характеристик ---
@export var max_health: float = 1000.0:
    set(value):
        var old_max = max_health
        max_health = value
        if is_instance_valid(health_component):
            health_component.update_max_health(value)
            if value > old_max:
                health_component.current_health += (value - old_max)

@export var radius_weapons: float = 1.0:
    set(value):
        radius_weapons = value
        var weapons = find_children("*", "WeaponComponent", true)
        for weapon in weapons:
            if weapon.has_method("update_weapon_range"):
                weapon.call("update_weapon_range", value)

@export var xp_radius: float = 1.0:
    set(value):
        xp_radius = value
        if is_instance_valid(magnet_area):
            var col = magnet_area.get_node_or_null("CollisionShape2D")
            if col: col.scale = Vector2.ONE * value

@export var xp_gain: float = 1.0

# --- Динамические характеристики ---
var stability: float = 100.0
var applied_zone_speed_modifier: float = 1.0
var active_zones: Array[Area2D] = []
var mass: float = 100.0
const MAX_MASS: float = 500.0

# --- Ссылки ---
@onready var polygon: Polygon2D = $Polygon2D
@onready var magnet_area: Area2D = %MagnetArea
@onready var health_component: HealthComponent = $HealthComponent

# --- Состояние ---
var current_level: int = 1
var current_xp: int = 10
var xp_to_next_level: int = 20
var current_camp: Node2D = null 

func _ready() -> void:
    mass = base_mass
    stability = base_stability
    add_to_group("player")
    
    # Принудительная синхронизация при старте
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

func _move_player(delta: float) -> void:
    var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var mass_penalty = base_mass / mass
    var current_speed = max_speed * applied_zone_speed_modifier * mass_penalty
    
    if input_vector != Vector2.ZERO:
        velocity = velocity.move_toward(input_vector * current_speed, acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
    move_and_slide()

func _process_territory_interaction(delta: float) -> void:
    # 1. Логика Лагеря
    if is_instance_valid(current_camp):
        # Проверяем метод и принадлежность игроку
        if current_camp.has_method("is_player_alignment") and current_camp.is_player_alignment():
            var camp_inv = 60.0 * delta # Увеличили скорость передачи
            if spend_mass(camp_inv):
                current_camp.upgrade(camp_inv)
            
    # 2. Логика Зоны
    active_zones = active_zones.filter(func(z): return is_instance_valid(z))
    for zone in active_zones:
        if zone.has_method("inject_mass") and zone.get("current_state") == 2: # 2 = ACTIVE
            var zone_inv = 20.0 * delta
            if spend_mass(zone_inv):
                zone.inject_mass(zone_inv)

func spend_mass(amount: float) -> bool:
    # Тратим только если масса больше базы
    if mass > base_mass:
        var actual_spend = min(amount, mass - base_mass)
        mass -= actual_spend
        _update_visual_scale()
        return true
    return false

func collect_mass(amount: float) -> void:
    mass = clamp(mass + amount, base_mass, MAX_MASS)
    _update_visual_scale()

func _update_visual_scale() -> void:
    var s = 1.0 + ((mass / base_mass) - 1.0) * 0.8
    scale = scale.lerp(Vector2.ONE * s, 0.2)

func _process_zone_influences(delta: float) -> void:
    var speed_mod: float = 1.0
    active_zones = active_zones.filter(func(z): return is_instance_valid(z))
    for zone in active_zones:
        if zone.has_method("get_influence_factor"):
            var influence = zone.get_influence_factor(global_position)
            match zone.get("zone_type"):
                "Acceleration": speed_mod += influence * 1.0
                "Stabilization": stability += influence * 25.0 * delta
                "Pressure": stability -= influence * 30.0 * delta
    applied_zone_speed_modifier = speed_mod
    stability = clamp(stability, 0.0, base_stability * 2.0)

func collect_xp(amount: int) -> void:
    current_xp += amount
    while current_xp >= xp_to_next_level:
        current_xp -= xp_to_next_level
        current_level += 1
        xp_to_next_level = int(xp_to_next_level * 1.5)
        level_up.emit(current_level)
    xp_changed.emit(current_xp, xp_to_next_level)

func register_zone(zone: Area2D) -> void:
    if not active_zones.has(zone): active_zones.append(zone)

func unregister_zone(zone: Area2D) -> void:
    active_zones.erase(zone)

func _on_magnet_area_entered(area: Area2D) -> void:
    if area.has_method("attract"): area.attract(self)

func _on_death() -> void:
    if GameManager.has_method("reset_game"): GameManager.reset_game()
    get_tree().reload_current_scene()

func _on_hit_received(_damage: float) -> void:
    if is_instance_valid(polygon):
        polygon.modulate = Color.RED
        create_tween().tween_property(polygon, "modulate", Color.WHITE, 0.15)
