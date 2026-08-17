extends CharacterBody2D
class_name Courier

## Курьер — самостоятельный юнит охоты (не связан с системой аномалий).
## После первого удара начинает убегать от игрока. Убийство даёт золото/XP.

signal died

@export var health: float = 100.0
@export var speed: float = 200.0        # итоговая скорость (см. формулу)
@export var gold_min: int = 200
@export var gold_max: int = 350
@export var xp_min: int = 150
@export var xp_max: int = 250

@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _player: Player = null
var _is_fleeing: bool = false           # после ПЕРВОГО удара = true
var _flee_dir: Vector2 = Vector2.ZERO   # фикс. направление побега (стабильный flip_h)
var _edge_reflect_cooldown: float = 0.0 # защита от осцилляции у края карты
var _wander_target: Vector2 = Vector2.ZERO
var _map_rect: Rect2 = Rect2(-2000, -2000, 4000, 4000)


func _ready() -> void:
    add_to_group("courier")
    # Легальная цель для систем, наводящихся по группе "enemy"
    # (знамя, лучники форта, юниты лагеря). Прямые оружия игрока и так
    # попадают через хёртбокс (faction=enemy, layer=8) — не затрагиваются.
    add_to_group("enemy")
    if is_instance_valid(health_component):
        health_component.health_depleted.connect(_on_death)
        # Поле health — единственный источник HP курьера.
        # Иначе правка @export health не влияет на фактическое HP:
        # реальное здоровье живёт в HealthComponent (max_health из Courier.tscn).
        health_component.max_health = health
        health_component.current_health = health
    # Подключение постоянное: guard "if not _is_fleeing" включает побег один раз,
    # а вспышка срабатывает при каждом попадании.
    if is_instance_valid(hurtbox):
        hurtbox.hit_received.connect(_on_first_hit)   # триггер первой атаки
    _player = get_tree().get_first_node_in_group("player")

    var meta := get_node_or_null("/root/MetaProgress")
    var meta_bonus := 0.0
    if meta and meta.has_method("get_hero_upgrade_level"):
        meta_bonus = float(meta.get_hero_upgrade_level("move_speed")) * 15.0
    speed = 200.0 + 0.5 * meta_bonus

    if GameManager.has_meta("map_rect"):
        _map_rect = GameManager.get_meta("map_rect")

    _wander_target = _random_map_point()
    print("[COURIER] spawned. speed=", speed, " meta_bonus=", meta_bonus)


func _physics_process(delta: float) -> void:
    if not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player")

    var dir: Vector2
    if _is_fleeing and is_instance_valid(_player):
        # Переназначение направления побега ТОЛЬКО у края карты, с кулдауном,
        # чтобы не осциллировать (не клинить) между «к краю» и «от края».
        if _edge_reflect_cooldown > 0.0:
            _edge_reflect_cooldown -= delta
        else:
            var edge_margin := 100.0
            var at_x_edge: bool = global_position.x < _map_rect.position.x + edge_margin or global_position.x > _map_rect.end.x - edge_margin
            var at_y_edge: bool = global_position.y < _map_rect.position.y + edge_margin or global_position.y > _map_rect.end.y - edge_margin
            if at_x_edge and not at_y_edge:
                # «Отражаем» направление относительно края и фиксируем.
                _flee_dir.x *= -1.0
                _edge_reflect_cooldown = 0.4
            elif at_y_edge and not at_x_edge:
                _flee_dir.y *= -1.0
                _edge_reflect_cooldown = 0.4
            elif at_x_edge and at_y_edge:
                # Угол: разворачиваем строго внутрь карты.
                _flee_dir = (Vector2(_map_rect.get_center()) - global_position).normalized()
                _edge_reflect_cooldown = 0.4
        dir = _flee_dir
    else:
        # Фаза патруля: бежит к случайной точке на карте.
        # _random_map_point() выбирает точку в безопасной зоне [pos+200, end-200],
        # поэтому инверсия у края не нужна.
        if global_position.distance_to(_wander_target) < 60.0:
            _wander_target = _random_map_point()
        dir = (global_position - _wander_target).normalized() * -1.0

    velocity = velocity.lerp(dir.normalized() * speed, delta * 10.0)
    move_and_slide()

    # flip_h по направлению движения
    if is_instance_valid(animated_sprite):
        if abs(dir.x) > 0.1:
            animated_sprite.flip_h = dir.x < 0
        animated_sprite.play("Run" if velocity.length() > 20 else "Idle")


func _on_first_hit(_dmg) -> void:
    # Диагностика уровня жизни при попадании.
    print("[COURIER] hp=", health_component.current_health, " fleeing=", _is_fleeing)
    # Триггер: после ПЕРВОЙ атаки курьер начинает убегать.
    if not _is_fleeing:
        _is_fleeing = true
        # Фиксируем направление побега один раз (с одним случайным отклонением).
        if is_instance_valid(_player):
            _flee_dir = (global_position - _player.global_position).normalized()
            _flee_dir = _flee_dir.rotated(randf_range(-0.785, 0.785))
    # Красная вспышка при КАЖДОМ попадании (обработчик оставлен постоянным).
    modulate = Color(1.0, 0.3, 0.3)
    var t := create_tween()
    t.tween_property(self, "modulate", Color.WHITE, 0.15)


func _on_death() -> void:
    if not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player")
    if is_instance_valid(_player):
        var gold_reward := int(randi_range(gold_min, gold_max))
        var xp_reward := int(randi_range(xp_min, xp_max))
        _player.collect_gold(gold_reward)
        _player.collect_xp(xp_reward)
        print("[COURIER] killed! gold=", gold_reward, " xp=", xp_reward)
    died.emit()
    queue_free()


func _random_map_point() -> Vector2:
    return Vector2(
        randf_range(_map_rect.position.x + 200, _map_rect.end.x - 200),
        randf_range(_map_rect.position.y + 200, _map_rect.end.y - 200)
    )
