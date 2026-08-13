extends Node

signal anomaly_started(type: String, duration: float)
signal anomaly_warning(time_left: float)
signal anomaly_ended()
signal run_ended(victory: bool, reward: int, breakdown: Dictionary)

# --- ТЕСТОВАЯ НАСТРОЙКА ---
const DEBUG_TEST_ANOMALY: String = "" 

var total_xp_collected: int = 0
var rival_camps_destroyed: int = 0
var units_spawned: int = 0
var zones_captured: int = 0
var time_elapsed: float = 0.0
var enemies_killed: int = 0
var resources_collected: int = 0
var mines_captured: int = 0
var gold_collected: int = 0

# --- МЕТА-ПРОГРЕССИЯ (персистентная, переживает смену сцен) ---
var _meta_currency: int = 0
var _run_reward_calculated: bool = false

# --- ВЫБОР ГЕРОЯ (сохраняется между забегами; меняется только в HeroSelectScreen) ---
var selected_hero_id: String = ""

var is_game_over: bool = false
var map_rect: Rect2 = Rect2(-2000, -2000, 4000, 4000)

var _check_timer: float = 0.0
const CHECK_INTERVAL: float = 40.0 
var current_chance: float = 0.20   
const CHANCE_STEP: float = 0.15    

var current_anomaly: String = "" 
const ANOMALY_DURATION: float = 40.0 
const WARNING_TIME: float = 5.0

# --- НАГРАДА ЗА ЗАБЕГ (настраивается в Inspector на GameManager) ---
@export_group("Run Reward")
@export var kill_gold_value: float = 1.0
@export var victory_bonus: int = 200

const ANOMALY_NAMES = {
    "HUNT": "ПРИКАЗ: ОХОТА",
    "SEIZE": "ПРИКАЗ: ЗАХВАТ",
    "COLLAPSE": "АНОМАЛИЯ: КОЛЛАПС РЕАЛЬНОСТИ",
    "INERTIA": "АНОМАЛИЯ: ИНЕРЦИЯ",
    "GRAVITY": "АНОМАЛИЯ: ГРАВИТАЦИЯ",
    "DEFICIT": "АНОМАЛИЯ: ДЕФИЦИТ",
    "ABUNDANCE": "АНОМАЛИЯ: ИЗОБИЛИЕ",
    "FEAST": "АНОМАЛИЯ: ТЕНЕВОЙ ПИР",
    "HYPERDRIVE": "АНОМАЛИЯ: ГИПЕРДРАЙВ"
}

func _ready() -> void:
    _reset_metas()
    set_meta("map_rect", map_rect)
    var save_manager := get_node_or_null("/root/SaveManager")
    if save_manager and save_manager.has_method("get_value"):
        _meta_currency = int(save_manager.get_value("meta_currency", 0))

func _reset_metas() -> void:
    set_meta("prod_mult", 1.0)
    set_meta("xp_mult", 1.0)
    set_meta("enemy_stat_mult", 0.8) 
    set_meta("scarcity_active", false)
    set_meta("inertia_active", false)
    set_meta("shadow_feast_active", false)
    set_meta("shadow_feast_vision_range", 0.0)

func _process(delta: float) -> void:
    if not is_game_over:
        time_elapsed += delta
        _process_anomaly_logic(delta)

func _process_anomaly_logic(delta: float) -> void:
    if current_anomaly != "": return 
    _check_timer += delta
    if _check_timer >= CHECK_INTERVAL:
        _check_timer = 0.0
        if DEBUG_TEST_ANOMALY != "" or randf() < current_chance:
            trigger_anomaly()
            current_chance = 0.20 
        else:
            current_chance += CHANCE_STEP 

