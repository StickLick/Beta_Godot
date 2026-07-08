class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent
@export var faction: String = "player"
@export var invulnerability_duration: float = 0.5

var _is_invulnerable: bool = false

var _invulnerability_timer: Timer

signal hit_received(damage: float)


func _ready() -> void:
    monitoring = true
    monitorable = true

    var parent_name: String = get_parent().name if get_parent() != null else "unknown"

    if health_component == null:
        print(
            "[HURTBOX ERROR] Hurtbox on node '" + parent_name + "' has NO HealthComponent assigned in the Inspector!"
        )

    if collision_mask == 0:
        print(
            "[HURTBOX ERROR] Hurtbox on node '" + parent_name + "' has collision mask set to 0 (it will never detect any hitboxes)!"
        )

    area_entered.connect(_on_area_entered)

    _invulnerability_timer = Timer.new()
    _invulnerability_timer.one_shot = true
    _invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
    add_child(_invulnerability_timer)


func _on_area_entered(area: Area2D) -> void:
    var hitbox: HitboxComponent = area as HitboxComponent
    if not hitbox:
        return

    if _is_invulnerable:
        return

    if hitbox.get_parent() == get_parent():
        return

    if hitbox.faction.to_lower() == faction.to_lower():
        return

    _apply_damage(hitbox.damage)


func _apply_damage(amount: float) -> void:
    if health_component == null:
        return
        
    print("DEBUG: Враг получил урон: ", amount)

    # 1. Set invulnerability and start timer FIRST
    _is_invulnerable = true
    if _invulnerability_timer and is_inside_tree():
        _invulnerability_timer.start(invulnerability_duration)

    # 2. Apply damage and emit signal second
    health_component.take_damage(amount)
    if is_inside_tree():
        hit_received.emit(amount)


func _on_invulnerability_timeout() -> void:
    _is_invulnerable = false

    for area: Area2D in get_overlapping_areas():
        var hitbox: HitboxComponent = area as HitboxComponent
        if not hitbox:
            continue

        if hitbox.get_parent() == get_parent():
            continue

        if hitbox.faction.to_lower() == faction.to_lower():
            continue

        _apply_damage(hitbox.damage)
        break
