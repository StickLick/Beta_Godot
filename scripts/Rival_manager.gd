extends Node
class_name RivalManager

enum Doctrine { EXPANSION, ECONOMY, MILITARIZATION }

var potency: float = 1.0
var current_doctrine: Doctrine = Doctrine.ECONOMY
var previous_doctrine: Doctrine = Doctrine.ECONOMY
var is_boosting_pressure: bool = false

var _strategic_timer: float = 0.0
var _tactical_timer: float = 0.0
var _global_timer: float = 0.0

var _strategic_interval: float = 1.5
var _tactical_interval: float = 75.0
var _global_interval: float = 7.5

var _doctrine_transition_timer: float = 0.0
const TRANSITION_DURATION: float = 10.0

var pressure_manager = null
var zone_system = null

func _ready() -> void:
    add_to_group("rival_manager")
    potency = randf_range(0.8, 1.2)
    _reset_strategic_timer(); _reset_tactical_timer(); _reset_global_timer()
    print("[RIVAL] ИИ Соперника запущен.")

func _process(delta: float) -> void:
    if GameManager.is_game_over: return

    if not zone_system: zone_system = get_tree().root.find_child("ZoneSystem", true, false)
    if not pressure_manager: pressure_manager = get_tree().root.find_child("PressureManager", true, false)

    if GameManager.current_anomaly == "HYPERDRIVE" and current_doctrine != Doctrine.ECONOMY:
        _force_doctrine(Doctrine.ECONOMY)

    _strategic_timer += delta; _tactical_timer += delta; _global_timer += delta
    
    if _strategic_timer >= _strategic_interval:
        _on_strategic_tick(); _reset_strategic_timer()
    if _tactical_timer >= _tactical_interval:
        _on_tactical_tick(); _reset_tactical_timer()
    if _global_timer >= _global_interval:
        _on_global_tick(); _reset_global_timer()

    if is_boosting_pressure and is_instance_valid(pressure_manager):
        pressure_manager.current_pressure_level += delta * 0.03 * potency
    if _doctrine_transition_timer > 0:
        _doctrine_transition_timer -= delta

func _force_doctrine(doc: Doctrine) -> void:
    previous_doctrine = current_doctrine
    current_doctrine = doc
    _doctrine_transition_timer = 0 
    is_boosting_pressure = (current_doctrine == Doctrine.MILITARIZATION)

func _on_global_tick() -> void:
    var camps = get_tree().get_nodes_in_group("camps")
    var p_count = 0; var r_count = 0
    for camp in camps:
        if not is_instance_valid(camp): continue
        if camp.alignment == 1: p_count += 1
        elif camp.alignment == 2: r_count += 1

    # Подсчёт шахт (новая система)
    for mine in get_tree().get_nodes_in_group("player_mines"):
        if is_instance_valid(mine): p_count += 1
    for mine in get_tree().get_nodes_in_group("rival_mines"):
        if is_instance_valid(mine): r_count += 1
    
    if r_count > p_count and is_instance_valid(pressure_manager):
        pressure_manager.current_pressure_level += 0.2

func _on_tactical_tick() -> void:
    if GameManager.get_meta("prod_mult") < 1.0: return 
    
    previous_doctrine = current_doctrine
    var options = [Doctrine.EXPANSION, Doctrine.ECONOMY, Doctrine.MILITARIZATION]
    options.erase(current_doctrine)
    current_doctrine = options.pick_random()
    _doctrine_transition_timer = TRANSITION_DURATION
    is_boosting_pressure = (current_doctrine == Doctrine.MILITARIZATION)

func _on_strategic_tick() -> void:
    var active_doc = current_doctrine
    if _doctrine_transition_timer > 0 and randf() < 0.5: active_doc = previous_doctrine
    
    match active_doc:
        Doctrine.EXPANSION: _execute_expansion()
        Doctrine.ECONOMY: _execute_economy()
        Doctrine.MILITARIZATION: _execute_militarization()

func _execute_expansion() -> void:
    # Единственный путь экспансии: захват нейтральных OreNode
    _try_capture_ore_node()


