class_name WarBanner
extends BaseWeapon

# ── Signals ──
signal war_cry_triggered(is_active: bool)
signal inspired_changed(is_inspired: bool)

# ── Unit Spawning ──
@export var max_banner_units: int = 2
@export var spawn_range: float = 80.0

# ── War Cry Buff System ──
@export var war_cry_interval: float = 10.0
@export var inspired_duration: float = 5.0
@export var inspired_regen_bonus: float = 5.0       # HP/sec while inspired
@export var inspired_damage_mult: float = 1.3        # 30% bonus damage

const UNIT_SCENE: PackedScene = preload("res://Assets/Scenes/Pawn.tscn")

# Speed scaling constants
const PLAYER_BASE_SPEED: float = 250.0
const UNIT_BASE_SPEED: float = 240.0

# Health scaling constants
const PLAYER_BASE_HP: float = 1000.0
const BASE_UNIT_HP: float = 30.0

# War Cry radius (scales with weapon final_range via apply_player_stats_to_units)
var war_cry_radius: float = 250.0

var _banner_units: Array[Unit] = []
var _pawn_targets: Dictionary = {}      # int pawn_id → int target_id
var _formation_offsets: Dictionary = {} # int pawn_id → Vector2 formation offset
var _commander_timer: float = 0.0

const COMMANDER_SCAN_INTERVAL: float = 0.2
const MAX_LEASH_DISTANCE: float = 400.0
const MAX_PAWNS_PER_ENEMY: int = 2
const MAX_PAWNS_PER_BOSS: int = 4

# ── War Cry State ──
var war_cry_timer: float = 0.0
var inspired_timer: float = 0.0
var is_inspired_active: bool = false

# ── Banner Visual ──
var banner_sprite: Sprite2D = null


# ═══════════════════════════════════════════════════════════════
# WEAPON LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)
    
    # War Cry starts its cycle
    war_cry_timer = war_cry_interval * 0.5  # First cry at half interval
    
    # Create banner visual
    _create_banner_sprite()


func _weapon_process(delta: float) -> void:
    _process_war_cry(delta)
    _animate_banner_sprite(delta)
    _update_commander(delta)


# ═══════════════════════════════════════════════════════════════
# STAT SCALING (links unit speed to player MoveSpeed passives)
# ═══════════════════════════════════════════════════════════════

func on_modifier_applied() -> void:
    super.on_modifier_applied()
    apply_player_stats_to_units()
    reconcile_pawn_count()


func apply_player_stats_to_units() -> void:
    if not is_instance_valid(player):
        return
    
    var speed_mult: float = player.max_speed / PLAYER_BASE_SPEED
    var hp_mult: float   = player.max_health / PLAYER_BASE_HP
    var dmg: float       = final_damage  # SSOT getter from BaseWeapon
    
    for unit: Unit in _banner_units:
        if not is_instance_valid(unit):
            continue
        
        unit.speed  = UNIT_BASE_SPEED * speed_mult
        unit.max_hp = BASE_UNIT_HP * hp_mult
        
        if is_instance_valid(unit.health_component):
            unit.health_component.max_health = unit.max_hp
            unit.health_component.current_health = minf(
                unit.health_component.current_health, unit.max_hp
            )
        
        if is_instance_valid(unit.hitbox):
            unit.hitbox.damage = dmg
    
    war_cry_radius = final_range
    
    print("[SYNC] Banner | Dmg: %.1f | Units: %d" % [dmg, _banner_units.size()])


# ═══════════════════════════════════════════════════════════════
# BANNER VISUAL (Standard-Bearer)
# ═══════════════════════════════════════════════════════════════

func _create_banner_sprite() -> void:
    banner_sprite = Sprite2D.new()
    banner_sprite.name = "BannerSprite"
    banner_sprite.position = Vector2(0, -48)
    banner_sprite.z_index = 10
    banner_sprite.scale = Vector2(2, 2)
    banner_sprite.centered = true
    
    banner_sprite.texture = _create_banner_texture()
    
    if is_instance_valid(visual_pivot):
        visual_pivot.add_child(banner_sprite)


