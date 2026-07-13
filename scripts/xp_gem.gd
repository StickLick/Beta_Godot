extends Area2D
class_name XPGem

@export var mass_amount: float = 0.5
@export var xp_amount: int = 10 

var target_player: CharacterBody2D = null
var is_available: bool = false # Флаг доступности для сбора

func _ready() -> void:
    add_to_group("resources")
    body_entered.connect(_on_body_entered)
    
    # Анимация "прыжка" при появлении
    _play_spawn_animation()

func _play_spawn_animation() -> void:
    is_available = false
    
    # Случайная точка для прыжка в радиусе 20-40 пикселей
    var random_direction = Vector2.from_angle(randf() * TAU)
    var jump_dist = randf_range(20.0, 40.0)
    var jump_target = global_position + random_direction * jump_dist
    
    var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
    
    # Прыжок и небольшое масштабирование
    tween.tween_property(self, "global_position", jump_target, 0.4)
    tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
    tween.chain().tween_property(self, "scale", Vector2.ONE, 0.2)
    
    # После завершения анимации кристалл можно собирать
    tween.tween_callback(func(): is_available = true)

func _physics_process(delta: float) -> void:
    # Кристалл летит к игроку только если он доступен и игрок в радиусе
    if is_available and target_player and is_instance_valid(target_player):
        var direction: Vector2 = (target_player.global_position - global_position).normalized()
        global_position += direction * 500.0 * delta # Чуть быстрее для удобства
        
        if global_position.distance_to(target_player.global_position) < 20.0:
            _collect()

func _on_body_entered(body: Node2D) -> void:
    if is_available and body.is_in_group("player"):
        target_player = body as CharacterBody2D

func _collect() -> void:
    if is_instance_valid(target_player):
        if target_player.has_method("collect_mass"):
            target_player.collect_mass(mass_amount)
        if target_player.has_method("collect_xp"):
            target_player.collect_xp(xp_amount)
    queue_free()

func attract(player: CharacterBody2D) -> void:
    if is_available:
        target_player = player
