extends Area2D

@export var max_radius: float = 1400.0
@export var min_radius: float = 400.0
@export var duration: float = 40.0

# Это свойство читает Player.gd для расчета урона и Hud.gd для шейдера
var current_radius: float = 1400.0
var _time_passed: float = 0.0

func _ready() -> void:
    add_to_group("safe_zone")
    current_radius = max_radius
    
    # Эффект появления (плавное проявление границы)
    modulate.a = 0
    create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
    
    # Визуальная пульсация только для ГРАНИЦЫ (делаем её "живой")
    var p_tween = create_tween().set_loops()
    p_tween.tween_property(self, "modulate:v", 2.0, 0.6) # Вспышка яркости
    p_tween.tween_property(self, "modulate:v", 1.0, 0.6)

func _process(delta: float) -> void:
    _time_passed += delta
    var progress = clamp(_time_passed / duration, 0.0, 1.0)
    
    # Плавное сужение радиуса
    current_radius = lerp(max_radius, min_radius, progress)
    
    # Масштабирование узла (базовый радиус в _draw = 100)
    scale = Vector2.ONE * (current_radius / 100.0)
    queue_redraw()

func _draw() -> void:
    # --- ИСПРАВЛЕНИЕ: Мы больше не рисуем draw_circle здесь! ---
    # Теперь внутри зоны будет абсолютно стандартная картинка.
    
    # Рисуем только четкую внешнюю границу (кольцо)
    draw_arc(Vector2.ZERO, 100.0, 0, TAU, 128, Color.CYAN, 3.0)
    
    # Добавляем мягкое внешнее свечение самой линии
    draw_arc(Vector2.ZERO, 101.0, 0, TAU, 64, Color(0, 0.5, 1.0, 0.4), 1.5)
    draw_arc(Vector2.ZERO, 99.0, 0, TAU, 64, Color(0, 0.5, 1.0, 0.4), 1.5)

func _exit_tree() -> void:
    # Можно добавить эффект вспышки при исчезновении
    pass
