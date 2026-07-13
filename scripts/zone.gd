#class_name Zone extends Area2D
#
## --- Состояния жизненного цикла ---
#enum ZoneState { SPAWN, GROWTH, ACTIVE, DECAY, DESPAWN }
#
## --- Свойства зоны по архитектуре LEGION ---
#@export_group("LEGION Properties")
#@export_enum("Acceleration", "Stabilization", "Pressure", "Flux") var zone_type: String = "Acceleration"
#@export var zone_mass: float = 100.0
#@export var core_radius: float = 120.0 
#@export var soft_influence_radius: float = 250.0 
#@export var dominance: float = 1.0 
#@export var growth_rate: float = 15.0 
#@export var absorb_rate: float = 5.0 
#
## --- Ресурсы (Новое) ---
#@export var resource_scene: PackedScene
#@export var base_spawn_cooldown: float = 4.0
#var _spawn_timer: float = 0.0
#
#var local_influence_multiplier: float = 1.0
#var current_state: ZoneState = ZoneState.SPAWN
#var _state_timer: float = 0.0
#
#const SPAWN_DURATION: float = 1.0
#const GROWTH_DURATION: float = 2.0
#const ACTIVE_DURATION: float = 10.0
#const DECAY_DURATION: float = 4.0
#
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#
#func _ready() -> void:
    #add_to_group("zones")
    #body_entered.connect(_on_body_entered)
    #body_exited.connect(_on_body_exited)
    #_setup_visuals()
    #_setup_collision_radius()
#
#func _process(delta: float) -> void:
    #_update_lifecycle(delta)
    #_handle_resource_spawning(delta)
#
## --- Логика ресурсов ---
#func _handle_resource_spawning(delta: float) -> void:
    #if zone_type == "Stabilization" and current_state == ZoneState.ACTIVE and resource_scene:
        #var dynamic_cooldown: float = base_spawn_cooldown / clamp(dominance, 0.2, 5.0)
        #_spawn_timer += delta
        #if _spawn_timer >= dynamic_cooldown:
            #_spawn_timer = 0.0
            #_spawn_resource()
#
#func _spawn_resource() -> void:
    #var resource_instance: Node2D = resource_scene.instantiate() as Node2D
    #var angle: float = randf() * TAU
    #var distance: float = randf() * core_radius
    #resource_instance.global_position = global_position + Vector2(cos(angle), sin(angle)) * distance
    #get_parent().add_child(resource_instance)
#
## --- Логика влияния ---
#func get_influence_factor(player_pos: Vector2) -> float:
    #var distance: float = global_position.distance_to(player_pos)
    #return clamp(1.0 - (distance / (core_radius * dominance)), 0.0, 1.0)
#
## --- Визуализация и жизненный цикл ---
#func _setup_visuals() -> void:
    #match zone_type:
        #"Acceleration": modulate = Color.CYAN
        #"Stabilization": modulate = Color.GREEN
        #"Pressure": modulate = Color.RED
        #"Flux": modulate = Color.YELLOW
#
#func _update_lifecycle(delta: float) -> void:
    #_state_timer += delta
    #var lifecycle_scale: float = 1.0
    #match current_state:
        #ZoneState.SPAWN:
            #lifecycle_scale = 0.1
            #if _state_timer >= SPAWN_DURATION: _transition_to(ZoneState.GROWTH)
        #ZoneState.GROWTH:
            #lifecycle_scale = lerp(0.1, 1.0, _state_timer / GROWTH_DURATION)
            #if _state_timer >= GROWTH_DURATION: _transition_to(ZoneState.ACTIVE)
        #ZoneState.ACTIVE:
            #lifecycle_scale = 1.0
            #if _state_timer >= ACTIVE_DURATION: _transition_to(ZoneState.DECAY)
        #ZoneState.DECAY:
            #lifecycle_scale = lerp(1.0, 0.0, _state_timer / DECAY_DURATION)
            #modulate.a = lerp(1.0, 0.0, _state_timer / DECAY_DURATION)
            #if _state_timer >= DECAY_DURATION: _transition_to(ZoneState.DESPAWN)
        #ZoneState.DESPAWN:
            #queue_free()
            #return
    #scale = Vector2.ONE * (lifecycle_scale * dominance)
#
#func _transition_to(new_state: ZoneState) -> void:
    #current_state = new_state
    #_state_timer = 0.0
#
#func _setup_collision_radius() -> void:
    #if collision_shape and collision_shape.shape is CircleShape2D:
        #collision_shape.shape = collision_shape.shape.duplicate() as CircleShape2D
        #(collision_shape.shape as CircleShape2D).radius = core_radius
#
#func _on_body_entered(body: Node2D) -> void:
    #if body.has_method("register_zone"): body.call("register_zone", self)
#
#func _on_body_exited(body: Node2D) -> void:
    #if body.has_method("unregister_zone"): body.call("unregister_zone", self)
#


class_name Zone extends Area2D

# --- Состояния жизненного цикла ---
enum ZoneState { SPAWN, GROWTH, ACTIVE, DECAY, DESPAWN }

