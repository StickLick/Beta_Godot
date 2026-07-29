class_name WarBanner
extends BaseWeapon

# ── Signals ──
signal war_cry_triggered(is_active: bool)
signal inspired_changed(is_inspired: bool)

# ── Unit & Banner Deployment ──
@export var max_banner_units: int = 2
@export var banner_duration: float = 8.0
@export var spawn_range: float = 80.0

# ── War Cry Buff System ──
@export var war_cry_interval: float = 10.0
@export var inspired_duration: float = 5.0
@export var inspired_regen_bonus: float = 5.0       # HP/sec while inspired
@export var inspired_damage_mult: float = 1.3        # 30% bonus damage

const UNIT_SCENE: PackedScene = preload("res://Assets/Scenes/Unit.tscn")
const BANNER_ZONE_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/BannerZone.tscn")

var _banner_units: Array[Unit] = []
var _active_banner: BannerZone = null
var _has_deployed_banner: bool = false

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


func _animate_banner_sprite(delta: float) -> void:
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

func _on_cooldown_timeout() -> void:
    if not is_instance_valid(player):
        cooldown_timer.start(0.5)
        return
    
    _banner_units = _banner_units.filter(func(u: Unit): return is_instance_valid(u))
    
    if not _has_deployed_banner and _banner_units.size() < max_banner_units:
        _spawn_banner_unit()
        cooldown_timer.start(attack_cooldown)
    elif not _has_deployed_banner:
        _deploy_banner()
        cooldown_timer.start(attack_cooldown + banner_duration)
    else:
        for _i in range(max_banner_units - _banner_units.size()):
            _spawn_banner_unit()
        cooldown_timer.start(attack_cooldown)


func _spawn_banner_unit() -> void:
    if not UNIT_SCENE:
        return
    
    var unit: Unit = UNIT_SCENE.instantiate() as Unit
    if not unit:
        return
    
    var root: Node = get_tree().current_scene
    root.add_child(unit)
    
    unit.global_position = player.global_position + Vector2.from_angle(randf() * TAU) * spawn_range
    unit.alignment = 1
    unit.banner_owner = self
    unit.guard_target = player
    
    if not war_cry_triggered.is_connected(unit._on_war_cry):
        war_cry_triggered.connect(unit._on_war_cry)
    
    if is_inspired_active:
        unit._on_war_cry(true)
    
    _banner_units.append(unit)


func _deploy_banner() -> void:
    if not BANNER_ZONE_SCENE or not is_instance_valid(player):
        return
    
    var banner: BannerZone = BANNER_ZONE_SCENE.instantiate() as BannerZone
    if not banner:
        return
    
    var root: Node = get_tree().current_scene
    root.add_child(banner)
    banner.global_position = player.global_position
    banner.banner_owner = self
    banner.duration = banner_duration
    
    _active_banner = banner
    _has_deployed_banner = true
    
    for unit: Unit in _banner_units:
        if is_instance_valid(unit):
            unit.guard_target = banner


func _on_banner_unit_died(unit: Unit) -> void:
    _banner_units.erase(unit)
    
    if war_cry_triggered.is_connected(unit._on_war_cry):
        war_cry_triggered.disconnect(unit._on_war_cry)


func _on_banner_zone_expired() -> void:
    _active_banner = null
    _has_deployed_banner = false
    
    for unit: Unit in _banner_units:
        if is_instance_valid(unit):
            unit.guard_target = player
