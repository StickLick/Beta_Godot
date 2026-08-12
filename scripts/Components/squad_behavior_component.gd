extends Node2D

enum State { IDLE_FOLLOW, COMBAT }

const FLEE_SPEED_MULT: float = 0.7

var parent_unit: Unit
var current_state: State = State.IDLE_FOLLOW

@export var attack_range: float = 80.0

var player: Node2D = null
var banner: WarBanner = null
var _attack_pulse_timer: float = 0.0


func _ready() -> void:
    parent_unit = get_parent() as Unit
    if not is_instance_valid(parent_unit):
        return
    player = parent_unit.get_tree().get_first_node_in_group("player")
    if is_instance_valid(parent_unit.banner_owner) and parent_unit.banner_owner is WarBanner:
        banner = parent_unit.banner_owner as WarBanner


func _physics_process(delta: float) -> void:
    if not is_instance_valid(parent_unit) or parent_unit.is_queued_for_deletion():
        return
    if not is_instance_valid(player):
        player = parent_unit.get_tree().get_first_node_in_group("player")
    var banner_owner = parent_unit.banner_owner
    if not is_instance_valid(banner_owner) or banner_owner.is_queued_for_deletion():
        return
    if not is_instance_valid(banner) and is_instance_valid(banner_owner):
        if banner_owner is WarBanner:
            banner = banner_owner as WarBanner
    if not is_instance_valid(player):
        return

    if Engine.get_physics_frames() % 60 == 0:
        print("[DEBUG] Pawn State: ", current_state)

    _update_state()

    match current_state:
        State.IDLE_FOLLOW:
            _idle_follow(delta)
        State.COMBAT:
            _combat(delta)


func _update_state() -> void:
    if not is_instance_valid(banner):
        current_state = State.IDLE_FOLLOW
        return

    var assigned_target: Node2D = banner.get_pawn_target(parent_unit)

    if is_instance_valid(assigned_target) and _in_leash(assigned_target):
        current_state = State.COMBAT
    else:
        current_state = State.IDLE_FOLLOW
        if is_instance_valid(parent_unit):
            parent_unit.target = null
            parent_unit.is_attacking = false
            if is_instance_valid(banner) and banner.has_method("release_pawn_target"):
                banner.release_pawn_target(parent_unit)


func _in_leash(target: Node2D) -> bool:
    if not is_instance_valid(player) or not is_instance_valid(target):
        return false
    var max_dist: float = banner.MAX_LEASH_DISTANCE if is_instance_valid(banner) else 400.0
    return player.global_position.distance_to(target.global_position) <= max_dist


func _idle_follow(delta: float) -> void:
    var offset: Vector2 = banner.get_formation_offset(parent_unit) if is_instance_valid(banner) else Vector2(80, 0)
    var target_pos: Vector2 = player.global_position + offset
    var dist: float = parent_unit.global_position.distance_to(target_pos)

    if dist < 10.0:
        parent_unit.velocity = parent_unit.velocity.lerp(Vector2.ZERO, delta * 10.0)
        if not parent_unit.is_attacking and is_instance_valid(parent_unit.animated_sprite) and parent_unit.animated_sprite.animation != "Idle":
            parent_unit.animated_sprite.play("Idle")
    else:
        var dir: Vector2 = (target_pos - parent_unit.global_position).normalized()
        var speed_mult: float = min(parent_unit._get_elastic_speed_mult(dist), 1.0)
        var desired: Vector2 = dir * parent_unit.speed * speed_mult
        parent_unit.velocity = parent_unit.velocity.lerp(desired, delta * 8.0)
        if is_instance_valid(parent_unit.animated_sprite):
            if parent_unit.animated_sprite.animation != "Run":
                parent_unit.animated_sprite.play("Run")
            if dir.x != 0:
                parent_unit.animated_sprite.flip_h = dir.x < 0

    parent_unit.move_and_slide()


func _combat(delta: float) -> void:
    var assigned_target: Node2D = null
    if is_instance_valid(banner) and is_instance_valid(parent_unit):
        assigned_target = banner.get_pawn_target(parent_unit)
    if not is_instance_valid(assigned_target):
        current_state = State.IDLE_FOLLOW
        return

    if not _in_leash(assigned_target):
        current_state = State.IDLE_FOLLOW
        return

    var enemy_dist: float = parent_unit.global_position.distance_to(assigned_target.global_position)
    var dir: Vector2 = (assigned_target.global_position - parent_unit.global_position).normalized()
    var separation: Vector2 = parent_unit._get_separation_velocity()

    if parent_unit.is_ranged:
        if enemy_dist <= parent_unit.attack_range:
            if enemy_dist < parent_unit.comfort_distance:
                var flee_dir = -dir
                var offset: Vector2 = banner.get_formation_offset(parent_unit) if is_instance_valid(banner) else Vector2(80, 0)
                var formation_pos: Vector2 = player.global_position + offset
                var dist_to_formation: float = parent_unit.global_position.distance_to(formation_pos)
                if dist_to_formation > 280.0:
                    var pull_dir: Vector2 = (formation_pos - parent_unit.global_position).normalized()
                    var t: float = clamp((dist_to_formation - 280.0) / 120.0, 0.0, 0.7)
                    flee_dir = (flee_dir.lerp(pull_dir, t)).normalized()
                var desired: Vector2 = (flee_dir * parent_unit.speed * FLEE_SPEED_MULT + separation).normalized() * parent_unit.speed * FLEE_SPEED_MULT
                parent_unit.velocity = parent_unit.velocity.lerp(desired, delta * 8.0)
            else:
                parent_unit.velocity = parent_unit.velocity.lerp(separation * 0.5, delta * 8.0)
            if is_instance_valid(parent_unit.animated_sprite) and dir.x != 0:
                parent_unit.animated_sprite.flip_h = dir.x < 0
            if not parent_unit.is_attacking:
                parent_unit._play_sequential_attack(assigned_target, banner)
            _attack_pulse_timer += delta
            if _attack_pulse_timer >= 0.8:
                _attack_pulse_timer = 0.0
                parent_unit._toggle_hitbox()
        else:
            if is_instance_valid(banner) and banner.has_method("release_pawn_target"):
                banner.release_pawn_target(parent_unit)
            current_state = State.IDLE_FOLLOW
            _idle_follow(delta)
            return
    else:
        if enemy_dist < parent_unit.attack_range:
            if not parent_unit.is_attacking:
                parent_unit._play_sequential_attack(assigned_target, banner)
                parent_unit.velocity = (dir * 1.2 + separation * 0.5).normalized() * parent_unit.speed * 1.2
            else:
                var blend_target: Vector2 = (dir * 0.6 + separation * 0.5).normalized() * parent_unit.speed * 0.6
                parent_unit.velocity = parent_unit.velocity.lerp(blend_target, delta * 8.0)
            _attack_pulse_timer += delta
            if _attack_pulse_timer >= 0.8:
                _attack_pulse_timer = 0.0
                parent_unit._toggle_hitbox()
        else:
            var desired: Vector2 = (dir * parent_unit.speed + separation).normalized() * parent_unit.speed
            parent_unit.velocity = parent_unit.velocity.lerp(desired, delta * 8.0)
            if is_instance_valid(parent_unit.animated_sprite):
                if parent_unit.animated_sprite.animation != "Run":
                    parent_unit.animated_sprite.play("Run")
                if dir.x != 0:
                    parent_unit.animated_sprite.flip_h = dir.x < 0

    parent_unit.move_and_slide()