func trigger_anomaly() -> void:
    var pool = ["HUNT", "SEIZE", "COLLAPSE", "INERTIA", "GRAVITY", "DEFICIT", "ABUNDANCE", "FEAST", "HYPERDRIVE"]
    current_anomaly = DEBUG_TEST_ANOMALY if DEBUG_TEST_ANOMALY != "" else pool.pick_random()
    
    match current_anomaly:
        "HUNT": set_meta("enemy_stat_mult", 1.2)
        "SEIZE": _mark_camps_for_seize()
        "COLLAPSE": _spawn_safe_zone()
        "INERTIA": set_meta("inertia_active", true)
        "GRAVITY": _spawn_gravity_wells_globally()
        "DEFICIT": set_meta("scarcity_active", true); set_meta("xp_mult", 2.0)
        "ABUNDANCE": set_meta("prod_mult", 0.5); set_meta("enemy_stat_mult", 1.1)
        "FEAST": 
            set_meta("shadow_feast_active", true)
            # УМЕНЬШЕНО: 0.07 - это очень узкий обзор, идеально для мобилок
            set_meta("shadow_feast_vision_range", 0.07)
            set_meta("xp_mult", 3.0)
        "HYPERDRIVE": Engine.time_scale = 1.4
    
    var display_name = ANOMALY_NAMES.get(current_anomaly, current_anomaly)
    anomaly_started.emit(display_name, ANOMALY_DURATION)
    
    var tree = get_tree()
    if tree:
        tree.create_timer(ANOMALY_DURATION - WARNING_TIME).timeout.connect(func():
            anomaly_warning.emit(WARNING_TIME)
        )
        tree.create_timer(ANOMALY_DURATION).timeout.connect(_end_anomaly)

func _end_anomaly() -> void:
    _check_timer = 0.0
    var tree = get_tree()
    if not tree: return
    if current_anomaly == "HYPERDRIVE": Engine.time_scale = 1.0
    for c in tree.get_nodes_in_group("camps"): 
        if is_instance_valid(c): c.set_meta("is_seize_target", false)
    for m in tree.get_nodes_in_group("mines"): 
        if is_instance_valid(m): m.set_meta("is_seize_target", false)
    _cleanup_remaining_gems()
    _reset_metas()
    for sz in tree.get_nodes_in_group("safe_zone"): sz.queue_free()
    for gw in tree.get_nodes_in_group("gravity_well"): gw.queue_free()
    current_anomaly = ""; anomaly_ended.emit()

func _cleanup_remaining_gems() -> void:
    var tree = get_tree()
    if not tree: return
    var gems = tree.get_nodes_in_group("resources")
    for gem in gems:
        if is_instance_valid(gem) and gem.has_method("start_decay"): gem.start_decay(3.0)

func _mark_camps_for_seize() -> void:
    var tree = get_tree()
    if not tree: return
    var player_camps = tree.get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.get("alignment") == 1)
    var player_mines = tree.get_nodes_in_group("player_mines").filter(func(m): return is_instance_valid(m))
    var all_targets = player_camps + player_mines
    all_targets.shuffle()
    for i in range(min(2, all_targets.size())):
        all_targets[i].set_meta("is_seize_target", true)

func _spawn_safe_zone() -> void:
    var tree = get_tree()
    if not tree: return
    var sz_scene = load("res://Assets/Scenes/SafeZone.tscn")
    if not sz_scene: return
    var inst = sz_scene.instantiate()
    var margin = 600.0
    var target_pos = Vector2(randf_range(map_rect.position.x + margin, map_rect.end.x - margin), randf_range(map_rect.position.y + margin, map_rect.end.y - margin))
    var player = tree.get_first_node_in_group("player")
    if player and target_pos.distance_to(player.global_position) < 800.0:
        target_pos = Vector2(randf_range(map_rect.position.x + margin, map_rect.end.x - margin), randf_range(map_rect.position.y + margin, map_rect.end.y - margin))
    inst.global_position = target_pos
    tree.current_scene.add_child(inst)

func _spawn_gravity_wells_globally() -> void:
    var tree = get_tree()
    if not tree: return
    var gw_scene = load("res://Assets/Scenes/GravityWell.tscn")
    if not gw_scene: return
    var spawned_count = 0; var max_wells = 5; var attempts = 0
    while spawned_count < max_wells and attempts < 40:
        attempts += 1
        var spawn_pos = Vector2(randf_range(map_rect.position.x + 500, map_rect.end.x - 500), randf_range(map_rect.position.y + 500, map_rect.end.y - 500))
        var too_close = false
        for gw in tree.get_nodes_in_group("gravity_well"):
            if gw.global_position.distance_to(spawn_pos) < 1000.0: too_close = true; break
        if not too_close:
            var inst = gw_scene.instantiate(); inst.global_position = spawn_pos
            tree.current_scene.add_child(inst); spawned_count += 1