func _create_banner_texture() -> ImageTexture:
    var size: int = 32
    var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
    var half: float = size / 2.0
    
    for x in range(size):
        for y in range(size):
            var px: float = float(x) + 0.5
            var py: float = float(y) + 0.5
            
            # Banner pole (vertical line in left-center)
            var pole_dist: float = abs(px - half * 0.3)
            var pole_top: float = size * 0.1
            var pole_bottom: float = size * 0.85
            
            if pole_dist < 2.0 and py > pole_top and py < pole_bottom:
                img.set_pixel(x, y, Color(0.55, 0.35, 0.15, 1.0))
                continue
            
            # Banner cloth (flag to the right of pole, top portion)
            var cloth_left: float = half * 0.3 + 3.0
            var cloth_right: float = size * 0.9
            var cloth_top: float = pole_top + 2.0
            var cloth_bottom: float = half * 0.6
            
            if px >= cloth_left and px <= cloth_right and py >= cloth_top and py <= cloth_bottom:
                var edge_top: float = cloth_top + (py - cloth_top) * 0.3
                var edge_bottom: float = cloth_bottom - (cloth_bottom - py) * 0.3
                if py >= edge_top and py <= edge_bottom:
                    img.set_pixel(x, y, Color(0.15, 0.45, 0.85, 0.95))
                    continue
            
            # Banner tip (small triangle at the right edge)
            var tip_center_y: float = (cloth_top + cloth_bottom) / 2.0
            var tip_dist: float = abs(py - tip_center_y)
            if px > cloth_right - 6.0 and px <= cloth_right and tip_dist < (px - cloth_right + 6.0) * 1.5:
                img.set_pixel(x, y, Color(0.1, 0.35, 0.7, 0.9))
                continue
            
            img.set_pixel(x, y, Color(0, 0, 0, 0))
    
    return ImageTexture.create_from_image(img)


func _animate_banner_sprite(_delta: float) -> void:
    if not is_instance_valid(banner_sprite):
        return
    
    var t: float = Time.get_ticks_msec() / 1000.0
    banner_sprite.rotation = sin(t * 2.0) * 0.06
    banner_sprite.position.y = -48.0 + sin(t * 1.5) * 3.0
    
    if is_inspired_active:
        banner_sprite.rotation = sin(t * 4.0) * 0.12
        banner_sprite.position.y = -48.0 + sin(t * 3.0) * 5.0
        banner_sprite.modulate = Color(1.0, 0.9, 0.2, 1.0)
    else:
        banner_sprite.modulate = Color.WHITE


# ═══════════════════════════════════════════════════════════════
# WAR CRY BUFF SYSTEM
# ═══════════════════════════════════════════════════════════════

func _process_war_cry(delta: float) -> void:
    if not is_instance_valid(player):
        return
    
    if not is_inspired_active:
        war_cry_timer += delta
        if war_cry_timer >= war_cry_interval:
            _activate_war_cry()
    else:
        inspired_timer -= delta
        if inspired_timer <= 0.0:
            _deactivate_war_cry()


func _activate_war_cry() -> void:
    is_inspired_active = true
    inspired_timer = inspired_duration
    war_cry_timer = 0.0
    
    _apply_inspired_buffs_to_player()
    
    war_cry_triggered.emit(true)
    inspired_changed.emit(true)
    
    print("[WAR CRY] Inspired! +", inspired_regen_bonus, "HP/s, +", int((inspired_damage_mult - 1.0) * 100), "% damage for ", inspired_duration, "s")


func _deactivate_war_cry() -> void:
    is_inspired_active = false
    inspired_timer = 0.0
    
    _remove_inspired_buffs_from_player()
    
    war_cry_triggered.emit(false)
    inspired_changed.emit(false)
    
    print("[WAR CRY] Inspired ended. Next cry in ", war_cry_interval, "s")


func _apply_inspired_buffs_to_player() -> void:
    if not is_instance_valid(player):
        return
    
    player.banner_inspired = true
    player.health_regen += inspired_regen_bonus
    player.damage_multiplier *= inspired_damage_mult


func _remove_inspired_buffs_from_player() -> void:
    if not is_instance_valid(player):
        return
    
    player.banner_inspired = false
    player.health_regen -= inspired_regen_bonus
    player.damage_multiplier /= inspired_damage_mult
    
    # Let player's own priority system handle modulate restoration
    if player.has_method("_update_modulate_from_state"):
        player._update_modulate_from_state()


# ═══════════════════════════════════════════════════════════════
# UNIT SPAWN / DEPLOY CYCLE
# ═══════════════════════════════════════════════════════════════


func reconcile_pawn_count() -> void:
    _banner_units = _banner_units.filter(func(u: Unit): return is_instance_valid(u))
    var final_max: int = max_banner_units + max(0, (player.projectile_amount - 1)) if is_instance_valid(player) else max_banner_units
    while _banner_units.size() < final_max:
        _spawn_banner_unit()


func _on_cooldown_timeout() -> void:
    if not is_instance_valid(player):
        cooldown_timer.start(0.5)
        return
    
    reconcile_pawn_count()
    cooldown_timer.start(attack_cooldown)


