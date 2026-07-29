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
@export var projectile_amount: int = 1

@export var max_health: float = 1000.0:
    set(value):
        max_health = value
        if is_node_ready() and is_instance_valid(health_component):
            health_component.update_max_health(max_health)

@export var radius_weapons: float = 1.0
@export var xp_radius: float = 1.0
@export var xp_gain: float = 20.0
@export var debug_give_aura_evolution: bool = false

# --- ИНВЕНТАРЬ И ТЕГИ ---
var max_weapon_slots: int = 3
var max_passive_slots: int = 3
var unlocked_weapon_slots: int = 2
var unlocked_passive_slots: int = 2
var active_weapons: Array[Upgrade] = []
var active_passives: Array[Upgrade] = []
var applied_upgrade_names: Array[String] = []
var tag_levels: Dictionary = {} # {"Spear": 5}
var _accumulated_weapon_bonuses: Dictionary = {}  # "max_attack_distance": 50.0

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

# War Banner inspired state (set externally by WarBanner weapon)
var banner_inspired: bool = false

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
    
    # Заполняем первый слот стартовым копьём
    var spear_upgrade = load("res://Upgrades/Weapons/Spear/BaseSpear.tres") as Upgrade
    if spear_upgrade:
        active_weapons.append(spear_upgrade)
        applied_upgrade_names.append(spear_upgrade.name)
        tag_levels["Spear"] = 1
    
    if debug_give_aura_evolution:
        call_deferred("_debug_add_aura_evolution")

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
    
    var debuff: float = 1.0
    if _disruptor_debuff_timer > 0:
        _disruptor_debuff_timer -= delta
        debuff = 0.4
        modulate = Color(0.7, 0.3, 1.0)
        if _disruptor_debuff_timer <= 0:
            # Restore based on active effects priority
            _update_modulate_from_state()
    elif banner_inspired:
        modulate = Color(1.0, 0.84, 0.0, 1.0)
    elif camp_buffs.get("speed", 0.0) != 0.0 or camp_buffs.get("damage", 0.0) != 0.0:
        modulate = Color(0.8, 0.8, 1.5, 1.0)
    else:
        modulate = Color.WHITE
    
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
    _update_modulate_from_state()

func remove_camp_buffs() -> void:
    camp_buffs = {"speed": 0.0, "damage": 0.0, "stability": 0.0, "regen": 0.0}
    _update_modulate_from_state()


func _update_modulate_from_state() -> void:
    # Priority: Disruptor > Banner Inspired > Camp Buffs > Normal
    if _disruptor_debuff_timer > 0:
        modulate = Color(0.7, 0.3, 1.0, 1.0)
    elif banner_inspired:
        modulate = Color(1.0, 0.84, 0.0, 1.0)
    elif camp_buffs.get("speed", 0.0) != 0.0 or camp_buffs.get("damage", 0.0) != 0.0:
        modulate = Color(0.8, 0.8, 1.5, 1.0)
    else:
        modulate = Color.WHITE

# --- ИНВЕНТАРЬ И УЛУЧШЕНИЯ ---

