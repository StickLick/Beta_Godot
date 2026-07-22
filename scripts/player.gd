extends CharacterBody2D
class_name Player

signal xp_changed(current_xp: int, next_level_xp: int)
signal level_up(new_level: int)
signal inventory_updated 

@export_group("Base Stats")
@export var base_mass: float = 100.0
@export var base_stability: float = 100.0

@export_group("Movement & Combat")
@export var max_speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1500.0
@export var damage_multiplier: float = 1.0

@export_group("Advanced Stats")
@export var luck: float = 1.0
@export var crit_chance: float = 0.05
@export var crit_damage: float = 1.5
@export var lifesteal: float = 0.0
@export var health_regen: float = 0.0

@export var max_health: float = 1000.0:
    set(value):
        max_health = value
        if is_node_ready() and is_instance_valid(health_component):
            health_component.update_max_health(max_health)

@export var radius_weapons: float = 1.0
@export var xp_radius: float = 1.0
@export var xp_gain: float = 1.0

# --- ИНВЕНТАРЬ И ТЕГИ ---
var max_weapon_slots: int = 3
var max_passive_slots: int = 3
var active_weapons: Array[Upgrade] = []
var active_passives: Array[Upgrade] = []
var applied_upgrade_names: Array[String] = []
var tag_levels: Dictionary = {} # {"Spear": 5}

# --- ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ---
var stability: float = 100.0
var applied_zone_speed_modifier: float = 1.0
var active_zones: Array[Area2D] = []
var mass: float = 100.0
const MAX_MASS: float = 500.0
var camp_buffs = {"speed": 0.0, "damage": 0.0, "stability": 0.0, "regen": 0.0}

var is_attacking: bool = false
var _disruptor_debuff_timer: float = 0.0
var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 100
var current_camp: Node2D = null

@onready var magnet_area: Area2D = %MagnetArea
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    mass = base_mass
    stability = base_stability
    add_to_group("player")
    if animated_sprite: 
        animated_sprite.animation_finished.connect(_on_animation_finished)
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
    _process_anomalies_damage(delta)
    _process_feast_debuffs()
    
    var total_regen = health_regen + camp_buffs.regen
    if total_regen > 0 and health_component.current_health < max_health:
        health_component.heal(total_regen * delta)
    
    var debuff = 1.0
    if _disruptor_debuff_timer > 0:
        _disruptor_debuff_timer -= delta
        debuff = 0.4
        modulate = Color(0.7, 0.3, 1.0)
        if _disruptor_debuff_timer <= 0: modulate = Color.WHITE
    
    var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    _move_player(delta, input_vector, debuff)
    
    if not is_attacking:
        _update_animations(input_vector)
        
    _process_territory_interaction(delta)

# --- МЕТОДЫ БАФФОВ И УРОНА ---

func get_final_damage_multiplier() -> float:
    return damage_multiplier * (1.0 + camp_buffs.damage)

func apply_complex_camp_buffs(data: Dictionary) -> void:
    camp_buffs = data
    if _disruptor_debuff_timer <= 0: modulate = Color(0.8, 0.8, 1.5)

func remove_camp_buffs() -> void:
    camp_buffs = {"speed": 0.0, "damage": 0.0, "stability": 0.0, "regen": 0.0}
    if _disruptor_debuff_timer <= 0: modulate = Color.WHITE

# --- ИНВЕНТАРЬ И УЛУЧШЕНИЯ ---

func apply_custom_upgrade(upgrade: Upgrade) -> void:
    # 1. Трекинг тегов и уровней
    var tag = upgrade.weapon_tag
    tag_levels[tag] = tag_levels.get(tag, 0) + 1
    
    # 2. Регистрация в инвентаре
    if upgrade.is_weapon:
        var already_owned = active_weapons.any(func(u): return u.weapon_tag == tag)
        if not already_owned:
            active_weapons.append(upgrade)
    else:
        var already_owned = active_passives.any(func(u): return u.name == upgrade.name)
        if not already_owned:
            active_passives.append(upgrade)
            
    if not applied_upgrade_names.has(upgrade.name):
        applied_upgrade_names.append(upgrade.name)
    
    # 3. Эволюция
    if upgrade.change_mechanic_on_apply and upgrade.evolved_weapon_scene != null:
        apply_evolution(upgrade.target_weapon_name, upgrade.evolved_weapon_scene)
    
    # 4. Применение статов
    var stat = upgrade.stat_to_modify
    if stat != "":
        if stat in self:
            set(stat, get(stat) + upgrade.amount)
        else:
            var weapons = find_children("*", "WeaponComponent", true)
            for w in weapons:
                if w.get("weapon_name") == tag or w.get("weapon_name") == upgrade.target_weapon_name:
                    if stat in w: 
                        w.set(stat, w.get(stat) + upgrade.amount)
                    if w.has_method("on_modifier_applied"): 
                        w.on_modifier_applied()
            
    inventory_updated.emit()

func apply_evolution(weapon_name: String, evolved_scene: PackedScene) -> void:
    var weapons = find_children("*", "WeaponComponent", true)
    for w in weapons:
        if w.get("weapon_name") == weapon_name:
            var old_pos = w.position
            w.queue_free()
            var new_weapon = evolved_scene.instantiate()
            new_weapon.position = old_pos
            add_child(new_weapon)
            _play_evolution_fx()
            break

