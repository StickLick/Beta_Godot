extends Area2D
class_name XPGem

@export var mass_amount: float = 0.5
@export var xp_amount: int = 10 # Добавили значение опыта

var target_player: CharacterBody2D = null

func _ready() -> void:
    add_to_group("resources")
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    if target_player and is_instance_valid(target_player):
        var direction: Vector2 = (target_player.global_position - global_position).normalized()
        global_position += direction * 400.0 * delta
        
        if global_position.distance_to(target_player.global_position) < 20.0:
            _collect()

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        target_player = body as CharacterBody2D

func _collect() -> void:
    if is_instance_valid(target_player):
        # Вызываем оба метода
        if target_player.has_method("collect_mass"):
            target_player.collect_mass(mass_amount)
        if target_player.has_method("collect_xp"):
            target_player.collect_xp(xp_amount)
    queue_free()

func attract(player: CharacterBody2D) -> void:
    target_player = player