func apply_custom_upgrade(upgrade: Upgrade) -> void:
    # 1. Трекинг тегов и уровней
    var tag = upgrade.weapon_tag
    var pid = upgrade.passive_id
    
    # Track passive family levels
    if pid != "" and not upgrade.change_mechanic_on_apply:
        tag_levels[pid] = min(tag_levels.get(pid, 0) + 1, 8)
        # First pickup: create passive slot entry
        var exists = active_passives.any(func(u: Upgrade): return u.get("passive_id") == pid)
        if not exists:
            var new_entry = Upgrade.new()
            new_entry.passive_id = pid
            new_entry.name = pid
            active_passives.append(new_entry)
    
    # Track weapon levels separately
    if not upgrade.change_mechanic_on_apply and tag != "" and pid == "":
        tag_levels[tag] = min(tag_levels.get(tag, 0) + 1, 8)
    
    # 2. Регистрация в инвентаре и спавн сцены оружия
    if upgrade.is_weapon:
        var already_owned = active_weapons.any(func(u): return u.weapon_tag == tag)
        if not already_owned:
            active_weapons.append(upgrade)
            _spawn_weapon_scene(upgrade)
    elif pid == "" and (upgrade.weapon_tag == "" or upgrade.weapon_tag == "General") and not upgrade.is_global_modifier:
        var already_owned = active_passives.any(func(u): return u.name == upgrade.name)
        if not already_owned:
            active_passives.append(upgrade)
    # Модификаторы оружия/пассивок (weapon_tag != "" и не "General") — не добавляем в active_passives
            
    if not applied_upgrade_names.has(upgrade.name):
        applied_upgrade_names.append(upgrade.name)
    
    # 3. Эволюция — заменяет оружие и создаёт новую ветку прогрессии
    if upgrade.change_mechanic_on_apply and upgrade.evolved_weapon_scene != null:
        var evo_tag = upgrade.evolved_weapon_tag
        if evo_tag != "":
            # 3a. Удаляем старую запись из active_weapons (тег, который был до эволюции)
            active_weapons = active_weapons.filter(func(u): return u.weapon_tag != tag)
            # 3b. Добавляем новую запись с evolved тегом для поиска в UpgradeMenu
            var evo_entry = Upgrade.new()
            evo_entry.weapon_tag = evo_tag
            evo_entry.name = evo_tag + "_Base"
            evo_entry.is_weapon = true
            active_weapons.append(evo_entry)
            # 3c. Новая прогрессия с 1 уровня
            tag_levels[evo_tag] = 1
        apply_evolution(upgrade.target_weapon_name, upgrade.evolved_weapon_scene, evo_tag)
    
    # 4. Применение статов (Multi-Modifier Phase 1 — Dictionary format)
    if upgrade.modifiers.size() > 0:
        for modifier in upgrade.modifiers:
            var mod_stat: String = modifier.get("stat", "")
            var mod_amount: float = modifier.get("amount", 0.0)
            if mod_stat == "":
                continue
            print("[WEAPON INIT MOD] tag=", tag, " stat=", mod_stat, " amount=", mod_amount, " name=", upgrade.name, " (multi)")
            if mod_stat in self:
                set(mod_stat, get(mod_stat) + mod_amount)
                for child in get_children():
                    if child is BaseWeapon and child.has_method("on_modifier_applied"):
                        child.on_modifier_applied()
            else:
                _apply_upgrade_stat_to_weapons(tag, upgrade.target_weapon_name, mod_stat, mod_amount)
    else:
        # FALLBACK: старый single-stat для обратной совместимости
        var stat = upgrade.stat_to_modify
        print("[WEAPON INIT MOD] tag=", tag, " stat=", stat, " amount=", upgrade.amount, " name=", upgrade.name, " (legacy)")
        if stat != "":
            if stat in self:
                set(stat, get(stat) + upgrade.amount)
                for child in get_children():
                    if child is BaseWeapon and child.has_method("on_modifier_applied"):
                        child.on_modifier_applied()
            else:
                _apply_upgrade_stat_to_weapons(tag, upgrade.target_weapon_name, stat, upgrade.amount)


func _apply_upgrade_stat_to_weapons(tag: String, target_name: String, stat: String, amount: float) -> void:
    var weapons: Array[Node] = []
    for child in get_children():
        if child is BaseWeapon:
            weapons.append(child)
    var matched = false
    for w in weapons:
        if w.get("weapon_tag") == tag or w.get("weapon_name") == tag or w.get("weapon_name") == target_name:
            matched = true
            _apply_stat_to_weapon(w, stat, amount)
            if w.has_method("on_modifier_applied"):
                w.on_modifier_applied()
    if not matched:
        _accumulated_weapon_bonuses[stat] = _accumulated_weapon_bonuses.get(stat, 0.0) + amount
        for w in weapons:
            _apply_stat_to_weapon(w, stat, amount)
            if w.has_method("on_modifier_applied"):
                w.on_modifier_applied()


