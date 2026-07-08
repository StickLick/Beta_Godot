class_name WeaponComponent
extends Node2D

const SWING_SCALE_UP_DURATION: float = 0.1

@export var base_damage: float = 15.0
@export var attack_cooldown: float = 1.0
@export var rotation_offset_degrees: float = 0.0

@onready var detection_area: Area2D = $DetectionArea
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var visual_pivot: Node2D = $VisualPivot
@onready var hitbox: HitboxComponent = $VisualPivot/HitboxComponent

var player: Node2D

func _ready() -> void:
    # Инициализация ссылки на игрока
    player = get_tree().get_first_node_in_group("player")

    cooldown_timer.wait_time = attack_cooldown
    cooldown_timer.timeout.connect(_on_cooldown_timeout)

    hitbox.faction = "player"

    var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
    hitbox_shape.disabled = true

    visual_pivot.scale = Vector2.ZERO

    detection_area.monitoring = true
    detection_area.collision_mask = 4

    # Применяем настройки радиуса, если игрок уже существует
    if player and "radius_multiplier" in player:
        update_weapon_range(player.radius_multiplier)

    cooldown_timer.start()

# Функция обновления радиуса (вызывается из Player.gd)
func update_weapon_range(new_multiplier: float) -> void:
    # Если переменная player пуста, пробуем найти игрока еще раз
    if not player:
        player = get_tree().get_first_node_in_group("player")
        
    var detection_shape = detection_area.get_node_or_null("CollisionShape2D")
    if detection_shape:
        detection_shape.scale = Vector2.ONE * new_multiplier
    
    var hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
    if hitbox_shape:
        hitbox_shape.scale = Vector2.ONE * new_multiplier

func _get_closest_target() -> HurtboxComponent:
    var closest_target: HurtboxComponent = null
    var closest_distance_sq: float = INF

    for area: Area2D in detection_area.get_overlapping_areas():
        var hurtbox: HurtboxComponent = area as HurtboxComponent
        if hurtbox == null:
            continue

        if hurtbox.faction != "enemy":
            continue

        var distance_sq: float = global_position.distance_squared_to(hurtbox.global_position)
        if distance_sq < closest_distance_sq:
            closest_distance_sq = distance_sq
            closest_target = hurtbox

    return closest_target

func _on_cooldown_timeout() -> void:
    var target: HurtboxComponent = _get_closest_target()
    if target == null:
        cooldown_timer.start()
        return

    visual_pivot.look_at(target.global_position)
    visual_pivot.rotation += deg_to_rad(rotation_offset_degrees)
    _perform_swing()

func _perform_swing() -> void:
    # Динамически ищем игрока в момент удара, чтобы множитель всегда был актуальным
    var active_player = get_tree().get_first_node_in_group("player")
    
    var multiplier: float = 1.0
    if active_player and "damage_multiplier" in active_player:
        multiplier = active_player.damage_multiplier
    
    hitbox.damage = base_damage * multiplier

    var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
    hitbox_shape.disabled = false
    visual_pivot.scale = Vector2.ZERO

    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_property(visual_pivot, "scale", Vector2(1.8, 1.8), SWING_SCALE_UP_DURATION)
    tween.chain().tween_property(visual_pivot, "scale", Vector2.ZERO, SWING_SCALE_UP_DURATION)
    tween.chain().tween_callback(_on_swing_finished)

func _on_swing_finished() -> void:
    var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
    hitbox_shape.disabled = true
    cooldown_timer.start()
