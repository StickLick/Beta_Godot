extends CharacterBody2D

class_name Player
signal xp_changed(current_xp: int, next_level_xp: int)
signal level_up(new_level: int)

@export var max_speed: float = 250.0

@export var max_health: float = 100:
    set(value):
        max_health = value
        if health_component: # Проверяем, что компонент уже инициализирован
            health_component.update_max_health(value)
            
@export var acceleration: float = 1800.0
@export var friction: float = 1500.0
@export var damage_multiplier: float = 1.0

@export var radius_weapons: float = 1.0:
    set(value):
        radius_weapons = value
        var weapons = find_children("*", "WeaponComponent", true)
        for weapon in weapons:
            if weapon.has_method("update_weapon_range"):
                weapon.update_weapon_range(value)
                
@export var xp_radius: float = 1.0:
    set(value):
        xp_radius = value
        if magnet_area:
            # Увеличиваем масштаб коллизии магнита
            magnet_area.get_node("CollisionShape2D").scale = Vector2.ONE * value
            
@export var xp_gain: float = 1.0 # Добавь эту переменную к остальным экспортам

var current_level: int = 1
var current_xp: int = 90
var xp_to_next_level: int = 100

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var polygon: Polygon2D = $Polygon2D
@onready var magnet_area: Area2D = %MagnetArea


func _ready() -> void:
    add_to_group("player")
    health_component.health_depleted.connect(_on_death)
    hurtbox_component.hit_received.connect(_on_hit_received)
    magnet_area.area_entered.connect(_on_magnet_area_entered)


func _on_death() -> void:
    GameManager.reset_game()
    get_tree().call_deferred("reload_current_scene")


func _on_hit_received(damage: float) -> void:
    print("Player took %.1f damage" % damage)
    _flash_damage()


func _flash_damage() -> void:
    polygon.modulate = Color.RED
    var tween: Tween = create_tween()
    tween.tween_property(polygon, "modulate", Color.WHITE, 0.15)


func _on_magnet_area_entered(area: Area2D) -> void:
    var gem: XPGem = area as XPGem
    if gem != null:
        gem.attract(self)


func collect_xp(amount: int) -> void:
    # Умножаем полученное значение на наш множитель и приводим к целому числу
    var final_amount: int = int(amount * xp_gain)
    
    current_xp += final_amount

    while current_xp >= xp_to_next_level:
        current_xp -= xp_to_next_level
        current_level += 1
        xp_to_next_level = int(xp_to_next_level * 1.5)
        level_up.emit(current_level)
        print("[Player] LEVELED UP to Level ", current_level)

    xp_changed.emit(current_xp, xp_to_next_level)


func _physics_process(delta: float) -> void:
    var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

    if input_vector != Vector2.ZERO:
        velocity = velocity.move_toward(input_vector * max_speed, acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

    move_and_slide()
