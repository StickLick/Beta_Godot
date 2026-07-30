extends Node2D

enum State { IDLE_FOLLOW, COMBAT }

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


func _in_leash(target: Node2D) -> bool:
    if not is_instance_valid(player) or not is_instance_valid(target):
        return false
    return player.global_position.distance_to(target.global_position) <= 400.0


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
        var desired: Vector2 = dir * parent_unit.speed
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
    
    if enemy_dist < attack_range:
        if not parent_unit.is_attacking:
            parent_unit._play_sequential_attack()
            parent_unit.velocity = dir * parent_unit.speed * 1.2
        else:
            parent_unit.velocity = parent_unit.velocity.lerp(dir * parent_unit.speed * 0.6, delta * 8.0)
        _attack_pulse_timer += delta
        if _attack_pulse_timer >= 0.8:
            _attack_pulse_timer = 0.0
            parent_unit._toggle_hitbox()
    else:
        var desired: Vector2 = dir * parent_unit.speed
        parent_unit.velocity = parent_unit.velocity.lerp(desired, delta * 8.0)
        if is_instance_valid(parent_unit.animated_sprite):
            if parent_unit.animated_sprite.animation != "Run":
                parent_unit.animated_sprite.play("Run")
            if dir.x != 0:
                parent_unit.animated_sprite.flip_h = dir.x < 0
    
    parent_unit.move_and_slide()
