class_name StarShardBase
extends Area2D

# -- Emerald Vortex: 2-Phase State Machine --
# PHASE 1 (TRAVEL): Fly to target_pos, no early detonation
# PHASE 2 (ORBIT): Stationary core, orbiting shards deal AOE damage
# Lifetime: 5.0s total, then full cleanup

enum Phase { TRAVEL, ORBIT }

const EMERALD_GREEN = Color(0.0, 1.0, 0.5, 1.0)
const NEON_MINT = Color(0.2, 1.0, 0.7, 0.9)
const DEEP_EMERALD = Color(0.0, 0.6, 0.3, 0.8)

@export var speed: float = 1200.0
@export var damage: float = 30.0
@export var orbit_radius: float = 90.0
@export var shard_count: int = 8
@export var orbit_duration: float = 3.5
@export var rotation_speed: float = 180.0

const SHARD_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/ArcaneBolt.tscn")

var direction: Vector2 = Vector2.RIGHT
var target_pos: Vector2 = Vector2.ZERO
var faction: String = "player"
var _current_phase: Phase = Phase.TRAVEL
var _orbit_timer: float = 0.0
var _lifetime_timer: float = 0.0

var _vortex_shards: Array[ArcaneBolt] = []
var _vortex_angle: float = 0.0
var _star_core: Node2D = null
var _damage_cooldowns: Dictionary = {}  # enemy -> last damage time

# Visual: flight trail
var _nucleus: Sprite2D = null
var _trail_points: Array[Vector2] = []
var _trail_line: Line2D = null


func _ready() -> void:
    collision_layer = 0
    collision_mask = 12
    _spawn_nucleus()


func _physics_process(delta: float) -> void:
    _lifetime_timer += delta
    if _lifetime_timer >= 5.0:
        _cleanup_all()
        return
    match _current_phase:
        Phase.TRAVEL:
            _phase_travel(delta)
        Phase.ORBIT:
            _phase_orbit(delta)


func _phase_travel(delta: float) -> void:
    position += direction * speed * delta
    _update_trail()
    if target_pos != Vector2.ZERO and global_position.distance_to(target_pos) < 15.0:
        _enter_orbit_phase()


func _enter_orbit_phase() -> void:
    # Remove flight visuals
    if is_instance_valid(_nucleus):
        _nucleus.queue_free()
        _nucleus = null
    if is_instance_valid(_trail_line):
        _trail_line.queue_free()
        _trail_line = null
    
    _current_phase = Phase.ORBIT
    _orbit_timer = 0.0
    direction = Vector2.ZERO
    _spawn_emerald_core()
    _spawn_vortex_shards()


# ── Flight Nucleus + Trail ──
func _spawn_nucleus() -> void:
    _nucleus = Sprite2D.new()
    _nucleus.name = "Nucleus"
    _nucleus.texture = _create_radial_texture(16, EMERALD_GREEN)
    _nucleus.scale = Vector2.ONE * 0.8
    _nucleus.modulate = EMERALD_GREEN
    _nucleus.z_index = 9
    add_child(_nucleus)
    
    _trail_line = Line2D.new()
    _trail_line.name = "Trail"
    _trail_line.width = 2.0
    _trail_line.default_color = EMERALD_GREEN
    _trail_line.z_index = 5
    get_tree().current_scene.add_child(_trail_line)


func _update_trail() -> void:
    if not is_instance_valid(_trail_line):
        return
    _trail_points.append(global_position)
    if _trail_points.size() > 6:
        _trail_points.pop_front()
    _trail_line.points = PackedVector2Array(_trail_points)


func _phase_orbit(delta: float) -> void:
    _orbit_timer += delta
    if is_instance_valid(_star_core):
        var pulse = 1.0 + sin(_orbit_timer * 8.0) * 0.15
        _star_core.scale = Vector2.ONE * pulse * 1.3
        _star_core.modulate.a = 0.6 + sin(_orbit_timer * 12.0) * 0.2
    _vortex_angle += rotation_speed * delta
    if _vortex_angle > 360.0:
        _vortex_angle -= 360.0
    _update_vortex_positions()
    _orbit_damage_pulse()


func _orbit_damage_pulse() -> void:
    for shard in _vortex_shards:
        if not is_instance_valid(shard):
            continue
        var space_state = get_world_2d().direct_space_state
        if space_state == null:
            continue
        var query = PhysicsShapeQueryParameters2D.new()
        var circle = CircleShape2D.new()
        circle.radius = 22.0
        query.shape = circle
        query.transform = Transform2D(0, shard.global_position)
        query.collision_mask = 12
        query.collide_with_areas = true
        query.collide_with_bodies = false
        var results = space_state.intersect_shape(query)
        for result in results:
            var collider = result.collider
            var cf = collider.get("faction") if "faction" in collider else null
            if cf != null and str(cf).to_lower() == faction.to_lower():
                continue
            if collider.has_method("_apply_damage"):
                # Damage cooldown: 0.3s between hits per enemy
                var enemy_id = collider.get_instance_id()
                var now = Time.get_ticks_msec() / 1000.0
                var last = _damage_cooldowns.get(enemy_id, -1.0)
                if now - last >= 0.3:
                    collider._apply_damage(damage * 0.2)
                    _damage_cooldowns[enemy_id] = now