func _spawn_banner_unit() -> void:
    if not UNIT_SCENE:
        return
    
    var unit: Unit = UNIT_SCENE.instantiate() as Unit
    if not unit:
        return
    
    # Set ALL properties BEFORE add_child() so _ready() sees them
    var idx: int = _banner_units.size()
    var offset_angle: float = idx * TAU / max_banner_units + randf_range(-0.3, 0.3)
    var offset_dist: float = randf_range(60.0, 100.0)
    var offset: Vector2 = Vector2.from_angle(offset_angle) * offset_dist
    _formation_offsets[unit.get_instance_id()] = offset
    
    unit.banner_owner = self
    unit.alignment = 1
    unit.guard_target = player
    unit.global_position = player.global_position + offset
    
    var root: Node = get_tree().current_scene
    root.add_child(unit)
    
    if not war_cry_triggered.is_connected(unit._on_war_cry):
        war_cry_triggered.connect(unit._on_war_cry)
    
    if is_inspired_active:
        unit._on_war_cry(true)
    
    _banner_units.append(unit)
    
    apply_player_stats_to_units()


func _on_banner_unit_died(unit: Unit) -> void:
    var unit_id: int = unit.get_instance_id()
    _banner_units.erase(unit)
    _pawn_targets.erase(unit_id)
    _formation_offsets.erase(unit_id)

    if war_cry_triggered.is_connected(unit._on_war_cry):
        war_cry_triggered.disconnect(unit._on_war_cry)


# ═══════════════════════════════════════════════════════════════
# COMMANDER LOGIC
# ═══════════════════════════════════════════════════════════════

func _update_commander(delta: float) -> void:
    if not is_instance_valid(player):
        return
    
    _commander_timer += delta
    if _commander_timer < COMMANDER_SCAN_INTERVAL:
        return
    _commander_timer = 0.0
    
    _clean_dead_assignments()
    _assign_targets()


func _clean_dead_assignments() -> void:
    var safe_targets: Dictionary = {}
    for p_id: int in _pawn_targets.keys():
        var pawn_instance: Node = instance_from_id(p_id) as Node
        if not is_instance_valid(pawn_instance) or pawn_instance.is_queued_for_deletion():
            continue
        var t_id: int = _pawn_targets[p_id]
        var target_instance: Node = instance_from_id(t_id) as Node
        if not is_instance_valid(target_instance) or target_instance.is_queued_for_deletion():
            var pawn_unit: Unit = pawn_instance as Unit
            if pawn_unit:
                pawn_unit.target = null
                pawn_unit.is_attacking = false
            continue
        safe_targets[p_id] = t_id
    _pawn_targets = safe_targets

    var safe_offsets: Dictionary = {}
    for p_id: int in _formation_offsets.keys():
        var pawn_instance: Node = instance_from_id(p_id) as Node
        if is_instance_valid(pawn_instance) and not pawn_instance.is_queued_for_deletion():
            safe_offsets[p_id] = _formation_offsets[p_id]
    _formation_offsets = safe_offsets

    _banner_units = _banner_units.filter(func(u: Unit): return is_instance_valid(u) and not u.is_queued_for_deletion())


func _assign_targets() -> void:
    var free_pawns: Array[Unit] = []
    for pawn: Unit in _banner_units:
        if not is_instance_valid(pawn):
            continue
        var p_id: int = pawn.get_instance_id()
        if not _pawn_targets.has(p_id) or not is_instance_valid(instance_from_id(_pawn_targets[p_id])):
            free_pawns.append(pawn)
            pawn.target = null

    if free_pawns.is_empty():
        return

    var enemies_near_player: Array[Node2D] = _get_enemies_near_player()

    for enemy: Node2D in enemies_near_player:
        if not is_instance_valid(enemy):
            continue
        var enemy_id: int = enemy.get_instance_id()
        var current_attackers: int = 0
        for t_id: int in _pawn_targets.values():
            if t_id == enemy_id:
                current_attackers += 1
        var max_allowed: int = MAX_PAWNS_PER_BOSS if enemy.get_meta("is_boss", false) else MAX_PAWNS_PER_ENEMY
        var slots_available: int = max_allowed - current_attackers
        while slots_available > 0 and not free_pawns.is_empty():
            var pawn: Unit = free_pawns.pop_front()
            pawn.target = enemy
            _pawn_targets[pawn.get_instance_id()] = enemy_id
            slots_available -= 1


func _get_enemies_near_player() -> Array[Node2D]:
    var result: Array[Node2D] = []
    var enemies: Array = get_tree().get_nodes_in_group("enemy")
    for e in enemies:
        if not is_instance_valid(e):
            continue
        if e.global_position.distance_to(player.global_position) <= MAX_LEASH_DISTANCE:
            result.append(e)
    result.sort_custom(func(a, b): return _dist_to_player_sq(a) < _dist_to_player_sq(b))
    return result


func _dist_to_player_sq(node: Node2D) -> float:
    return node.global_position.distance_squared_to(player.global_position)


func get_pawn_target(pawn: Unit) -> Node2D:
    var t_id: int = _pawn_targets.get(pawn.get_instance_id(), -1)
    if t_id == -1:
        return null
    return instance_from_id(t_id) as Node2D


func get_formation_offset(pawn: Unit) -> Vector2:
    return _formation_offsets.get(pawn.get_instance_id(), Vector2(80, 0))
