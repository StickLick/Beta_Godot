extends Area2D

enum State { CHARGING, COLLAPSE, EXPLODE }
var current_state: State = State.CHARGING

@export var pull_strength: float = 2200.0
@export var push_strength: float = 7000.0 
@export var pull_radius: float = 500.0
@export var influence_radius: float = 1000.0

# Параметры взрывного урона
const EXPLOSION_RADIUS: float = 200.0
const EXPLOSION_DAMAGE: float = 70.0

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
            gem.xp_amount = 15
            get_tree().current_scene.add_child(gem)
    
    # Взрывной урон: одинаково для игрока, его юнитов и врагов в радиусе взрыва.
    _deal_explosion_damage(["player", "enemy", "ally_units", "units"])
    
    var t = create_tween()
    t.tween_property(self, "modulate", Color(10, 10, 10, 1), 0.1)
    t.tween_property(self, "modulate", Color.WHITE, 0.4)

func _deal_explosion_damage(groups: Array) -> void:
    for group_name in groups:
        for node in get_tree().get_nodes_in_group(group_name):
            if not is_instance_valid(node) or not node is Node2D:
                continue
            var d: float = global_position.distance_to(node.global_position)
            if d > EXPLOSION_RADIUS:
                continue
            var health = node.get("health_component")
            if health == null or not is_instance_valid(health):
                continue
            if health.has_method("take_damage"):
                health.take_damage(EXPLOSION_DAMAGE)

func _draw() -> void:
    var color = Color.PURPLE
    if current_state == State.COLLAPSE: 
        color = Color.RED
        # Внешняя зона притяжения (опасная зона COLLAPSE) — пунктирный красный круг.
        _draw_dashed_circle(Vector2.ZERO, influence_radius, Color(1.0, 0.35, 0.35, 0.9), 24.0, 2.0)
    
    if current_state == State.EXPLODE: color = Color.WHITE
    
    # Ядро
    draw_circle(Vector2.ZERO, 45.0 * (1.8 if current_state == State.COLLAPSE else 1.0), Color(0,0,0,1.0))
    # Основной радиус (визуальная граница)
    draw_arc(Vector2.ZERO, pull_radius, 0, TAU, 64, color, 3.0)

func _draw_dashed_circle(center: Vector2, radius: float, color: Color, dash_len: float = 20.0, width: float = 2.0) -> void:
    var segments: int = 64
    var segment_angle: float = TAU / float(segments)
    var dash_angle: float = dash_len / maxf(radius, 1.0)
    var i: int = 0
    while i < segments:
        var start_angle: float = float(i) * segment_angle
        var end_angle: float = start_angle + minf(dash_angle, segment_angle)
        draw_arc(center, radius, start_angle, end_angle, 4, color, width)
        i += 2
