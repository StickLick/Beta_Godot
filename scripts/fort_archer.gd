extends ArcherPawnUnit
## Стационарная турель-защитник для форта шахты.
## Переиспользует полную боевую систему ArcherPawnUnit (стрельба, анимации, урон)
## и добавляет только стационарное поведение: lock позиции, поворот к цели, свой скан.
## Banner-арчер (PLAYER_FOLLOW) НЕ затрагивается.

enum ControlMode { PLAYER_FOLLOW, STATIC_TURRET }

@export var control_mode: ControlMode = ControlMode.STATIC_TURRET
@export var turret_range: float = 300.0
@export var turret_scan_interval: float = 0.2
@export var turret_fire_interval: float = 1.0

# -- Масштабирование от уровня форта (настраивается в Inspector) --
# Базовые статы уровня 1 (совпадают с прежним поведением турели).
@export var base_damage: float = 10.0
@export var base_range: float = 300.0
@export var base_attack_cooldown: float = 1.0

# Прирост за каждый уровень форта (уровень 2 и выше).
@export var damage_per_level: float = 5.0
@export var range_per_level: float = 40.0
@export var cooldown_reduction_per_level: float = 0.12
# Нижний предел кулдауна, чтобы он не стал нулевым/отрицательным.
@export var min_attack_cooldown: float = 0.3

## Текущий уровень форта (1 = базовые статы). Задаётся из MineWorldObjects.
var fort_level: int = 1
## Актуальный урон стрелы после пересчёта по уровню форта.
var _current_arrow_damage: float = 10.0

## Флаг «защитник здания»: враги игнорируют этот юнит при выборе целей.
## Banner-арчер (ArcherPawnUnit) этого флага НЕ имеет — остаётся атакуемым.
var is_fort_defender: bool = true

var _scan_timer: float = 0.0
var _fire_timer: float = 0.0
var _current_turret_target: Node2D = null
var _spawn_pos: Vector2 = Vector2.ZERO
var _pos_locked: bool = false


func _ready() -> void:
    super._ready()
    _recalc_stats()


## Задаёт уровень форта и мгновенно пересчитывает статы турели.
## Вызывается MineWorldObjects при спавне и при каждом изменении military_level.
func set_fort_level(level: int) -> void:
    fort_level = maxi(1, level)
    _recalc_stats()


func _recalc_stats() -> void:
    ## Пересчёт статов из exported базовых значений и приростов за уровень.
    ## Уровень 1 = базовые статы. Значения не хардкодятся в боевом коде.
    var level_bonus := float(fort_level - 1)
    _current_arrow_damage = base_damage + damage_per_level * level_bonus
    turret_range = maxf(base_range + range_per_level * level_bonus, 1.0)
    turret_fire_interval = maxf(
        base_attack_cooldown - cooldown_reduction_per_level * level_bonus,
        min_attack_cooldown
    )


func _spawn_arrow(angle: float, banner: WarBanner) -> void:
    ## Турель (banner == null) стреляет стрелой с уроном, пересчитанным
    ## по уровню форта. Используется та же сцена стрелы ARROW_SCENE —
    ## новая боевая система не создаётся.
    ## Banner-лучники (banner != null) идут в родительскую логику
    ## ArcherPawnUnit без изменений.
    if is_instance_valid(banner):
        super._spawn_arrow(angle, banner)
        return
    var arrow = ARROW_SCENE.instantiate() as Arrow
    if not arrow:
        return
    arrow.damage = _current_arrow_damage
    arrow.pierce_limit = 1
    # Фракция стрелы зависит от фракции турели: свои (1) — "player", враг (2) — "rival".
    var f_name: String = "player" if alignment == 1 else "rival"
    arrow.faction = f_name
    arrow.global_position = global_position
    arrow.rotation = angle
    get_tree().current_scene.add_child(arrow)
    SoundManager.play(SoundManager.shoot_bow_sound, SoundManager.shoot_bow_volume_db, SoundManager.shoot_bow_pitch * randf_range(0.96, 1.04))


