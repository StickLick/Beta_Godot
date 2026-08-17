extends Node
## Ограниченная по времени охота на курьера (v2).
## Независимая система: не связана с GameManager.current_anomaly / _process_anomaly_logic.
## Случайное появление через check_interval; шанс снижается вдвое после срабатывания.

signal hunt_started(duration: float)
signal hunt_ended()

@export var courier_scene: PackedScene = null
@export var check_interval: float = 90.0
@export var initial_chance: float = 0.20
@export var min_chance: float = 0.05
@export var event_duration: float = 30.0

var _check_timer: Timer
var _event_timer: Timer
var _current_chance: float = 0.20
var _active_courier: Courier = null
var time_left: float = 0.0     # для HUD


func _ready() -> void:
    add_to_group("courier_hunt_event")
    _current_chance = initial_chance
    _check_timer = Timer.new()
    _check_timer.one_shot = true
    _check_timer.wait_time = check_interval
    _check_timer.timeout.connect(_on_check)
    add_child(_check_timer)
    _check_timer.start()


func _process(_delta: float) -> void:
    # Живой отсчёт для HUD
    if is_instance_valid(_active_courier) and _event_timer != null:
        time_left = max(0.0, _event_timer.time_left)
    elif _active_courier == null:
        time_left = 0.0


func _on_check() -> void:
    # Активный курьер — пропуск проверки без изменения шанса
    if is_instance_valid(_active_courier) or not get_tree().get_nodes_in_group("courier").is_empty():
        _schedule_check()
        return
    if randf() < _current_chance:
        _spawn_courier()
    # Промах: шанс НЕ растёт — просто ждём следующую проверку
    _schedule_check()


func _spawn_courier() -> void:
    if not is_instance_valid(courier_scene):
        return
    var c: Courier = courier_scene.instantiate()

    # Спавн в случайной точке карты, но не ближе 900px к игроку
    var rect: Rect2 = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000, -2000, 4000, 4000)
    var player: Node2D = get_tree().get_first_node_in_group("player")
    var pos := Vector2(
        randf_range(rect.position.x + 200, rect.end.x - 200),
        randf_range(rect.position.y + 200, rect.end.y - 200)
    )
    var attempts := 0
    while player and pos.distance_to(player.global_position) < 900.0 and attempts < 30:
        pos = Vector2(
            randf_range(rect.position.x + 200, rect.end.x - 200),
            randf_range(rect.position.y + 200, rect.end.y - 200)
        )
        attempts += 1
    c.global_position = pos
    get_tree().current_scene.add_child(c)
    _active_courier = c
    c.died.connect(_on_courier_died)

    # Снижение шанса вдвое (не ниже порога)
    _current_chance = max(min_chance, _current_chance * 0.5)

    # Таймер преследования (Timer-узел)
    _event_timer = Timer.new()
    _event_timer.one_shot = true
    _event_timer.wait_time = event_duration
    _event_timer.timeout.connect(_on_event_timeout)
    add_child(_event_timer)
    _event_timer.start()

    hunt_started.emit(event_duration)
    print("[COURIER HUNT] started | chance now=", _current_chance)


func _on_courier_died() -> void:
    if _event_timer:
        _event_timer.queue_free()
        _event_timer = null
    _active_courier = null
    time_left = 0.0
    hunt_ended.emit()


func _on_event_timeout() -> void:
    if is_instance_valid(_active_courier):
        _active_courier.queue_free()
    _event_timer.queue_free()
    _event_timer = null
    _active_courier = null
    time_left = 0.0
    hunt_ended.emit()
    print("[COURIER HUNT] courier escaped (timeout)")


func _schedule_check() -> void:
    _check_timer.wait_time = check_interval
    _check_timer.start()
