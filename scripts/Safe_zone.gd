extends Area2D

var max_radius: float = 1400.0
var min_radius: float = 450.0 # Увеличено, чтобы игрок помещался
var duration: float = 40.0
var current_radius: float = 1400.0

var _time_passed: float = 0.0

func _ready() -> void:
    add_to_group("safe_zone")
    current_radius = max_radius
    # Визуальная пульсация
    var p_tween = create_tween().set_loops()
    p_tween.tween_property(self, "modulate", Color(1.5, 1.5, 2.0, 0.8), 0.5)
    p_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.4), 0.5)

func _process(delta: float) -> void:
    _time_passed += delta
    var progress = clamp(_time_passed / duration, 0.0, 1.0)
    
    # Математическое сужение радиуса
    current_radius = lerp(max_radius, min_radius, progress)
    
    # Синхронизируем визуальный масштаб (базовый радиус в _draw = 100)
    scale = Vector2.ONE * (current_radius / 100.0)
    queue_redraw()

func _draw() -> void:
    # Рисуем четкую границу
    draw_arc(Vector2.ZERO, 100.0, 0, TAU, 64, Color.CYAN, 5.0)
    draw_circle(Vector2.ZERO, 100.0, Color(0, 1, 1, 0.1))