func _apply_stat_to_weapon(w: Node, stat: String, amount: float) -> void:
    print("[UPGRADE TRACE] weapon=", w.weapon_tag if "weapon_tag" in w else w.name, " stat=", stat, " amount=", amount)
    match stat:
        "base_damage":
            w.weapon_dmg_bonus += amount
        "max_attack_distance":
            w.weapon_range_bonus += amount
        "pierce_limit":
            w.weapon_pierce_bonus += int(amount)
        _:
            if stat in w:
                var current = w.get(stat)
                if current is int:
                    w.set(stat, current + int(amount))
                else:
                    w.set(stat, current + amount)
    inventory_updated.emit()


func _debug_add_aura_evolution() -> void:
    # Прямой спавн EvolvedAuraWave без нормальной Aura
    var evo_scene = load("res://Assets/Scenes/EvolvedAuraWave.tscn") as PackedScene
    if not evo_scene:
        return
    var evolved = evo_scene.instantiate()
    evolved.weapon_tag = "Aura_Evolved"
    add_child(evolved)
    move_child(evolved, 0)
    # Добавляем в active_weapons эволюционную запись
    var evo_weapon_entry = Upgrade.new()
    evo_weapon_entry.weapon_tag = "Aura_Evolved"
    evo_weapon_entry.is_weapon = true
    active_weapons.append(evo_weapon_entry)
    tag_levels["Aura_Evolved"] = 1
    # Добавляем AttackRange пассивку (для совместимости)
    var range_entry = Upgrade.new()
    range_entry.name = "AttackRange"
    range_entry.passive_id = "AttackRange"
    active_passives.append(range_entry)

func _spawn_weapon_scene(upgrade: Upgrade) -> void:
    # Загружаем сцену из Assets/Scenes/{weapon_tag}Weapon.tscn
    var scene_path = "res://Assets/Scenes/Weapons/" + upgrade.weapon_tag + "Weapon.tscn"
    var weapon_scene = load(scene_path) as PackedScene
    if not weapon_scene:
        push_warning("No weapon scene found at: " + scene_path)
        return
    var new_weapon = weapon_scene.instantiate()
    # Устанавливаем weapon_tag из ресурса Upgrade
    new_weapon.weapon_tag = upgrade.weapon_tag
    # Сдвигаем позицию, чтобы оружия не накладывались друг на друга
    var offset = active_weapons.size() * 20
    new_weapon.position = Vector2(offset, -offset)
    add_child(new_weapon)
    # Перемещаем BaseWeapon в начало списка детей Player,
    # чтобы визуал (Aura, Spear) был ПОД AnimatedSprite2D персонажа
    move_child(new_weapon, 0)
    # Применяем накопленные пассивные/глобальные бонусы к новому оружию
    for bonus_stat in _accumulated_weapon_bonuses:
        _apply_stat_to_weapon(new_weapon, bonus_stat, _accumulated_weapon_bonuses[bonus_stat])
    if new_weapon.has_method("on_modifier_applied"):
        new_weapon.on_modifier_applied()
    

func apply_evolution(weapon_name: String, evolved_scene: PackedScene, evolved_tag: String = "") -> void:
    var old_pos = Vector2.ZERO
    for child in get_children():
        if child is BaseWeapon and child.get("weapon_name") == weapon_name:
            old_pos = child.position
            child.queue_free()
            break
    var new_weapon = evolved_scene.instantiate()
    new_weapon.position = old_pos
    if evolved_tag != "":
        new_weapon.weapon_tag = evolved_tag
    add_child(new_weapon)
    # Evolved weapons start fresh — no inheritance of old weapon upgrades
    # Only global passives (radius_weapons, damage_multiplier) apply via _setup_physics_auto
    if new_weapon.has_method("on_modifier_applied"):
        new_weapon.on_modifier_applied()
    _play_evolution_fx()

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
    var weapons: Array[Node] = []
    for child in get_children():
        if child is BaseWeapon:
            weapons.append(child)
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
    call_deferred("_deferred_restart")

func _deferred_restart() -> void:
    GameManager.reset_game()
    if is_inside_tree():
        get_tree().reload_current_scene()
