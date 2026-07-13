class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent
@export var faction: String = "player"

## Длительность неуязвимости после получения удара.
## ВАЖНО: Установите 0.1 для ВРАГОВ и 0.5 для ИГРОКА в их сценах (Inspector).
@export var invulnerability_duration: float = 0.1

var _is_invulnerable: bool = false
var _invulnerability_timer: Timer

signal hit_received(damage: float)

func _ready() -> void:
    monitoring = true
    monitorable = true

    if health_component == null:
        var parent_name = get_parent().name if get_parent() != null else "unknown"
        print("[HURTBOX ERROR] Hurtbox on node '" + parent_name + "' has NO HealthComponent assigned!")

    if not area_entered.is_connected(_on_area_entered):
        area_entered.connect(_on_area_entered)

    # Инициализация таймера
    _invulnerability_timer = Timer.new()
    _invulnerability_timer.one_shot = true
    _invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
    add_child(_invulnerability_timer)

func _on_area_entered(area: Area2D) -> void:
    if _is_invulnerable:
        return

    var hitbox = area as HitboxComponent
    if not hitbox:
        return

    # Не бьем сами себя
    if hitbox.get_parent() == get_parent():
        return

    # Проверка фракций
    if hitbox.faction.to_lower() == faction.to_lower():
        return

    _apply_damage(hitbox.damage)

func _apply_damage(amount: float) -> void:
    if health_component == null or _is_invulnerable:
        return

    # 1. Сначала включаем неуязвимость
    if invulnerability_duration > 0:
        _is_invulnerable = true
        _invulnerability_timer.start(invulnerability_duration)

    # 2. Наносим урон через HealthComponent
    # Используем call_deferred для безопасности, если это смерть
    health_component.take_damage(amount)
    
    if is_inside_tree():
        hit_received.emit(amount)

func _on_invulnerability_timeout() -> void:
    _is_invulnerable = false

    # Проверяем, не стоим ли мы все еще в зоне поражения врага
    # (Например, если игрок стоит внутри врага)
    var overlapping_areas = get_overlapping_areas()
    for area in overlapping_areas:
        var hitbox = area as HitboxComponent
        if hitbox and hitbox.faction.to_lower() != faction.to_lower():
            if hitbox.get_parent() != get_parent():
                _apply_damage(hitbox.damage)
                break