func log_event(type: String, value: Variant = 1) -> void:
    match type:
        "xp": total_xp_collected += int(value)
        "camp_destroyed": rival_camps_destroyed += int(value)
        "unit_spawned": units_spawned += int(value)
        "zone_captured": zones_captured += int(value)
        "enemy_killed": enemies_killed += int(value)
        "resources_collected": resources_collected += int(value)
        "mine_captured": mines_captured += int(value)
        "gold_collected": gold_collected += int(value)

# --- МЕТА-ВАЛЮТА (рантайм-курс; персистенция — через SaveManager) ---

func get_meta_currency() -> int:
    return _meta_currency


func set_meta_currency(value: int) -> void:
    _meta_currency = max(0, value)
    var save_manager := get_node_or_null("/root/SaveManager")
    if save_manager and save_manager.has_method("set_value"):
        save_manager.set_value("meta_currency", _meta_currency)


func add_meta_currency(amount: int) -> void:
    if amount > 0:
        set_meta_currency(_meta_currency + amount)


# --- ОКОНЧАНИЕ ЗАБЕГА И НАГРАДА ---

func calculate_run_reward(victory: bool) -> Dictionary:
    # Реальная награда за забег в металле (run gold) с разбивкой для экрана результатов.
    # 1. Металл, уже собранный игроком за забег (Player.gold) — всегда сохраняется.
    # 2. Металл за убийства врагов — враги не дропают золото в игре,
    #    конвертация происходит только здесь. Gold Gain влияет ТОЛЬКО на этот источник.
    # 3. Победа: не собранные ресурсы READY-шахт игрока + настраиваемый бонус победы.
    #    Поражение: не собранные ресурсы шахт и бонус победы НЕ включаются.
    var player := get_tree().get_first_node_in_group("player") as Player

    var carried_gold: int = player.gold if player else 0
    var gold_gain_mult: float = player.gold_gain if player else 1.0

    # База за убийства до пассивки и бонус от пассивки (только к убийствам).
    var enemy_kill_gold: int = int(enemies_killed * kill_gold_value)
    var gold_gain_bonus: int = int(enemy_kill_gold * (gold_gain_mult - 1.0))

    var mine_remaining_gold: int = 0
    var victory_bonus_amount: int = 0
    if victory:
        for mine in get_tree().get_nodes_in_group("player_mines"):
            if not is_instance_valid(mine):
                continue
            # Только READY (хранилище заполнено) и только шахты игрока (группа уже фильтрует).
            if mine.get("state") == mine.MineState.READY:
                mine_remaining_gold += int(mine.get("resources_accumulated"))
        victory_bonus_amount = victory_bonus

    var total: int = carried_gold + enemy_kill_gold + gold_gain_bonus + mine_remaining_gold + victory_bonus_amount

    return {
        "carried_gold": carried_gold,
        "mine_remaining_gold": mine_remaining_gold,
        "enemy_kill_gold": enemy_kill_gold,
        "gold_gain_bonus": gold_gain_bonus,
        "victory_bonus": victory_bonus_amount,
        "total": max(1, total),
    }

func end_run(victory: bool) -> void:
    if is_game_over and _run_reward_calculated:
        return
    is_game_over = true
    Engine.time_scale = 1.0
    _run_reward_calculated = true
    var breakdown: Dictionary = calculate_run_reward(victory)
    var reward: int = int(breakdown.get("total", 0))
    # Начисляем награду за забег в мета-валюту (сохраняется через SaveManager).
    add_meta_currency(reward)
    run_ended.emit(victory, reward, breakdown)

func stop_game() -> void: is_game_over = true

func reset_game() -> void:
    total_xp_collected = 0; rival_camps_destroyed = 0; units_spawned = 0; zones_captured = 0
    enemies_killed = 0; resources_collected = 0; mines_captured = 0; gold_collected = 0
    time_elapsed = 0.0; is_game_over = false; current_anomaly = ""; Engine.time_scale = 1.0
    _run_reward_calculated = false
    # selected_hero_id НЕ сбрасывается — герой сохраняется при рестарте забега
    _reset_metas()

func start_new_game() -> void:
    reset_game()
    get_tree().change_scene_to_file("res://Assets/Scenes/Main.tscn")

func return_to_menu() -> void:
    stop_game()
    get_tree().change_scene_to_file("res://Assets/Scenes/MainMenu.tscn")
