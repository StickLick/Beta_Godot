extends Area2D
class_name OreNode
## Нейтральный рудный узел на карте.
## Существует только до захвата. При захвате заменяется на Mine.
## Визуалы настраиваются через Inspector.

enum Alignment { NEUTRAL = 0, PLAYER = 1, RIVAL = 2 }

# -- Константы захвата (хуки для будущей мета-прогрессии) --
const CAPTURE_BASE_SPEED: float = 8.0
const CAPTURE_DECAY_RATE: float = 3.0
const CAPTURE_GRACE_TIME: float = 0.8

@export var alignment: Alignment = Alignment.NEUTRAL
@export var capture_progress: float = 0.0
@export var capture_threshold: float = 100.0

var _player_inside: bool = false
var _unit_count: int = 0
var _capture_label: Label = null
var _out_of_zone_timer: float = 0.0


func _ready() -> void:
    add_to_group("ore_nodes")
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _setup_capture_label()
    _setup_capture_ring()


func _process(delta: float) -> void:
    if alignment != Alignment.NEUTRAL:
        return
    _handle_capture(delta)


## Создаёт дочерний Node2D «CaptureRing» с z_index = 0. Окружность рисует
## только этот узел: кольцо лежит на уровне земли (выше травы/воды, которые
## тоже z=0, но идут в дереве раньше руды) и НЕ перекрывает игрока (z=1).
func _setup_capture_ring() -> void:
    var ring := CaptureRing.new()
    ring.name = "CaptureRing"
    ring.z_index = 0
    add_child(ring)
    ring.queue_redraw()


## Дочерний узел, рисующий окружность зоны захвата поверх тайлов.
## Радиус читается из CollisionShape2D родителя (OreNode).
class CaptureRing extends Node2D:
    func _draw() -> void:
        var ore := get_parent() as OreNode
        if ore == null:
            return
        if ore.alignment != OreNode.Alignment.NEUTRAL:
            return
        var shape_node := ore.get_node_or_null("CollisionShape2D") as CollisionShape2D
        if shape_node == null:
            return
        var circle := shape_node.shape as CircleShape2D
        if circle == null:
            return
        var col := Color(1, 0.95, 0.7, 0.35)
        # Обводка круга из 64 сегментов (заметное кольцо).
        var segments := 64
        var step := TAU / float(segments)
        var pts := PackedVector2Array()
        for i in range(segments):
            var a := step * float(i)
            pts.append(Vector2(cos(a), sin(a)) * circle.radius)
        # Замкнуть контур.
        pts.append(pts[0])
        draw_polyline(pts, col, 3.0, true)


func _setup_capture_label() -> void:
    ## Временный debug-лейбл прогресса захвата. Создаётся в рантайме.
    _capture_label = Label.new()
    _capture_label.name = "CaptureDebugLabel"
    _capture_label.position = Vector2(-100, -90)
    _capture_label.size = Vector2(200, 30)
    _capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _capture_label.add_theme_font_size_override("font_size", 14)
    _capture_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
    _capture_label.text = "Захват: 0%"
    add_child(_capture_label)


func _refresh_capture_label() -> void:
    if not is_instance_valid(_capture_label):
        return
    var pct := int(round(clampf(capture_progress / capture_threshold, 0.0, 1.0) * 100.0))
    _capture_label.text = "Захват: %d%%" % pct


func _handle_capture(delta: float) -> void:
    var invaders := 0
    var player_present := false
    var invader_alignment := 0

    for b in get_overlapping_bodies():
        if b is Player:
            player_present = true
        elif b is Unit and b.alignment != 0:
            if invaders == 0:
                invader_alignment = b.alignment
            if b.alignment == invader_alignment:
                invaders += 1

    if invaders >= 2 and invader_alignment == Alignment.RIVAL:
        # Rival units capture
        _out_of_zone_timer = 0.0
        capture_progress += (invaders * 4.0) * delta
        if capture_progress >= capture_threshold:
            _on_captured(Alignment.RIVAL)
    elif player_present or invaders > 0:
        # Игрок или его юниты захватывают
        _out_of_zone_timer = 0.0
        var speed := CAPTURE_BASE_SPEED + invaders * 4.0
        var effective_alignment := Alignment.PLAYER if player_present else invader_alignment
        capture_progress += speed * delta
        if capture_progress >= capture_threshold:
            _on_captured(effective_alignment)
    else:
        # Никого в зоне — постепенный decay после grace time
        if capture_progress > 0.0:
            _out_of_zone_timer += delta
            if _out_of_zone_timer >= CAPTURE_GRACE_TIME:
                capture_progress = max(0.0, capture_progress - CAPTURE_DECAY_RATE * delta)

    _refresh_capture_label()


func _on_captured(new_alignment: Alignment) -> void:
    alignment = new_alignment
    # Debug-вспышка при завершении захвата
    var anim = get_node_or_null("AnimatedSprite2D")
    if is_instance_valid(anim):
        anim.modulate = Color(2.0, 2.0, 0.5)
    remove_from_group("ore_nodes")
    _on_captured_as_mine(new_alignment)


func _on_captured_as_mine(new_alignment: Alignment) -> void:
    ## Переопределяется в Mine или через сигнал.
    ## По умолчанию: создаёт Mine на этом месте.
    var mine_scene: PackedScene = null
    if ResourceLoader.exists("res://Assets/Scenes/Mine.tscn"):
        mine_scene = load("res://Assets/Scenes/Mine.tscn") as PackedScene
    if mine_scene:
        var mine := mine_scene.instantiate()
        mine.global_position = global_position
        mine.set("alignment", int(new_alignment))
        get_tree().current_scene.add_child(mine)
    else:
        # Fallback: создаём Mine скриптом
        var mine := Mine.new()
        mine.name = "Mine_Fallback"
        mine.global_position = global_position
        mine.set("alignment", int(new_alignment))

        # Добавляем CollisionShape2D + CircleShape2D (обязательно для Area2D)
        var collision := CollisionShape2D.new()
        var circle := CircleShape2D.new()
        circle.radius = 120.0
        collision.shape = circle
        collision.name = "CollisionShape2D"
        mine.add_child(collision)

        # Добавляем визуальную заглушку — Polygon2D (как в camp.gd)
        var visual := Polygon2D.new()
        visual.name = "Polygon2D"
        visual.polygon = _make_hexagon(120.0)
        mine.add_child(visual)

        get_tree().current_scene.add_child(mine)
    queue_free()


func _on_body_entered(body: Node2D) -> void:
    if body is Player:
        _player_inside = true


func _on_body_exited(body: Node2D) -> void:
    if body is Player:
        _player_inside = false


func _make_hexagon(radius: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(6):
        var angle := deg_to_rad(60.0 * float(i) - 30.0)
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points
