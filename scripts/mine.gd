extends Area2D
class_name Mine
## Шахта — экономический объект, создаваемый при захвате OreNode.
## Единый источник истины владения: alignment (setter → _apply_ownership).
## Уровни 1-5, на уровне 3 выбор типа шахты (DEEP / FORTIFIED).
## FORTIFIED создаёт Outpost (в будущем).
## Визуалы настраиваются через Inspector.

signal upgrade_ready(mine: Mine)

enum Alignment { NEUTRAL = 0, PLAYER = 1, RIVAL = 2 }
enum MineState { PRODUCING = 0, READY = 1, BUILDING = 2 }

# -- Владение (ЕДИНСТВЕННЫЙ источник истины) --
@export var alignment: Alignment = Alignment.NEUTRAL:
    set(new_alignment):
        if new_alignment == alignment:
            return
        var old := alignment
        alignment = new_alignment
        if _ownership_ready:
            _apply_ownership(old, new_alignment)

# -- Захват (HP — единственный прогресс захвата) --

# -- Ресурсы --
@export var collection_radius: float = 250.0
var resources_accumulated: float = 0.0
var _player_nearby: bool = false
var state: MineState = MineState.PRODUCING
var construction_progress: float = 0.0
var pending_branch: String = ""
const CONSTRUCTION_TIME: float = 10.0

# -- Здоровье --
@export var max_health: float = 3000.0
var current_health: float = 3000.0
var _last_health: float = 0.0

# -- World UI (редактируемая сцена) --
const MINE_UI_SCENE := preload("res://Assets/UI/Mine/MineWorldUI.tscn")

# -- Внутренние --
var _ownership_ready: bool = false
var _mine_ui: Control = null
var _repair_cooldown: float = 0.0
# Фракция для damage-пайплайна (HitboxComponent). Только player/rival — нейтральных шахт нет.
var faction: String = "player"
# Состояние «под атакой» для map-индикатора (красный пульс).
var is_under_attack: bool = false
var _attack_flash_timer: float = 0.0
const ATTACK_FLASH_DURATION: float = 3.0

# -- НОВАЯ СИСТЕМА: двойное улучшение (экономика + военный) --
@export var economic_level: int = 1
@export var military_level: int = 0
# Устаревшие поля удалены: upgrade_readiness, is_upgrade_stalled → заменены state-машиной (MineState).

# -- Ссылка на аванпост (null если нет) --
var outpost: Node = null

# -- Группы --
const GROUP_ALL := "mines"
const GROUP_PLAYER := "player_mines"
const GROUP_RIVAL := "rival_mines"

# -- Константы --
const BASE_HEALTH: float = 3000.0
# Бонус скорости захвата за уровень игрока: +25% к базовому урону за каждый уровень выше 1.
const LEVEL_CAPTURE_BONUS: float = 0.25
# Стартовые уровни шахты: новая шахта = Lv.1 (экономика) без военной ветки.
const STARTING_ECONOMIC_LEVEL: int = 1
const STARTING_MILITARY_LEVEL: int = 0

# -- НОВАЯ СИСТЕМА: константы двойного улучшения --
const MAX_ECONOMIC_LEVEL: int = 3
const MAX_MILITARY_LEVEL: int = 3
const MAX_TOTAL_UPGRADES: int = 5
const HEALTH_PER_MIL_LEVEL: float = 2500.0
const STORAGE_BASE: float = 100.0
const STORAGE_PER_ECO_LEVEL: float = 50.0


func _ready() -> void:
    _update_groups()
    if is_instance_valid($CollisionShape2D):
        ($CollisionShape2D as CollisionShape2D).disabled = false
    else:
        var collision := CollisionShape2D.new()
        var circle := CircleShape2D.new()
        circle.radius = 120.0
        collision.shape = circle
        collision.name = "CollisionShape2D"
        add_child(collision)

    _mine_ui = MINE_UI_SCENE.instantiate()
    add_child(_mine_ui)
    # Позиция над шахтой: центр блока (90x62) сдвинут выше шахты.
    _mine_ui.position = Vector2(-45, -190)

    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    upgrade_ready.connect(_on_upgrade_ready_sfx)

    # Здоровье зависит ТОЛЬКО от military_level (через get_max_health).
    var initial_health := get_max_health()
    max_health = initial_health
    current_health = initial_health
    _last_health = initial_health

    _update_visuals()
    _update_faction()
    _ownership_ready = true


