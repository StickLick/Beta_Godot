class_name WeaponComponent
extends Node2D

signal weapon_maxed(name: String)

@export_group("Identity")
@export var weapon_name: String = "Spear"
@export var current_level: int = 1
@export var max_level: int = 8

@export_group("Stats")
@export var base_damage: float = 15.0
@export var attack_cooldown: float = 1.0:
    set(value):
        attack_cooldown = max(0.05, value)
        if is_instance_valid(cooldown_timer):
            cooldown_timer.wait_time = attack_cooldown

@export_group("Animation Settings")
@export var attack_lunge_distance: float = 90.0 # Дистанция вылета
@export var attack_speed: float = 0.08           # Скорость (чем меньше, тем резче)

@onready var detection_area: Area2D = $DetectionArea
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var visual_pivot: Node2D = $VisualPivot
@onready var spear_mesh: Node2D = $VisualPivot/Polygon2D 
@onready var particles: GPUParticles2D = find_child("GPUParticles2D", true)
@onready var hitbox: HitboxComponent = find_child("HitboxComponent", true)

var player: Player

func _ready() -> void:
    player = get_parent() as Player
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
    
    # Начальное состояние: копье невидимо и не искрит
    if is_instance_valid(spear_mesh):
        spear_mesh.position.x = 0
        spear_mesh.modulate.a = 0
    
    if is_instance_valid(particles):
        particles.emitting = false
        
    if is_instance_valid(cooldown_timer):
        cooldown_timer.timeout.connect(_on_cooldown_timeout)
        cooldown_timer.start(attack_cooldown)

func _on_cooldown_timeout() -> void:
    var target = _get_closest_target()
    if target == null:
        cooldown_timer.start(0.2)
        return

    visual_pivot.look_at(target.global_position)
    
    if is_instance_valid(player) and player.has_method("play_attack_animation"):
        player.play_attack_animation(target.global_position)
        
    _perform_lunge()

func _perform_lunge() -> void:
    if not is_instance_valid(spear_mesh): return
    
    # Включаем урон
    var multiplier = player.get_final_damage_multiplier() if is_instance_valid(player) else 1.0
    if is_instance_valid(hitbox):
        hitbox.damage = base_damage * multiplier
        hitbox.faction = "player"
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape: shape.disabled = false

    # --- ЗАПУСК АНИМАЦИИ ---
    var tween = create_tween().set_parallel(false)
    
    # 1. Перед самым выпадом включаем частицы
    if is_instance_valid(particles):
        particles.emitting = true
        particles.restart() # Сбрасываем старые частицы, чтобы не было "шлейфа из-за спины"

    # 2. Резкий удар вперед
    tween.tween_property(spear_mesh, "position:x", attack_lunge_distance, attack_speed).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(spear_mesh, "modulate:a", 1.0, attack_speed)
    
    # 3. Короткая пауза
    tween.tween_interval(0.05)
    
    # 4. Возврат назад и ВЫКЛЮЧЕНИЕ частиц
    var return_tween = tween.tween_property(spear_mesh, "position:x", 0.0, attack_speed * 2.5).set_trans(Tween.TRANS_SINE)
    tween.parallel().tween_property(spear_mesh, "modulate:a", 0.0, attack_speed * 2.5)
    
    # Как только копье начало возвращаться — выключаем искры
    return_tween.finished.connect(func(): if is_instance_valid(particles): particles.emitting = false)
    
    tween.finished.connect(_on_attack_finished)

func _on_attack_finished() -> void:
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape: shape.disabled = true
    cooldown_timer.start(attack_cooldown)

# --- Остальные методы без изменений ---
func level_up() -> void:
    if current_level >= max_level: return
    current_level += 1
    if current_level in [2, 4, 6]: attack_cooldown *= 0.8
    if current_level in [3, 5, 7]: base_damage *= 1.2
    if current_level == max_level: weapon_maxed.emit(weapon_name)

func _get_closest_target() -> Area2D:
    var closest_target: Area2D = null
    var closest_distance_sq: float = INF
    if not is_instance_valid(detection_area): return null
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage"):
            if area.get("faction") == "player": continue
            var distance_sq = global_position.distance_squared_to(area.global_position)
            if distance_sq < closest_distance_sq:
                closest_distance_sq = distance_sq
                closest_target = area
    return closest_target

func update_weapon_range(new_range_mult: float) -> void:
    if is_instance_valid(detection_area):
        detection_area.scale = Vector2.ONE * new_range_mult
