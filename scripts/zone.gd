class_name Zone extends Area2D

signal evolved(pos: Vector2, zone_type: String, dominance: float)
enum ZoneState { SPAWN, GROWTH, ACTIVE, DECAY, DESPAWN }

@export_group("LEGION Properties")
@export var zone_type: String = "Acceleration"
@export var core_radius: float = 120.0 
@export var dominance: float = 1.0:
    set(value):
        dominance = clamp(value, 0.2, 4.0)

var current_state: ZoneState = ZoneState.SPAWN
var _state_timer: float = 0.0
var _settling_timer: float = 0.0
var _is_evolving: bool = false
var _player_inside: bool = false

const EVOLUTION_THRESHOLD: float = 2.2 
const SETTLING_TIME: float = 3.5

const SPAWN_DURATION: float = 1.0
const GROWTH_DURATION: float = 2.0
const ACTIVE_DURATION: float = 45.0 

func _ready() -> void:
    add_to_group("zones")
    # Настройка слоев: Зона должна видеть игрока (Layer 1)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _setup_visuals()

func _process(delta: float) -> void:
    _update_lifecycle(delta)
    
    if current_state == ZoneState.ACTIVE:
        # Автономный медленный рост
        dominance += 0.02 * delta
        # Ускоренный рост от игрока
        if _player_inside:
            dominance += 0.3 * delta
            
    _check_for_evolution(delta)
    queue_redraw()

func inject_mass(amount: float) -> void:
    if current_state == ZoneState.ACTIVE:
        dominance += (amount * 0.05)

func _setup_visuals() -> void:
    match zone_type:
        "Acceleration": modulate = Color(0, 1, 1, 0.4)
        "Stabilization": modulate = Color(0, 1, 0, 0.4)
        "Pressure": modulate = Color(1, 0, 0, 0.4)
        "Flux": modulate = Color(0.6, 0, 1, 0.4)

func _check_for_evolution(delta: float) -> void:
    if current_state != ZoneState.ACTIVE or _is_evolving: return
    if dominance >= EVOLUTION_THRESHOLD:
        _settling_timer += delta
        position += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
        if _settling_timer >= SETTLING_TIME:
            _is_evolving = true
            evolved.emit(global_position, zone_type, dominance)
            _transition_to(ZoneState.DESPAWN)

func _update_lifecycle(delta: float) -> void:
    _state_timer += delta
    var lifecycle_scale: float = 1.0
    match current_state:
        ZoneState.SPAWN:
            lifecycle_scale = 0.1
            if _state_timer >= SPAWN_DURATION: _transition_to(ZoneState.GROWTH)
        ZoneState.GROWTH:
            lifecycle_scale = lerp(0.1, 1.0, _state_timer / GROWTH_DURATION)
            if _state_timer >= GROWTH_DURATION: _transition_to(ZoneState.ACTIVE)
        ZoneState.ACTIVE:
            lifecycle_scale = 1.0
            if _state_timer >= ACTIVE_DURATION: _transition_to(ZoneState.DECAY)
        ZoneState.DECAY:
            lifecycle_scale = lerp(1.0, 0.0, _state_timer / 5.0)
            if lifecycle_scale <= 0.05: _transition_to(ZoneState.DESPAWN)
        ZoneState.DESPAWN:
            queue_free()
            return
    scale = Vector2.ONE * (lifecycle_scale * dominance)

func _transition_to(new_state: ZoneState) -> void:
    current_state = new_state
    _state_timer = 0.0

func get_influence_factor(player_pos: Vector2) -> float:
    var distance: float = global_position.distance_to(player_pos)
    var current_radius = core_radius * scale.x
    if current_radius <= 0: return 0.0
    return clampf(1.0 - (distance / current_radius), 0.0, 1.0)

func _on_body_entered(body: Node2D) -> void:
    if body is Player:
        _player_inside = true
        body.register_zone(self)

func _on_body_exited(body: Node2D) -> void:
    if body is Player:
        _player_inside = false
        body.unregister_zone(self)

func _draw() -> void:
    draw_circle(Vector2.ZERO, core_radius, Color(1, 1, 1, 0.1))
    draw_arc(Vector2.ZERO, core_radius, 0, TAU, 32, Color.WHITE, 1.0)