func _on_upgrade_ready_sfx(_mine: Mine) -> void:
    SoundManager.play(SoundManager.mine_ready_sound, SoundManager.mine_ready_volume_db, SoundManager.mine_ready_pitch)


func _process(delta: float) -> void:
    _handle_capture(delta)

    if _attack_flash_timer > 0.0:
        _attack_flash_timer -= delta
        if _attack_flash_timer <= 0.0:
            is_under_attack = false

    if alignment != Alignment.NEUTRAL:
        _generate_resources(delta)
        _process_construction(delta)
        _process_auto_repair(delta)

    _update_mine_ui()


# ── ЗАХВАТ ──

func _handle_capture(delta: float) -> void:
    var invaders := 0
    var p_inside := false
    var p_ref: Player = null
    var invader_alignment := -1

    for b in get_overlapping_bodies():
        if b is Player:
            p_inside = true
            p_ref = b
        elif b is Unit and b.alignment != 0:
            if invaders == 0:
                invader_alignment = b.alignment
            if b.alignment == invader_alignment:
                invaders += 1

    var current_alignment := int(alignment)

    # HP — единственный прогресс захвата. При 0 — передача владения тому, кто в зоне.
    if current_health <= 0.0:
        if p_inside and current_alignment != Alignment.PLAYER:
            _set_owner(Alignment.PLAYER)
        elif invaders >= 2 and invader_alignment != current_alignment:
            _set_owner(invader_alignment as Alignment)
        elif invaders > 0 and invader_alignment != current_alignment:
            _set_owner(invader_alignment as Alignment)
        return

    # Скорость захвата зависит ТОЛЬКО от прочности шахты (max_health).
    # Больше max_health → медленнее захват (множитель BASE_HEALTH / max_health).
    var durability_factor := BASE_HEALTH / max_health

    if invaders >= 2 and invader_alignment != current_alignment:
        current_health -= (invaders * 4.0) * durability_factor * delta
        _repair_cooldown = 5.0
    elif p_inside and current_alignment != Alignment.PLAYER:
        var p_bonus := float(p_ref.gold) / 100.0
        # Прогрессия игрока ускоряет захват: уровень 1 = базовый темп, выше — быстрее.
        var level_mult := 1.0 + (p_ref.current_level - 1) * LEVEL_CAPTURE_BONUS
        current_health -= (8.0 + p_bonus) * level_mult * durability_factor * delta
        _repair_cooldown = 5.0
    elif invaders > 0 and invader_alignment != current_alignment:
        current_health -= (invaders * 4.0) * durability_factor * delta
        _repair_cooldown = 5.0

    current_health = max(0.0, current_health)


# ── ЕДИНЫЙ МЕТОД СМЕНЫ ВЛАДЕЛЬЦА ──

func _set_owner(new_alignment: Alignment) -> void:
    if alignment == new_alignment:
        return
    alignment = new_alignment


# ── ОБРАБОТЧИК СМЕНЫ ВЛАДЕНИЯ (вызывается из setter) ──

func _apply_ownership(_old: Alignment, _new: Alignment) -> void:
    # При смене владельца шахта полностью сбрасывается в базовую Lv.1 для нового владельца.
    _reset_mine_progression()
    _update_groups()
    _update_visuals()
    _update_collision_layers()
    _update_faction()
    # Переподчиняем юнитов аванпоста
    if is_instance_valid(outpost) and outpost.has_method("flip_units"):
        outpost.flip_units(int(_new))


## Полный сброс прогрессии шахты при смене владельца.
## Новая шахта: экономика Lv.1, военная Lv.0, ресурсы очищены, HP по базовому военному уровню.
## Не касается player.gold/player.current_level/player upgrades.
func _reset_mine_progression() -> void:
    economic_level = STARTING_ECONOMIC_LEVEL
    military_level = STARTING_MILITARY_LEVEL
    resources_accumulated = 0.0
    state = MineState.PRODUCING
    construction_progress = 0.0
    pending_branch = ""

    max_health = get_max_health()
    current_health = max_health
    _last_health = max_health


