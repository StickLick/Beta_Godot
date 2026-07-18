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
    if not is_instance_valid(zone_system): return
    var player = get_tree().get_first_node_in_group("player")
    if not player: return
    
    var zones = get_tree().get_nodes_in_group("zones")
    var rival_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return c.alignment == 2)
    
    # ДИНАМИЧЕСКАЯ НАГЛОСТЬ:
    # Базовая дистанция спавна — 1500 пикселей (далеко).
    # За каждый живой красный лагерь дистанция снижается на 150 пикселей (минимум до 600).
    var min_spawn_dist = clamp(1500.0 - (rival_camps.size() * 150.0), 600.0, 1500.0)
    
    var best_zone = null
    var min_dist = INF
    
    for zone in zones:
        if not is_instance_valid(zone) or zone.is_queued_for_deletion(): continue
        if zone.get("current_state") != 2: continue 
        
        var d = zone.global_position.distance_to(player.global_position)
        if d > min_spawn_dist and d < min_dist: 
            min_dist = d
            best_zone = zone
            
    if best_zone:
        best_zone.remove_from_group("zones")
        _log("STRATEGIC", "EXPANSION - Spawning Rival Camp at safe distance: %dpx" % int(min_dist))
        zone_system._on_zone_evolved(best_zone.global_position, "RivalExpansion", 2.0, best_zone)
        
        (func(): 
            await get_tree().process_frame
            var camps = get_tree().get_nodes_in_group("camps")
            if camps.size() > 0:
                var last_camp = camps.back()
                if is_instance_valid(last_camp): last_camp.alignment = 2
        ).call()

func _execute_economy() -> void:
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
