extends CharacterBody2D
class_name Player

# --- Сигналы ---
signal xp_changed(current_xp: int, next_level_xp: int)
signal level_up(new_level: int)

# --- Настройки базовых характеристик (Legion Architecture) ---
@export_group("Base Stats")
@export var base_mass: float = 100.0
@export var base_stability: float = 100.0

# --- Свойства движения и боя ---
@export_group("Movement & Combat")
@export var max_speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1500.0
@export var damage_multiplier: float = 1.0

# --- Сеттеры характеристик (Сохранены и типизированы) ---
@export var max_health: float = 100.0:
    set(value):
        max_health = value
        if is_instance_valid(health_component): # Безопасная проверка инициализации
            health_component.update_max_health(value)

@export var radius_weapons: float = 1.0:
    set(value):
        radius_weapons = value
        var weapons: Array[Node] = find_children("*", "WeaponComponent", true)
        for weapon in weapons:
            if weapon.has_method("update_weapon_range"):
                weapon.call("update_weapon_range", value)

@export var xp_radius: float = 1.0:
    set(value):
        xp_radius = value
        if is_instance_valid(magnet_area):
            var col_shape: CollisionShape2D = magnet_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
            if col_shape:
                col_shape.scale = Vector2.ONE * value

@export var xp_gain: float = 1.0

# --- Динамические характеристики (Legion Architecture) ---
var mass: float = 100.0
var stability: float = 100.0
var applied_zone_speed_modifier: float = 1.0
var active_zones: Array[Area2D] = []

# --- Характеристики уровня ---
var current_level: int = 1
var current_xp: int = 90
var xp_to_next_level: int = 100

# --- Ссылки на компоненты (Уникальные имена и строгая типизация) ---
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var polygon: Polygon2D = $Polygon2D
@onready var magnet_area: Area2D = %MagnetArea

func _ready() -> void:
    # Инициализация динамических параметров
    mass = base_mass
    stability = base_stability
    
    # Регистрация в группе
    add_to_group("player")
    
    # Подключение сигналов (Callable-синтаксис Godot 4)
    if health_component:
        health_component.health_depleted.connect(_on_death)
    if hurtbox_component:
        hurtbox_component.hit_received.connect(_on_hit_received)
    if magnet_area:
        magnet_area.area_entered.connect(_on_magnet_area_entered)

func _physics_process(delta: float) -> void:
    # 1. Сначала рассчитываем влияние зон на характеристики
    _process_zone_influences(delta)
    
    # 2. Затем выполняем движение с учетом нового модификатора скорости
    _move_player(delta)

# Логика движения (Сохранена оригинальная инерция движения)
func _move_player(delta: float) -> void:
    var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    
    if input_vector != Vector2.ZERO:
        velocity = velocity.move_toward(
            input_vector * max_speed * applied_zone_speed_modifier, 
            acceleration * delta
        )
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
    
    move_and_slide()

# Расчет влияния зон на игрока в реальном времени
func _process_zone_influences(delta: float) -> void:
    var speed_modifier: float = 1.0
    var mass_change: float = 0.0
    var stability_change: float = 0.0

    # Очищаем массив от удаленных зон (деспавн)
    active_zones = active_zones.filter(func(zone: Area2D) -> bool: return is_instance_valid(zone))

    for zone in active_zones:
        if not zone.has_method("get_influence_factor"):
            continue
            
        var influence: float = zone.get_influence_factor(global_position)
        var zone_type: String = zone.get("zone_type") if "zone_type" in zone else "Acceleration"
        
        match zone_type:
            "Acceleration":
                # Ускорение до +100% в центре
                speed_modifier += influence * 1.0
            "Pressure":
                # Давление снижает стабильность и массу
                stability_change -= influence * 15.0 * delta
                mass_change -= influence * 5.0 * delta
            "Stabilization":
                # Стабилизация восстанавливает параметры
                stability_change += influence * 10.0 * delta
                mass_change += influence * 8.0 * delta
            "Flux":
                # Хаотичные скачки скорости
                speed_modifier += (randf_range(-0.5, 1.5)) * influence

    # Применяем изменения
    applied_zone_speed_modifier = speed_modifier
    stability = clamp(stability + stability_change, 0.0, base_stability * 2.0)
    mass = max(10.0, mass + mass_change) # Масса не падает ниже 10.0

    # Динамическое изменение визуального масштаба игрока на основе его массы (Legion Architecture)
    var target_scale: float = clamp(mass / base_mass, 0.5, 2.0)
    scale = scale.lerp(Vector2.ONE * target_scale, 5.0 * delta)

    # Отладочный вывод раз в секунду
    if Engine.get_physics_frames() % 60 == 0 and not active_zones.is_empty():
        print("[PLAYER] Speed Mod: ", snapped(applied_zone_speed_modifier, 0.1), 
              " | Stability: ", snapped(stability, 0.1), 
              " | Mass: ", snapped(mass, 0.1))

# --- Вспомогательные методы регистрации зон (Совместимость с обоими подходами) ---
func register_zone(zone: Area2D) -> void:
    _on_zone_entered(zone)

func unregister_zone(zone: Area2D) -> void:
    _on_zone_exited(zone)

func _on_zone_entered(zone: Area2D) -> void:
    if is_instance_valid(zone) and not active_zones.has(zone):
        active_zones.append(zone)

func _on_zone_exited(zone: Area2D) -> void:
    if active_zones.has(zone):
        active_zones.erase(zone)

# --- Системные методы игрока (Сохранены без изменений) ---
func _on_death() -> void:
    GameManager.reset_game()
    get_tree().call_deferred("reload_current_scene")

func _on_hit_received(_damage: float) -> void:
    _flash_damage()

func _flash_damage() -> void:
    if is_instance_valid(polygon):
        polygon.modulate = Color.RED
        var tween: Tween = create_tween()
        tween.tween_property(polygon, "modulate", Color.WHITE, 0.15)

func _on_magnet_area_entered(area: Area2D) -> void:
    var gem: XPGem = area as XPGem
    if gem != null:
        gem.attract(self)

func collect_xp(amount: int) -> void:
    var final_amount: int = int(amount * xp_gain)
    current_xp += final_amount
    
    while current_xp >= xp_to_next_level:
        current_xp -= xp_to_next_level
        current_level += 1
        xp_to_next_level = int(xp_to_next_level * 1.5)
        level_up.emit(current_level)
    
    xp_changed.emit(current_xp, xp_to_next_level)