func _update_groups() -> void:
    if not is_in_group(GROUP_ALL):
        add_to_group(GROUP_ALL)

    match alignment:
        Alignment.PLAYER:
            if not is_in_group(GROUP_PLAYER):
                add_to_group(GROUP_PLAYER)
            if is_in_group(GROUP_RIVAL):
                remove_from_group(GROUP_RIVAL)
        Alignment.RIVAL:
            if not is_in_group(GROUP_RIVAL):
                add_to_group(GROUP_RIVAL)
            if is_in_group(GROUP_PLAYER):
                remove_from_group(GROUP_PLAYER)
        _:
            if is_in_group(GROUP_PLAYER):
                remove_from_group(GROUP_PLAYER)
            if is_in_group(GROUP_RIVAL):
                remove_from_group(GROUP_RIVAL)


func _update_collision_layers() -> void:
    # Обновляем hurtbox если есть
    var hurtbox := get_node_or_null("HurtboxComponent")
    if is_instance_valid(hurtbox):
        match alignment:
            Alignment.PLAYER:
                hurtbox.faction = "player"
                hurtbox.collision_layer = 2
            Alignment.RIVAL:
                hurtbox.faction = "rival"
                hurtbox.collision_layer = 8
            _:
                hurtbox.faction = "neutral"
                hurtbox.collision_layer = 0


func _update_faction() -> void:
    match alignment:
        Alignment.PLAYER:
            faction = "player"
        Alignment.RIVAL:
            faction = "rival"
        _:
            faction = "player"  # нейтральных шахт нет: базовое состояние — player


# ── СИСТЕМА УРОНА (интеграция с HitboxComponent) ──

## Хук damage-пайплайна: вызывается HitboxComponent через deal_damage_to_area().
## Уменьшает current_health и прерывает авто-ремонт (cooldown).
## Владелец НЕ меняется при HP=0 — это отдельная система захвата (_handle_capture).
func _apply_damage(amount: float) -> void:
    if current_health <= 0.0:
        return
    current_health = max(0.0, current_health - amount)
    _repair_cooldown = 5.0
    # Взводим индикатор «под атакой» (красный пульс на карте).
    is_under_attack = true
    _attack_flash_timer = ATTACK_FLASH_DURATION
    # HP исчерпан прямым уроном (Breaker/Rival) — шахта переходит атакующей стороне (Rival).
    # Игрок-захват использует отдельный путь (_handle_capture), этот код её не касается.
    if current_health <= 0.0:
        _set_owner(Alignment.RIVAL)


# ── НОВАЯ СИСТЕМА: двойное улучшение ──

func total_upgrades_used() -> int:
    ## Возвращает количество потраченных стадий улучшения.
    ## economic_level начинается с 1 (не считается), military_level с 0.
    return (economic_level - 1) + military_level


func get_max_health() -> float:
    ## Вычисляет максимальное здоровье шахты.
    ## Зависит ТОЛЬКО от военной ветки.
    ## База 3000 + 2500 за каждый military_level.
    return BASE_HEALTH + HEALTH_PER_MIL_LEVEL * float(military_level)


func get_storage_capacity() -> float:
    ## Вычисляет объём хранилища ресурсов.
    ## Зависит ТОЛЬКО от экономической ветки.
    return STORAGE_BASE + STORAGE_PER_ECO_LEVEL * float(economic_level - 1)


func apply_upgrade(branch: String) -> void:
    ## Совместимость: HUD и RivalManager вызывают этот метод.
    ## В новой архитектуре «применить улучшение» = начать строительство.
    start_construction(branch)


func start_construction(branch: String) -> void:
    ## Начать строительство выбранной ветки.
    ## Мгновенно потребляет накопленные ресурсы и переводит шахту в BUILDING.
    ## Строительство идёт без присутствия игрока; по завершении применяется upgrade.
    if alignment == Alignment.NEUTRAL:
        return
    if total_upgrades_used() >= MAX_TOTAL_UPGRADES:
        return
    if state == MineState.BUILDING:
        return  # уже строится

    var branch_valid := false
    match branch:
        "economic":
            if economic_level < MAX_ECONOMIC_LEVEL:
                branch_valid = true
        "military":
            if military_level < MAX_MILITARY_LEVEL:
                branch_valid = true
        _:
            pass
    if not branch_valid:
        return

    # Потребляем накопленное хранилище как cost на строительство.
    resources_accumulated = 0.0
    pending_branch = branch
    construction_progress = 0.0
    state = MineState.BUILDING
    print("[MINE] Строительство начато: %s | eco=%d mil=%d" % [branch, economic_level, military_level])


