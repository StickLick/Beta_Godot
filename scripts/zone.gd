class_name Zone
extends Area2D

# --- Состояния жизненного цикла ---
enum ZoneState { SPAWN, GROWTH, ACTIVE, DECAY, DESPAWN }

# --- Свойства зоны по архитектуре LEGION ---
@export_group("LEGION Properties")
@export_enum("Acceleration", "Stabilization", "Pressure", "Flux") var zone_type: String = "Acceleration"
@export var zone_mass: float = 100.0
@export var core_radius: float = 120.0 # Фиксированный радиус влияния на игрока
@export var soft_influence_radius: float = 250.0 # Радиус влияния на другие зоны
@export var dominance: float = 1.0 # Сила доминирования зоны (меняется при конкуренции)
@export var growth_rate: float = 15.0
@export var absorb_rate: float = 5.0

var local_influence_multiplier: float = 1.0
var current_state: ZoneState = ZoneState.SPAWN
var _state_timer: float = 0.0

# Длительность фаз жизненного цикла (в секундах)
const SPAWN_DURATION: float = 1.0
const GROWTH_DURATION: float = 2.0
const ACTIVE_DURATION: float = 10.0
const DECAY_DURATION: float = 4.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    # Подключение сигналов
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    
    _setup_visuals()
    _setup_collision_radius()

func _process(delta: float) -> void:
    _update_lifecycle(delta)

# Рассчитывает силу влияния на игрока (1.0 в центре, 0.0 на границе core_radius)
func get_influence_factor(player_pos: Vector2) -> float:
    var distance: float = global_position.distance_to(player_pos)
    # Влияние также масштабируется от текущего уровня доминирования зоны
    return clamp(1.0 - (distance / (core_radius * dominance)), 0.0, 1.0)

# Цветовая индикация типов зон
func _setup_visuals() -> void:
    match zone_type:
        "Acceleration": modulate = Color.CYAN
        "Stabilization": modulate = Color.GREEN
        "Pressure": modulate = Color.RED
        "Flux": modulate = Color.YELLOW

# Управление жизненным циклом и динамическим масштабом
func _update_lifecycle(delta: float) -> void:
    _state_timer += delta
    var lifecycle_scale: float = 1.0
    
    match current_state:
        ZoneState.SPAWN:
            lifecycle_scale = 0.1
            if _state_timer >= SPAWN_DURATION:
                _transition_to(ZoneState.GROWTH)
        ZoneState.GROWTH:
            var progress: float = _state_timer / GROWTH_DURATION
            lifecycle_scale = lerp(0.1, 1.0, progress)
            if _state_timer >= GROWTH_DURATION:
                _transition_to(ZoneState.ACTIVE)
        ZoneState.ACTIVE:
            lifecycle_scale = 1.0
            if _state_timer >= ACTIVE_DURATION:
                _transition_to(ZoneState.DECAY)
        ZoneState.DECAY:
            var progress: float = _state_timer / DECAY_DURATION
            lifecycle_scale = lerp(1.0, 0.0, progress)
            modulate.a = lerp(1.0, 0.0, progress)
            if _state_timer >= DECAY_DURATION:
                _transition_to(ZoneState.DESPAWN)
        ZoneState.DESPAWN:
            queue_free()
            return

    # Итоговый масштаб зоны зависит от фазы жизни И её текущего доминирования (dominance)
    scale = Vector2.ONE * (lifecycle_scale * dominance)

func _transition_to(new_state: ZoneState) -> void:
    current_state = new_state
    _state_timer = 0.0

func _setup_collision_radius() -> void:
    if collision_shape and collision_shape.shape is CircleShape2D:
        collision_shape.shape = collision_shape.shape.duplicate() as CircleShape2D
        (collision_shape.shape as CircleShape2D).radius = core_radius

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("register_zone"):
        body.call("register_zone", self)

func _on_body_exited(body: Node2D) -> void:
    if body.has_method("unregister_zone"):
        body.call("unregister_zone", self)