func _play_evolution_fx() -> void:
    var camera = get_viewport().get_camera_2d()
    if camera and camera.has_method("apply_shake"): camera.apply_shake(25.0)
    Engine.time_scale = 0.05
    get_tree().create_timer(0.3, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
    var flash = create_tween()
    flash.tween_property(self, "modulate", Color(20, 20, 20), 0.1)
    flash.tween_property(self, "modulate", Color.WHITE, 0.5)

# --- ЗОНЫ И ВЗАИМОДЕЙСТВИЕ ---

func register_zone(zone: Area2D) -> void:
    if not active_zones.has(zone):
        active_zones.append(zone)

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
    if is_instance_valid(current_camp) and current_camp.get("alignment") == 1:
        var inv = 50.0 * delta
        if spend_mass(inv):
            if current_camp.has_method("upgrade"):
                current_camp.upgrade(inv)
                
    for zone in active_zones:
        if is_instance_valid(zone) and zone.has_method("inject_mass"):
            if zone.get("current_state") == 2:
                var z_inv = 20.0 * delta
                if spend_mass(z_inv):
                    zone.inject_mass(z_inv)

func _process_anomalies_damage(delta: float) -> void:
    if not is_inside_tree(): return
    if GameManager.current_anomaly == "COLLAPSE":
        var sz = get_tree().get_first_node_in_group("safe_zone")
        if is_instance_valid(sz):
            if global_position.distance_to(sz.global_position) > sz.current_radius:
                health_component.take_damage(15.0 * delta)

func _process_feast_debuffs() -> void:
    var is_feast = GameManager.get_meta("shadow_feast_active", false)
    var range_mult = 0.4 if is_feast else 1.0
    var weapons = find_children("*", "WeaponComponent", true)
    for weapon in weapons:
        if weapon.has_method("update_weapon_range"): weapon.update_weapon_range(radius_weapons * range_mult)
    if is_instance_valid(magnet_area):
        var col = magnet_area.get_node_or_null("CollisionShape2D")
        if col: col.scale = Vector2.ONE * (xp_radius * range_mult)

# --- ДВИЖЕНИЕ И АНИМАЦИЯ ---

func _move_player(delta: float, input: Vector2, debuff: float) -> void:
    var mass_penalty = base_mass / mass
    var current_speed = max_speed * (1.0 + camp_buffs.speed) * applied_zone_speed_modifier * debuff * mass_penalty
    var accel_final = acceleration; var fric_final = friction
    if GameManager.get_meta("inertia_active", false): accel_final = 180.0; fric_final = 60.0
    if input != Vector2.ZERO: velocity = velocity.move_toward(input * current_speed, accel_final * delta)
    else: velocity = velocity.move_toward(Vector2.ZERO, fric_final * delta)
    _apply_gravity_logic(delta)
    move_and_slide()

func _apply_gravity_logic(delta: float) -> void:
    if not is_inside_tree(): return
    var wells = get_tree().get_nodes_in_group("gravity_well")
    for well in wells:
        if not is_instance_valid(well): continue
        var vec = well.global_position - global_position
        var dist = vec.length()
        var pull_rad = well.get("pull_radius") if "pull_radius" in well else 500.0
        if dist < pull_rad:
            var dir = vec.normalized(); var f_pct = clamp(1.1 - (dist / pull_rad), 0.2, 1.0)
            velocity += dir * (400.0 * f_pct * delta)

func _update_animations(input_vector: Vector2) -> void:
    if input_vector != Vector2.ZERO:
        animated_sprite.play("Run"); animated_sprite.flip_h = (input_vector.x < 0)
    else:
        animated_sprite.play("Idle")

func play_attack_animation(target_position: Vector2) -> void:
    is_attacking = true
    var direction = (target_position - global_position).normalized()
    animated_sprite.play(_get_attack_animation_name(direction))
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

func _on_animation_finished() -> void:
    var attack_anims = ["RightAttack", "DownRightAttack", "DownAttack", "UpAttack", "UpRightAttack"]
    if animated_sprite.animation in attack_anims: is_attacking = false

func collect_xp(amount: int) -> void:
    var total_gain = int(amount * xp_gain * GameManager.get_meta("xp_mult", 1.0))
    current_xp += total_gain
    if GameManager.has_method("log_event"): GameManager.log_event("xp", total_gain)
    while current_xp >= xp_to_next_level:
        current_xp -= xp_to_next_level; current_level += 1
        xp_to_next_level = int(xp_to_next_level * 1.2); level_up.emit(current_level)
        inventory_updated.emit()
    xp_changed.emit(current_xp, xp_to_next_level)

func spend_mass(amount: float) -> bool:
    if mass > (base_mass + 1.0):
        mass -= amount; _update_visual_scale(); return true
    return false

func collect_mass(amount: float) -> void:
    mass = clamp(mass + amount, base_mass, MAX_MASS); _update_visual_scale()

func _update_visual_scale() -> void:
    scale = scale.lerp(Vector2.ONE * (1.0 + ((mass / base_mass) - 1.0) * 0.7), 0.15)

func _on_death() -> void:
    GameManager.reset_game(); get_tree().reload_current_scene()
