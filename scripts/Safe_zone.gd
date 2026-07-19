extends Area2D

@export var max_radius: float = 1400.0
@export var min_radius: float = 400.0
@export var duration: float = 40.0

# Это свойство читает Player.gd для расчета урона
var current_radius: float = 1400.0
var _time_passed: float = 0.0

func _ready() -> void:
    add_to_group("safe_zone")
    current_radius = max_radius
    
    # Эффект появления
    modulate.a = 0
    create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
    
    # Визуальная пульсация края
    var p_tween = create_tween().set_loops()
    p_tween.tween_property(self, "modulate:v", 1.5, 0.5)
    p_tween.tween_property(self, "modulate:v", 1.0, 0.5)

func _process(delta: float) -> void:
    _time_passed += delta
    var progress = clamp(_time_passed / duration, 0.0, 1.0)
    
    # Плавное сужение радиуса
    current_radius = lerp(max_radius, min_radius, progress)
    
    # Масштабирование (базовый радиус круга в _draw = 100)
    scale = Vector2.ONE * (current_radius / 100.0)
    queue_redraw()

func _draw() -> void:
    # Рисуем только визуал. Коллизии масштабируются вместе с узлом (scale)
    draw_circle(Vector2.ZERO, 100.0, Color(0, 0.6, 1.0, 0.1))
    draw_arc(Vector2.ZERO, 100.0, 0, TAU, 128, Color.CYAN, 4.0)
    draw_arc(Vector2.ZERO, 101.0, 0, TAU, 64, Color(0, 0.4, 1.0, 0.4), 2.0)
