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
        print("[STATS] Max Health updated: ", max_health)

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

# --- СИСТЕМА БАФФОВ ЛАГЕРЯ ---
var camp_buffs = {
    "speed": 0.0,
    "damage": 0.0,
    "stability": 0.0,
    "regen": 0.0
}
var _regen_timer: float = 0.0 # Для ограничения спама в лог

# --- Ссылки ---
@onready var polygon: Polygon2D = $Polygon2D
@onready var magnet_area: Area2D = %MagnetArea
@onready var health_component: HealthComponent = $HealthComponent

# --- Состояние ---
var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 10
var current_camp: Camp = null 

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
    if is_instance_valid(health_component):
        if health_component.current_health <= 0:
            _on_death()
            return
        
        # Регенерация в лагере
        if camp_buffs.regen > 0 and health_component.current_health < max_health:
            health_component.current_health = min(health_component.current_health + camp_buffs.regen * delta, max_health)
            
            # Логируем реген раз в секунду
            _regen_timer += delta
            if _regen_timer >= 1.0:
                print("[CAMP REGEN] Health: %.1f / %.1f" % [health_component.current_health, max_health])
                _regen_timer = 0.0

    _process_zone_influences(delta)
    _move_player(delta)
    _process_territory_interaction(delta)

func _move_player(delta: float) -> void:
    var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var mass_penalty = base_mass / mass
    var camp_speed_mod = 1.0 + camp_buffs.speed
    var current_speed = max_speed * applied_zone_speed_modifier * camp_speed_mod * mass_penalty
    
    if input_vector != Vector2.ZERO:
        velocity = velocity.move_toward(input_vector * current_speed, acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
    move_and_slide()

func _process_territory_interaction(delta: float) -> void:
    if is_instance_valid(current_camp):
        if current_camp.is_player_alignment():
            var camp_inv = 50.0 * delta 
            if spend_mass(camp_inv):
                current_camp.upgrade(camp_inv)
            
    active_zones = active_zones.filter(func(z): return is_instance_valid(z))
    for zone in active_zones:
        if zone.has_method("inject_mass") and zone.get("current_state") == 2: # ACTIVE
            var zone_inv = 20.0 * delta
            if spend_mass(zone_inv):
                zone.inject_mass(zone_inv)

# --- Применение баффов с логированием ---
func apply_complex_camp_buffs(buff_data: Dictionary) -> void:
    camp_buffs.speed = buff_data.speed
    camp_buffs.damage = buff_data.damage
    camp_buffs.stability = buff_data.stability
    camp_buffs.regen = buff_data.regen
    
    print("--- [BUFF APPLIED] ---")
    print("Speed: +%d%%" % (camp_buffs.speed * 100))
    print("Damage: +%d%%" % (camp_buffs.damage * 100))
    print("Stability: +%d%%" % (camp_buffs.stability * 100))
    print("Regen: %.1f HP/s" % camp_buffs.regen)
    print("----------------------")
    
    modulate = Color(0.7, 0.8, 1.5) # Визуальный отклик

func remove_camp_buffs() -> void:
    if camp_buffs.speed > 0:
        print("[BUFF] Removed all camp buffs.")
    camp_buffs.speed = 0.0
    camp_buffs.damage = 0.0
    camp_buffs.stability = 0.0
    camp_buffs.regen = 0.0
    modulate = Color.WHITE

func get_final_damage_multiplier() -> float:
    return damage_multiplier * (1.0 + camp_buffs.damage)

func spend_mass(amount: float) -> bool:
    if mass > (base_mass + 0.1):
        var actual_spend = min(amount, mass - base_mass)
        mass -= actual_spend
        _update_visual_scale()
        return true
    return false

func collect_mass(amount: float) -> void:
    mass = clamp(mass + amount, base_mass, MAX_MASS)
    _update_visual_scale()
    print("[MASS] Collected. Current total: ", int(mass))

func _update_visual_scale() -> void:
    var s = 1.0 + ((mass / base_mass) - 1.0) * 0.8
    scale = scale.lerp(Vector2.ONE * s, 0.2)

func _process_zone_influences(delta: float) -> void:
    var speed_mod: float = 1.0
    active_zones = active_zones.filter(func(z): return is_instance_valid(z))
    var camp_stability_boost = 1.0 + camp_buffs.stability
    
    for zone in active_zones:
        if zone.has_method("get_influence_factor"):
            var influence = zone.get_influence_factor(global_position)
            match zone.get("zone_type"):
                "Acceleration": speed_mod += influence * 1.0
                "Stabilization": stability += influence * 30.0 * delta * camp_stability_boost
                "Pressure": stability -= (influence * 30.0 * delta) / camp_stability_boost
                
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
    print("[GAME] Player died. Resetting...")
    if GameManager.has_method("reset_game"): GameManager.reset_game()
    get_tree().reload_current_scene()

func _on_hit_received(_damage: float) -> void:
    if is_instance_valid(polygon):
        polygon.modulate = Color.RED
        create_tween().tween_property(polygon, "modulate", Color.WHITE, 0.15)