func _try_capture_ore_node() -> bool:
    ## Захват нейтрального рудного узла соперником.
    ## MVP-лимит: препятствует полному доминированию карты в ранней игре,
    ## но сохраняет экспансию и угрозу Соперника.
    var ore_nodes := get_tree().get_nodes_in_group("ore_nodes")
    if ore_nodes.is_empty():
        return false

    # Динамический лимит владения шахтами для Соперника.
    # При достижении лимита — пропускаем захват, продолжаем обычную работу (тики идут дальше).
    var mine_cap := _get_rival_mine_cap()
    if mine_cap >= 0:
        var rival_mine_count := 0
        for m in get_tree().get_nodes_in_group("rival_mines"):
            if is_instance_valid(m) and m.alignment == 2:
                rival_mine_count += 1
        if rival_mine_count >= mine_cap:
            _log("STRATEGIC", "EXPANSION - Rival at mine cap (%d/%d), waiting" % [rival_mine_count, mine_cap])
            return false

    var player := get_tree().get_first_node_in_group("player")
    var best_node: Node = null
    var best_dist := INF

    for ore in ore_nodes:
        if not is_instance_valid(ore):
            continue
        var d: float = 0.0
        if is_instance_valid(player):
            d = ore.global_position.distance_to(player.global_position)
        # Предпочитаем узлы подальше от игрока
        if d > best_dist or (best_node == null and d > 600.0):
            best_dist = d
            best_node = ore

    if best_node:
        _log("STRATEGIC", "EXPANSION - Rival capturing OreNode at distance: %dpx" % int(best_dist))
        if best_node.has_method("_on_captured"):
            best_node._on_captured(OreNode.Alignment.RIVAL)
        return true

    return false


func _get_rival_mine_cap() -> int:
    ## Динамический лимит числа шахт Соперника по времени забега.
    ## 0-5 мин: максимум 2; 5-10 мин: максимум 4; 10+ мин: без лимита (-1).
    var t := GameManager.time_elapsed
    if t < 300.0:
        return 2
    if t < 600.0:
        return 4
    return -1

func _execute_economy() -> void:
    # Улучшение вражеских шахт (новая система — приоритет).
    # Соперник следует той же экономике, что и игрок:
    #   - выбирать можно только шахту в READY (хранилище заполнено);
    #   - BUILDING-шахты пропускаются (стройка уже идёт);
    #   - start_construction() мгновенно потребляет ресурсы и переводит шахту в BUILDING,
    #     апгрейд применяется только по завершении строительства;
    #   - улучшаются только шахты под контролем соперника (rival_mines + alignment == 2).
    # Мета-фильтр: апгрейды шахт доступны только в пределах разблокированного
    # уровня шахты (MetaProgress.get_mine_level). Уровень 1 = только база без апгрейдов;
    # уровень N разрешает N-1 суммарных апгрейдов. Запертые апгрейды не попадают в пул выбора.
    var meta := get_node_or_null("/root/MetaProgress")
    var meta_max_upgrades: int = 999
    if meta and meta.has_method("get_mine_level"):
        meta_max_upgrades = int(meta.get_mine_level()) - 1
    var r_mines: Array = []
    for m in get_tree().get_nodes_in_group("rival_mines"):
        if not is_instance_valid(m):
            continue
        if m.alignment != 2:
            continue
        if not m.has_method("start_construction"):
            continue
        if m.state != m.MineState.READY:
            continue
        if m.total_upgrades_used() >= m.MAX_TOTAL_UPGRADES:
            continue
        if m.total_upgrades_used() >= meta_max_upgrades:
            continue
        r_mines.append(m)
    if r_mines.size() > 0:
        var target = r_mines.pick_random()
        var eco_available: bool = target.economic_level < target.MAX_ECONOMIC_LEVEL
        var mil_available: bool = target.military_level < target.MAX_MILITARY_LEVEL
        var branch: String = "economic"
        if eco_available and mil_available:
            branch = "military" if randf() > 0.5 else "economic"
        elif mil_available:
            branch = "military"
        # total_upgrades_used < MAX гарантирует хотя бы одну доступную ветку,
        # но страхуемся от пустого выбора.
        if eco_available or mil_available:
            target.start_construction(branch)
        return

    # Старая логика: улучшение лагерей
    var r_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.alignment == 2)
    if r_camps.size() > 0:
        var target = r_camps.pick_random()
        # ЗАМЕДЛЕНИЕ ЭКОНОМИКИ: теперь вливаем 12 массы вместо 45 за тик
        target.upgrade(12.0 * potency)

func _execute_militarization() -> void:
    if is_instance_valid(pressure_manager): 
        pressure_manager.current_pressure_level += 0.05

func _log(type: String, msg: String) -> void:
    var t = "%02d:%02d" % [int(GameManager.time_elapsed / 60), int(GameManager.time_elapsed) % 60]
    print("[%s][%s] %s" % [t, type, msg])

func _reset_strategic_timer() -> void: _strategic_timer = 0.0; _strategic_interval = randf_range(1.3, 1.8)
func _reset_tactical_timer() -> void: _tactical_timer = 0.0; _tactical_interval = randf_range(70.0, 85.0)
func _reset_global_timer() -> void: _global_timer = 0.0; _global_interval = randf_range(7.0, 9.0)