func _process_construction(delta: float) -> void:
    ## Тик строительства. Не требует игрока рядом.
    if state != MineState.BUILDING:
        return
    construction_progress += delta / CONSTRUCTION_TIME
    if construction_progress >= 1.0:
        construction_progress = 0.0
        var branch := pending_branch
        pending_branch = ""
        match branch:
            "economic":
                economic_level += 1
                _apply_economic_upgrade()
            "military":
                military_level += 1
                _apply_military_upgrade()
        state = MineState.PRODUCING
        _update_visuals()
        print("[MINE] Строительство завершено: %s | eco=%d mil=%d total=%d health=%d" % [branch, economic_level, military_level, total_upgrades_used(), int(get_max_health())])


func collect_resources(player) -> void:
    ## Собрать накопленные ресурсы как золото и вернуть шахту в PRODUCING.
    if player and player.has_method("collect_gold"):
        player.collect_gold(int(resources_accumulated))
    resources_accumulated = 0.0
    state = MineState.PRODUCING
    construction_progress = 0.0
    pending_branch = ""


func collect_and_reset(player) -> void:
    ## Совместимость с HUD (кнопка «Забрать и продолжить»).
    collect_resources(player)


func _apply_economic_upgrade() -> void:
    ## Применяет эффекты экономического улучшения.
    ## Влияет только на: производство ресурсов, объём хранилища.
    ## НЕ влияет на здоровье и военные системы.
    print("[MINE] Экономический апгрейд: уровень %d, хранилище %d" % [economic_level, int(get_storage_capacity())])
    # Будущие эффекты: бонус к скорости генерации, разблокировка DEEP-типа и т.д.


func _apply_military_upgrade() -> void:
    ## Применяет эффекты военного улучшения.
    ## Влияет только на: здоровье, турели, юнитов-защитников.
    ## НЕ влияет на производство ресурсов.
    var new_health := get_max_health()
    max_health = new_health
    current_health = new_health
    _last_health = new_health
    print("[MINE] Военный апгрейд: уровень %d, здоровье %d" % [military_level, int(new_health)])



# ── АВАНПОСТ (заглушка на будущее) ──

func _create_outpost() -> void:
    ## Будет реализовано в будущем.
    ## Создаёт Outpost, привязанный к этой шахте.
    pass


# ── РЕСУРСЫ ──

func _generate_resources(delta: float) -> void:
    ## Генерация ресурсов: только в состоянии PRODUCING.
    ## При заполнении хранилища — переход в READY (производство останавливается).
    if alignment == Alignment.NEUTRAL:
        return
    if state != MineState.PRODUCING:
        return

    var rate := 0.8 * float(economic_level)
    resources_accumulated = minf(resources_accumulated + rate * delta, get_storage_capacity())

    if resources_accumulated >= get_storage_capacity():
        state = MineState.READY
        upgrade_ready.emit(self)
        print("[MINE] Хранилище заполнено → READY | eco=%d mil=%d" % [economic_level, military_level])


func get_collection_progress() -> float:
    ## Возвращает долю накопленных ресурсов (0-1) для UI/визуализации.
    ## Порог — объём хранилища, зависящий от economic_level.
    var threshold := get_storage_capacity()
    return clampf(resources_accumulated / threshold, 0.0, 1.0)


# ── АВТО-РЕМОНТ ──

func _update_mine_ui() -> void:
    ## Обновляет world-UI шахты: уровень, хранилище/строительство, HP-бар.
    if not is_instance_valid(_mine_ui):
        return
    _mine_ui.update_level(economic_level + military_level)

    if alignment == Alignment.RIVAL:
        _mine_ui.update_storage("")
    elif state == MineState.BUILDING:
        var pct := int(clampf(construction_progress, 0.0, 1.0) * 100.0)
        _mine_ui.update_storage("Строительство %d%%" % pct)
    else:
        _mine_ui.update_storage("%d/%d" % [int(resources_accumulated), int(get_storage_capacity())])

    _mine_ui.update_health(current_health, max_health)
    _mine_ui.set_visible_state(int(alignment))


