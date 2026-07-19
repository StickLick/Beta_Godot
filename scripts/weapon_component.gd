class_name WeaponComponent
extends Node2D

const SWING_SCALE_UP_DURATION: float = 0.1
@export var base_damage: float = 15.0

@export var attack_cooldown: float = 1.0:
    set(value):
        attack_cooldown = max(0.05, value)
        if is_instance_valid(cooldown_timer):
            cooldown_timer.wait_time = attack_cooldown

@export var rotation_offset_degrees: float = 0.0

@onready var detection_area: Area2D = $DetectionArea
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var visual_pivot: Node2D = $VisualPivot
@onready var hitbox: HitboxComponent = $VisualPivot/HitboxComponent

var player: Player

func _ready() -> void:
    await get_tree().process_frame
    player = get_tree().get_first_node_in_group("player")
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start()

func _on_cooldown_timeout() -> void:
    var target = _get_closest_target()
    if target == null:
        cooldown_timer.start(0.1)
        return

    visual_pivot.look_at(target.global_position)
    visual_pivot.rotation += deg_to_rad(rotation_offset_degrees)
    
    if is_instance_valid(player) and player.has_method("play_attack_animation"):
        player.play_attack_animation(target.global_position)
        
    _perform_swing()

func _get_closest_target() -> Area2D:
    var closest_target: Area2D = null
    var closest_distance_sq: float = INF
    
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage"):
            if area.get("faction") == "player": continue
            var distance_sq = global_position.distance_squared_to(area.global_position)
            if distance_sq < closest_distance_sq:
                closest_distance_sq = distance_sq
                closest_target = area
    return closest_target

func _perform_swing() -> void:
    var multiplier = player.get_final_damage_multiplier() if is_instance_valid(player) else 1.0
    
    if is_instance_valid(hitbox):
        hitbox.damage = base_damage * multiplier
        hitbox.faction = "player"
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape: shape.disabled = false

    var tween: Tween = create_tween().set_parallel(true)
    visual_pivot.scale = Vector2.ZERO
    tween.tween_property(visual_pivot, "scale", Vector2(1.8, 1.8), SWING_SCALE_UP_DURATION)
    tween.chain().tween_property(visual_pivot, "scale", Vector2(0.0, 0.0), SWING_SCALE_UP_DURATION)
    tween.finished.connect(_on_swing_finished)

func _on_swing_finished() -> void:
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape: shape.disabled = true
    cooldown_timer.start(attack_cooldown)
