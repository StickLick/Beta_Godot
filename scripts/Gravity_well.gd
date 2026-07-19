extends Area2D

enum State { CHARGING, COLLAPSE, EXPLODE }
var current_state: State = State.CHARGING

@export var pull_strength: float = 2200.0
@export var push_strength: float = 7000.0 
@export var pull_radius: float = 500.0
@export var influence_radius: float = 1100.0 

var _timer: float = 0.0
const CYCLE_TIME: float = 6.0 

func _ready() -> void:
    add_to_group("gravity_well")
    scale = Vector2.ZERO
    create_tween().tween_property(self, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_BACK)

func _process(delta: float) -> void:
    _timer += delta
    
    if _timer < 3.5:
        current_state = State.CHARGING
        modulate = Color(1, 1, 1, 1).lerp(Color.PURPLE, _timer / 3.5)
    elif _timer < 5.0:
        current_state = State.COLLAPSE
        modulate = Color.RED
        position += Vector2(randf_range(-3, 3), randf_range(-3, 3))
    else:
        if current_state != State.EXPLODE:
            _execute_explosion()
        current_state = State.EXPLODE

    if _timer >= CYCLE_TIME:
        _timer = 0.0
        current_state = State.CHARGING

    queue_redraw()

func _execute_explosion() -> void:
    var gem_scene = load("res://Assets/Scenes/Xp_gem.tscn")
    if gem_scene:
        for i in range(7):
            var gem = gem_scene.instantiate()
            gem.global_position = global_position
            gem.xp_amount = 30
            get_tree().current_scene.add_child(gem)
    
    var t = create_tween()
    t.tween_property(self, "modulate", Color(10, 10, 10, 1), 0.1)
    t.tween_property(self, "modulate", Color.WHITE, 0.4)

func _draw() -> void:
    var color = Color.PURPLE
    if current_state == State.COLLAPSE: 
        color = Color.RED
        # ВНЕШНЯЯ ЗОНА ТЕПЕРЬ НЕ РИСУЕТСЯ, ТОЛЬКО ЧУВСТВУЕТСЯ
    
    if current_state == State.EXPLODE: color = Color.WHITE
    
    # Ядро
    draw_circle(Vector2.ZERO, 45.0 * (1.8 if current_state == State.COLLAPSE else 1.0), Color(0,0,0,1.0))
    # Основной радиус (визуальная граница)
    draw_arc(Vector2.ZERO, pull_radius, 0, TAU, 64, color, 3.0)