func _process_auto_repair(delta: float) -> void:
    # Ремонт приостанавливается при наличии врагов ИЛИ захватчиков в зоне,
    # иначе авто-ремонт отменял бы HP-захват.
    # После capture-урона действует cooldown — ремонт срабатывает с задержкой.
    if _repair_cooldown > 0.0:
        _repair_cooldown = max(0.0, _repair_cooldown - delta)
    var has_hostiles := false
    for b in get_overlapping_bodies():
        if b is Enemy:
            has_hostiles = true
            break
        if b is Player and alignment != Alignment.PLAYER:
            has_hostiles = true
            break
        if b is Unit and b.alignment != 0 and b.alignment != alignment:
            has_hostiles = true
            break
    if not has_hostiles and _repair_cooldown <= 0.0 and current_health < max_health:
        current_health += max_health * 0.01 * delta
        current_health = minf(current_health, max_health)


# ── ВИЗУАЛЫ ──

func _update_visuals() -> void:
    var color := Color(0.7, 0.7, 0.7, 0.6)

    match alignment:
        Alignment.PLAYER:
            if military_level >= 1:
                color = Color(0.4, 0.5, 0.6, 0.8)  # Стальной — укреплённая (mil >= 1)
            else:
                color = Color(0.2, 0.5, 1.0, 0.7)  # Синий — стандартная игрока
        Alignment.RIVAL:
            color = Color(1.0, 0.2, 0.2, 0.7)  # Красный — враг
        _:
            color = Color(0.7, 0.7, 0.7, 0.6)  # Серый — нейтральная

    var visual_shape := get_node_or_null("Polygon2D")
    if is_instance_valid(visual_shape):
        (visual_shape as Polygon2D).color = color

    # FortSprite (военный аванпост) — виден только при military_level >= 1.
    # Текстура назначается вручную в Inspector (в сцене пустая).
    var fort := get_node_or_null("FortSprite")
    if is_instance_valid(fort):
        (fort as Sprite2D).visible = military_level >= 1

    # UpgradeVisuals — визуальный слой апгрейдов (eco/mil индикаторы).
    # Только обновление картинки по текущим уровням; геймплейная логика не затрагивается.
    # Позиции/цвета/формы редактируются в Inspector (MineUpgradeVisuals.tscn).
    var upgrade_visuals := get_node_or_null("UpgradeVisuals")
    if is_instance_valid(upgrade_visuals) and upgrade_visuals.has_method("update_levels"):
        upgrade_visuals.update_levels(economic_level, military_level)

    # MineWorldObjects — визуальные world-объекты (рабочие у руды, форт).
    # Позиции задаются Marker2D в редакторе; сцены назначаются в Inspector.
    # alignment передаётся, чтобы вражеские (Rival) шахты получали красного рабочего.
    var world_objects := get_node_or_null("MineWorldObjects")
    if is_instance_valid(world_objects) and world_objects.has_method("update_levels"):
        world_objects.update_levels(economic_level, military_level, int(alignment))


# ── СИГНАЛЫ ──

func _on_body_entered(body: Node2D) -> void:
    # Только player-шахта назначается как current_mine и может триггерить меню.
    # Враг/нейтралка не должны захватывать current_mine (иначе HUD/сбор сломаются).
    if body is Player and alignment == Alignment.PLAYER:
        body.current_mine = self
        # Повторный триггер: исходный emit мог произойти, пока игрок был далеко.
        # При входе в зону своей шахты в состоянии READY — эмитим снова.
        if state == MineState.READY:
            upgrade_ready.emit(self)


func _on_body_exited(body: Node2D) -> void:
    if not (body is Player and body.get("current_mine") == self):
        return
    body.current_mine = null
    # Фикс аудита: если игрок всё ещё физически находится в зоне другой
    # player-шахты (перекрывающиеся зоны), не оставляем current_mine пустым —
    # назначаем ту шахту, в зоне которой он остался.
    for m in get_tree().get_nodes_in_group("player_mines"):
        if m == self or not is_instance_valid(m):
            continue
        if body.global_position.distance_to(m.global_position) <= 120.0:
            body.current_mine = m
            if m.get("state") == m.MineState.READY:
                m.upgrade_ready.emit(m)
            break


# ── ХЕЛПЕРЫ ──

func is_player_aligned() -> bool:
    return alignment == Alignment.PLAYER


func reinforce() -> void:
    ## Минимальная совместимость с RivalBoss pulse.
    ## Увеличивает здоровье шахты (аналог camp.reinforce).
    current_health = minf(current_health + 1000.0, max_health)

func _make_hexagon(radius: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(6):
        var angle := deg_to_rad(60.0 * float(i) - 30.0)
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points

func is_rival_aligned() -> bool:
    return alignment == Alignment.RIVAL