func _attach_squad_ai() -> void:
    ## STATIC_TURRET: не вешаем SquadAI — движение/навигация отключены.
    if control_mode == ControlMode.STATIC_TURRET:
        return
    super._attach_squad_ai()


func _force_damage_test() -> void:
    ## STATIC_TURRET: отключаем debug-self-damage из PawnUnit.
    if control_mode == ControlMode.STATIC_TURRET:
        return
    super._force_damage_test()


func _physics_process(delta: float) -> void:
    if control_mode == ControlMode.STATIC_TURRET:
        _tick_turret(delta)
        return
    super._physics_process(delta)


func _on_animation_finished() -> void:
    ## STATIC_TURRET: после атаки возвращаемся в Idle, не в Run.
    if control_mode == ControlMode.STATIC_TURRET:
        if animated_sprite.animation in ["Attack", "Attack1"]:
            is_attacking = false
        _idle_anim()
        return
    super._on_animation_finished()


func _tick_turret(delta: float) -> void:
    # Жёсткий lock позиции: арчер никогда не сходит с башни.
    if not _pos_locked:
        _spawn_pos = global_position
        _pos_locked = true
    global_position = _spawn_pos
    velocity = Vector2.ZERO

    # Периодический скан целей.
    _scan_timer -= delta
    if _scan_timer <= 0.0:
        _scan_timer = turret_scan_interval
        _current_turret_target = _find_turret_target()
        if not is_instance_valid(_current_turret_target):
            _current_turret_target = null
            _idle_anim()

    # Только вращение к цели — никакого движения.
    if is_instance_valid(_current_turret_target):
        _rotate_toward_target(_current_turret_target)

    # Стрельба существующей боевой системой арчера (стрелы/анимации/урон).
    _fire_timer -= delta
    if is_instance_valid(_current_turret_target) and _fire_timer <= 0.0:
        _fire_timer = turret_fire_interval
        _play_sequential_attack(_current_turret_target, null)

    move_and_slide()


func _find_turret_target() -> Node2D:
    ## Скан целей по фракции турели.
    ## Своя турель (alignment == 1): группа "enemy" + враждебные юниты (rival).
    ## Вражеская турель (alignment == 2): игрок + союзные юниты (alignment == 1).
    ## Приоритет опасным целям (BREAKER) — паттерн из mine.gd._find_turret_target.
    var targets: Array = []
    if alignment == 1:
        targets.append_array(get_tree().get_nodes_in_group("enemy"))
        var hostile_units: Array = get_tree().get_nodes_in_group("units").filter(
            func(u): return is_instance_valid(u) and u.alignment == 2
        )
        targets.append_array(hostile_units)
    else:
        var player := get_tree().get_first_node_in_group("player")
        if is_instance_valid(player):
            targets.append(player)
        var ally_units: Array = get_tree().get_nodes_in_group("ally_units").filter(
            func(u): return is_instance_valid(u)
        )
        targets.append_array(ally_units)

    # Приоритет BREAKER, если таковые есть в радиусе.
    var priority: Array = targets.filter(
        func(t): return is_instance_valid(t) and t is Enemy and t.current_archetype == Enemy.Archetype.BREAKER
    )
    var final_targets: Array = priority if not priority.is_empty() else targets

    var closest: Node2D = null
    var min_d := turret_range
    for t in final_targets:
        if is_instance_valid(t):
            var d: float = global_position.distance_to(t.global_position)
            if d < min_d:
                min_d = d
                closest = t
    return closest


func _rotate_toward_target(target: Node2D) -> void:
    ## Только горизонтальное отражение спрайта (как персонаж):
    ## цель справа — нормальный вид, слева — flip_h.
    ## Без полного вращения, без вращения по Y. Хитбоксы не затрагиваются.
    if not is_instance_valid(animated_sprite) or not is_instance_valid(target):
        return
    var dir := target.global_position - global_position
    if dir.x != 0.0:
        animated_sprite.flip_h = dir.x < 0.0


func _idle_anim() -> void:
    if is_attacking or not is_instance_valid(animated_sprite):
        return
    if animated_sprite.sprite_frames.has_animation("Idle") and animated_sprite.animation != "Idle":
        animated_sprite.play("Idle")
