extends Node

signal anomaly_started(type: String, duration: float)
signal anomaly_warning(time_left: float)
signal anomaly_ended()

# --- ТЕСТОВАЯ НАСТРОЙКА ---
const DEBUG_TEST_ANOMALY: String = "" 

var total_xp_collected: int = 0
var rival_camps_destroyed: int = 0
var units_spawned: int = 0
var zones_captured: int = 0
var time_elapsed: float = 0.0

var is_game_over: bool = false
var map_rect: Rect2 = Rect2(-2000, -2000, 4000, 4000)

var _check_timer: float = 0.0
const CHECK_INTERVAL: float = 10.0 
var current_chance: float = 0.20   
const CHANCE_STEP: float = 0.15    

var current_anomaly: String = "" 
const ANOMALY_DURATION: float = 40.0 
const WARNING_TIME: float = 5.0

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
    set_meta("prod_mult", 1.0)
    set_meta("xp_mult", 1.0)
    set_meta("enemy_stat_mult", 0.8) 
    set_meta("scarcity_active", false)
    set_meta("inertia_active", false)
    set_meta("shadow_feast_active", false)
    set_meta("map_rect", map_rect)

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
        "HUNT": set_meta("enemy_stat_mult", 1.1)
        "SEIZE": _mark_camps_for_seize()
        "COLLAPSE": _spawn_safe_zone()
        "INERTIA": set_meta("inertia_active", true)
        "GRAVITY": _spawn_gravity_wells_globally()
        "DEFICIT": set_meta("scarcity_active", true); set_meta("xp_mult", 2.0)
        "ABUNDANCE": set_meta("prod_mult", 0.5); set_meta("enemy_stat_mult", 1.1)
        "FEAST": set_meta("shadow_feast_active", true); set_meta("xp_mult", 2.0)
        "HYPERDRIVE": Engine.time_scale = 1.4
    
    var display_name = ANOMALY_NAMES.get(current_anomaly, current_anomaly)
    anomaly_started.emit(display_name, ANOMALY_DURATION)
    
    get_tree().create_timer(ANOMALY_DURATION - WARNING_TIME).timeout.connect(func():
        anomaly_warning.emit(WARNING_TIME)
    )
    get_tree().create_timer(ANOMALY_DURATION).timeout.connect(_end_anomaly)

func _end_anomaly() -> void:
    if current_anomaly == "HYPERDRIVE": Engine.time_scale = 1.0
    for c in get_tree().get_nodes_in_group("camps"): c.set_meta("is_seize_target", false)
    _cleanup_remaining_gems()
    set_meta("prod_mult", 1.0); set_meta("xp_mult", 1.0); set_meta("enemy_stat_mult", 0.8)
    set_meta("scarcity_active", false); set_meta("inertia_active", false); set_meta("shadow_feast_active", false)
    for sz in get_tree().get_nodes_in_group("safe_zone"): sz.queue_free()
    for gw in get_tree().get_nodes_in_group("gravity_well"): gw.queue_free()
    current_anomaly = ""; anomaly_ended.emit()

func _cleanup_remaining_gems() -> void:
    var gems = get_tree().get_nodes_in_group("resources")
    for gem in gems:
        if gem.has_method("start_decay"): gem.start_decay(5.0)

func _mark_camps_for_seize() -> void:
    var player_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.alignment == 1)
    player_camps.shuffle()
    for i in range(min(2, player_camps.size())):
        player_camps[i].set_meta("is_seize_target", true)
        player_camps[i].is_under_attack = true

func _spawn_safe_zone() -> void:
    var sz_scene = load("res://Assets/Scenes/SafeZone.tscn")
    if sz_scene:
        var inst = sz_scene.instantiate()
        var player = get_tree().get_first_node_in_group("player")
        if player: inst.global_position = player.global_position + Vector2.from_angle(randf()*TAU) * 350.0
        get_tree().current_scene.add_child(inst)

func _spawn_gravity_wells_globally() -> void:
    var gw_scene = load("res://Assets/Scenes/GravityWell.tscn")
    if not gw_scene: return
    var spawned_count = 0
    var max_wells = 5
    var attempts = 0
    while spawned_count < max_wells and attempts < 40:
        attempts += 1
        var spawn_pos = Vector2(randf_range(map_rect.position.x + 500, map_rect.end.x - 500), randf_range(map_rect.position.y + 500, map_rect.end.y - 500))
        var too_close = false
        for gw in get_tree().get_nodes_in_group("gravity_well"):
            if gw.global_position.distance_to(spawn_pos) < 1000.0: too_close = true; break
        if not too_close:
            var inst = gw_scene.instantiate(); inst.global_position = spawn_pos
            get_tree().current_scene.add_child(inst); spawned_count += 1

func log_event(type: String, value: Variant = 1) -> void:
    match type:
        "xp": total_xp_collected += int(value)
        "camp_destroyed": rival_camps_destroyed += int(value)
        "unit_spawned": units_spawned += int(value)
        "zone_captured": zones_captured += int(value)

func stop_game() -> void: 
    is_game_over = true
    print("[SYSTEM] Match Stopped.")

func reset_game() -> void:
    total_xp_collected = 0; rival_camps_destroyed = 0; units_spawned = 0; zones_captured = 0
    time_elapsed = 0.0; is_game_over = false; current_anomaly = ""; Engine.time_scale = 1.0