# --- Свойства зоны по архитектуре LEGION ---
@export_group("LEGION Properties")
@export_enum("Acceleration", "Stabilization", "Pressure", "Flux") var zone_type: String = "Acceleration"
@export var zone_mass: float = 100.0
@export var core_radius: float = 120.0 
@export var soft_influence_radius: float = 250.0 
@export var dominance: float = 1.0 
@export var growth_rate: float = 15.0 
@export var absorb_rate: float = 5.0 

# --- Ресурсы ---
@export var resource_scene: PackedScene
@export var base_spawn_cooldown: float = 4.0
var _spawn_timer: float = 0.0

var local_influence_multiplier: float = 1.0
var current_state: ZoneState = ZoneState.SPAWN
var _state_timer: float = 0.0

const SPAWN_DURATION: float = 1.0
const GROWTH_DURATION: float = 2.0
const ACTIVE_DURATION: float = 10.0
const DECAY_DURATION: float = 4.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    add_to_group("zones")
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _setup_visuals()
    _setup_collision_radius()

func _process(delta: float) -> void:
    _update_lifecycle(delta)
    _handle_resource_spawning(delta)
    # Перерисовываем каждый кадр для плавной анимации пульсации и дрожания Flux-зоны
    queue_redraw()

# --- Логика ресурсов ---
func _handle_resource_spawning(delta: float) -> void:
    if zone_type == "Stabilization" and current_state == ZoneState.ACTIVE and resource_scene:
        var dynamic_cooldown: float = base_spawn_cooldown / clamp(dominance, 0.2, 5.0)
        _spawn_timer += delta
        if _spawn_timer >= dynamic_cooldown:
            _spawn_timer = 0.0
            _spawn_resource()

func _spawn_resource() -> void:
    var resource_instance: Node2D = resource_scene.instantiate() as Node2D
    var angle: float = randf() * TAU
    var distance: float = randf() * core_radius
    resource_instance.global_position = global_position + Vector2(cos(angle), sin(angle)) * distance
    get_parent().add_child(resource_instance)

# --- Логика влияния ---
func get_influence_factor(player_pos: Vector2) -> float:
    var distance: float = global_position.distance_to(player_pos)
    var current_radius: float = core_radius * scale.x
    if current_radius <= 0.0:
        return 0.0
    return clampf(1.0 - (distance / current_radius), 0.0, 1.0)

# --- Визуализация и жизненный цикл ---
func _setup_visuals() -> void:
    match zone_type:
        "Acceleration": modulate = Color.CYAN
        "Stabilization": modulate = Color.GREEN
        "Pressure": modulate = Color.RED
        "Flux": modulate = Color.WHITE # Белый модулятор, чтобы не перебивать цвета в _draw()

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
            
            # Уникальное поведение для FLUX зоны в активном состоянии
            if zone_type == "Flux":
                # Хаотичное изменение dominance каждый кадр
                dominance += randf_range(-0.1, 0.1) * delta
                dominance = clampf(dominance, 0.5, 1.5)
                
            if _state_timer >= ACTIVE_DURATION: _transition_to(ZoneState.DECAY)
        ZoneState.DECAY:
            lifecycle_scale = lerp(1.0, 0.0, _state_timer / DECAY_DURATION)
            modulate.a = lerp(1.0, 0.0, _state_timer / DECAY_DURATION)
            if _state_timer >= DECAY_DURATION: _transition_to(ZoneState.DESPAWN)
        ZoneState.DESPAWN:
            queue_free()
            return
            
    # Рассчитываем пульсацию для Flux зоны
    var pulse: float = 1.0
    if zone_type == "Flux" and current_state == ZoneState.ACTIVE:
        pulse = 1.0 + sin(_state_timer * 5.0) * 0.15
        
    scale = Vector2.ONE * (lifecycle_scale * dominance * pulse)

func _transition_to(new_state: ZoneState) -> void:
    current_state = new_state
    _state_timer = 0.0

func _setup_collision_radius() -> void:
    if collision_shape and collision_shape.shape is CircleShape2D:
        collision_shape.shape = collision_shape.shape.duplicate() as CircleShape2D
        (collision_shape.shape as CircleShape2D).radius = core_radius

func _draw() -> void:
    # Отрисовка уникальных визуальных эффектов для Flux зоны
    if zone_type == "Flux":
        # Внутренняя полупрозрачная фиолетовая область
        draw_circle(Vector2.ZERO, core_radius, Color(0.6, 0.1, 0.8, 0.2))
        
        # Внешнее тонкое дрожащее кольцо
        var jitter_radius: float = core_radius * (1.0 + randf_range(-0.03, 0.03))
        draw_arc(Vector2.ZERO, jitter_radius, 0.0, TAU, 64, Color(0.8, 0.2, 1.0, 0.7), 1.5)

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("register_zone"): body.call("register_zone", self)

func _on_body_exited(body: Node2D) -> void:
    if body.has_method("unregister_zone"): body.call("unregister_zone", self)