func _spawn_emerald_core() -> void:
    _star_core = Node2D.new()
    _star_core.name = "EmeraldCore"
    _star_core.global_position = global_position
    _star_core.z_index = 10
    get_tree().current_scene.add_child(_star_core)
    var core_sprite = Sprite2D.new()
    core_sprite.name = "CoreGlow"
    core_sprite.texture = _create_radial_texture(32, EMERALD_GREEN)
    core_sprite.scale = Vector2.ONE * 0.5
    core_sprite.modulate = EMERALD_GREEN
    _star_core.add_child(core_sprite)
    var halo_sprite = Sprite2D.new()
    halo_sprite.name = "Halo"
    halo_sprite.texture = _create_radial_texture(64, NEON_MINT)
    halo_sprite.scale = Vector2.ONE * 1.4
    halo_sprite.modulate = NEON_MINT
    _star_core.add_child(halo_sprite)
    var ring = Sprite2D.new()
    ring.name = "Ring"
    ring.texture = _create_ring_texture(128, DEEP_EMERALD)
    ring.scale = Vector2.ZERO
    ring.modulate = EMERALD_GREEN
    _star_core.add_child(ring)
    var tw = _star_core.create_tween().set_loops()
    tw.tween_property(ring, "scale", Vector2.ONE * 2.0, 1.0)
    tw.tween_property(ring, "modulate:a", 0.0, 1.0)
    tw.tween_callback(func(): ring.scale = Vector2.ZERO; ring.modulate.a = 0.8)
    var light = PointLight2D.new() if ClassDB.class_exists("PointLight2D") else null
    if light:
        light.name = "Light"
        light.texture = _create_radial_texture(64, Color.WHITE)
        light.energy = 1.2
        light.color = EMERALD_GREEN
        light.z_index = 5
        _star_core.add_child(light)


func _create_radial_texture(size: int, color: Color) -> ImageTexture:
    var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
    var center = Vector2(size, size) / 2.0
    var max_dist = size / 2.0
    for x in range(size):
        for y in range(size):
            var dist = Vector2(x + 0.5, y + 0.5).distance_to(center)
            var alpha = clamp(1.0 - dist / max_dist, 0.0, 1.0)
            alpha = ease(alpha, 2.0)
            img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
    return ImageTexture.create_from_image(img)


func _create_ring_texture(size: int, color: Color) -> ImageTexture:
    var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
    var center = Vector2(size, size) / 2.0
    var radius = size / 2.0
    var thickness = 8.0
    for x in range(size):
        for y in range(size):
            var d = Vector2(x + 0.5, y + 0.5).distance_to(center)
            var ring_dist = abs(d - radius * 0.8)
            var alpha = clamp(1.0 - ring_dist / thickness, 0.0, 1.0)
            img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
    return ImageTexture.create_from_image(img)


func _spawn_vortex_shards() -> void:
    _vortex_shards.clear()
    _vortex_angle = 0.0
    for i in range(shard_count):
        var shard = SHARD_SCENE.instantiate() as ArcaneBolt
        if not shard:
            continue
        get_tree().current_scene.add_child(shard)
        shard.global_position = global_position
        shard.direction = Vector2.RIGHT
        shard.damage = damage * 0.4
        shard.speed = 0.0
        shard.steering_strength = 0.0
        shard.modulate = EMERALD_GREEN
        shard.scale = Vector2.ONE * 1.0
        shard.set_meta("vortex_index", i)
        shard.set_meta("vortex_center", self)
        _vortex_shards.append(shard)


func _update_vortex_positions() -> void:
    for i in range(_vortex_shards.size()):
        var shard = _vortex_shards[i]
        if not is_instance_valid(shard):
            continue
        var angle = deg_to_rad(_vortex_angle + (360.0 / shard_count) * i)
        # Perfect circular orbit — no lerp, no weave, no jitter
        shard.global_position = global_position + Vector2(cos(angle), sin(angle)) * orbit_radius
        shard.rotation = angle + PI / 2.0
        shard.modulate = EMERALD_GREEN


func _cleanup_all() -> void:
    for shard in _vortex_shards:
        if is_instance_valid(shard):
            shard.queue_free()
    _vortex_shards.clear()
    if is_instance_valid(_star_core):
        _star_core.queue_free()
        _star_core = null
    queue_free()
