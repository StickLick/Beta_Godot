class_name SingularityStaff
extends BaseWeapon

const ORB_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/SingularityOrb.tscn")

@export var pull_strength: float = 1500.0
@export var pull_radius: float = 250.0


func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
    var target = _get_closest_enemy()
    if target == null:
        cooldown_timer.start(0.3)
        return
    
    var dir = (target.global_position - global_position).normalized()
    _spawn_orb(dir)
    cooldown_timer.start(attack_cooldown)


func _spawn_orb(direction: Vector2) -> void:
    var orb = ORB_SCENE.instantiate() as SingularityOrb
    if not orb:
        return
    
    var root = get_tree().current_scene
    root.add_child(orb)
    orb.global_position = global_position
    orb.direction = direction
    orb.damage = final_damage
    orb.pull_strength = pull_strength
    orb.pull_radius = pull_radius


func _get_closest_enemy() -> Area2D:
    var closest: Area2D = null
    var dist_sq: float = INF
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage") and area.get("faction") != "player":
            var d = global_position.distance_squared_to(area.global_position)
            if d < dist_sq:
                dist_sq = d
                closest = area
    return closest
