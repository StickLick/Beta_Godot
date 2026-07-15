extends Area2D
class_name XPGem

# Увеличили массу за один кристалл для наглядности
@export var mass_amount: float = 2.0
@export var xp_amount: int = 10 

var target_player: CharacterBody2D = null
var is_available: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
    add_to_group("resources")
    _play_spawn_animation()
    # Запустить анимацию с названием "Gold"
    animated_sprite.play("Gold")

func _play_spawn_animation() -> void:
    is_available = false
    var jump_target = global_position + Vector2.from_angle(randf() * TAU) * randf_range(30, 60)
    var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "global_position", jump_target, 0.5)
    tween.tween_callback(func(): is_available = true)

func _physics_process(delta: float) -> void:
    if not is_available: return
    if target_player == null:
        _check_proximity_to_player()
        return

    if is_instance_valid(target_player):
        var direction = (target_player.global_position - global_position).normalized()
        global_position += direction * 750.0 * delta
        if global_position.distance_to(target_player.global_position) < 30.0:
            _collect()
    else:
        target_player = null

func _check_proximity_to_player() -> void:
    var player = get_tree().get_first_node_in_group("player") as Player
    if is_instance_valid(player):
        var dist = global_position.distance_to(player.global_position)
        var magnet_range = 200.0 * player.xp_radius
        if dist < magnet_range:
            target_player = player

func _collect() -> void:
    if is_instance_valid(target_player):
        if target_player.has_method("collect_mass"): target_player.collect_mass(mass_amount)
        if target_player.has_method("collect_xp"): target_player.collect_xp(xp_amount)
    queue_free()

func attract(player: CharacterBody2D) -> void:
    if is_available: target_player = player
