extends CanvasLayer

@onready var health_bar: ProgressBar = %HealthBar
@onready var timer_label: Label = %TimerLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel

@onready var results_panel: Control = %ResultsPanel
@onready var stats_label: Label = %StatsLabel
@onready var restart_button: Button = %RestartButton 

@onready var specialty_panel: Control = %SpecialtyPanel
@onready var industry_button: Button = %IndustryButton
@onready var military_button: Button = %MilitaryButton

@onready var anomaly_label: Label = %AnomalyLabel
@onready var anomaly_overlay: ColorRect = get_node_or_null("AnomalyOverlay")

var _player_health_component: HealthComponent = null
var _pending_camp: Camp = null

func _ready() -> void:
    add_to_group("hud")
    if is_instance_valid(results_panel): results_panel.hide()
    if is_instance_valid(specialty_panel): specialty_panel.hide()
    if is_instance_valid(anomaly_label): 
        anomaly_label.hide()
        anomaly_label.modulate.a = 0
        
    if is_instance_valid(industry_button):
        if not industry_button.pressed.is_connected(_on_specialty_selected):
            industry_button.pressed.connect(_on_specialty_selected.bind(1))
    if is_instance_valid(military_button):
        if not military_button.pressed.is_connected(_on_specialty_selected):
            military_button.pressed.connect(_on_specialty_selected.bind(2))
    if is_instance_valid(restart_button):
        if not restart_button.pressed.is_connected(_on_restart_pressed):
            restart_button.pressed.connect(_on_restart_pressed)

    GameManager.anomaly_started.connect(_on_anomaly_started)
    GameManager.anomaly_warning.connect(_on_anomaly_warning)
    GameManager.anomaly_ended.connect(_on_anomaly_ended)

    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if player != null: _setup_player_connections(player)
    get_tree().node_added.connect(func(n): if n is Camp: _connect_camp(n))
    for camp in get_tree().get_nodes_in_group("camps"): _connect_camp(camp)

func _on_anomaly_started(type_name: String, _duration: float) -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = type_name
        anomaly_label.show()
        anomaly_label.modulate = Color.WHITE
        var lt = create_tween()
        lt.tween_property(anomaly_label, "modulate:a", 1.0, 0.5)
        lt.tween_property(anomaly_label, "modulate:a", 0.0, 1.0).set_delay(3.0)
    
    if is_instance_valid(anomaly_overlay):
        var color = Color(1, 1, 1, 0.1)
        if "ОХОТА" in type_name: color = Color(0.8, 0, 0, 0.15)
        elif "ЗАХВАТ" in type_name: color = Color(1, 0.5, 0, 0.15)
        elif "КОЛЛАПС" in type_name: color = Color(0, 0.4, 0.8, 0.08)
        elif "ГРАВИТАЦИЯ" in type_name: color = Color(0.5, 0.5, 0.5, 0.1)
        elif "ДЕФИЦИТ" in type_name: color = Color(0.6, 0, 1, 0.15)
        elif "ИЗОБИЛИЕ" in type_name: color = Color(1, 0.8, 0, 0.1)
        elif "ПИР" in type_name: color = Color(0, 0, 0, 0.92)
        create_tween().tween_property(anomaly_overlay, "color", color, 1.0)

func _on_anomaly_warning(_time_left: float) -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = "ЗАВЕРШЕНИЕ СОБЫТИЯ..."
        anomaly_label.show()
        # ИСПРАВЛЕНО: set_loops вызывается у Tween
        var lt = create_tween().set_loops(4)
        lt.tween_property(anomaly_label, "modulate:a", 0.3, 0.3)
        lt.tween_property(anomaly_label, "modulate:a", 1.0, 0.3)
    
    if is_instance_valid(anomaly_overlay):
        var ot = create_tween().set_loops(5)
        ot.tween_property(anomaly_overlay, "color:a", 0.05, 0.5)
        ot.tween_property(anomaly_overlay, "color:a", 0.15, 0.5)

func _on_anomaly_ended() -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = "СИСТЕМА СТАБИЛИЗИРОВАНА"
        anomaly_label.modulate = Color.GREEN
        var lt = create_tween()
        lt.tween_property(anomaly_label, "modulate:a", 1.0, 0.2)
        lt.tween_property(anomaly_label, "modulate:a", 0.0, 0.8).set_delay(1.5)
        
    if is_instance_valid(anomaly_overlay):
        create_tween().tween_property(anomaly_overlay, "color", Color(0,0,0,0), 1.0)

func _on_restart_pressed() -> void:
    get_tree().paused = false; GameManager.reset_game(); get_tree().reload_current_scene()

func _on_specialty_selected(type_index: int) -> void:
    if is_instance_valid(_pending_camp): _pending_camp.apply_specialty(type_index as Camp.Specialty)
    if is_instance_valid(specialty_panel): specialty_panel.hide()
    _pending_camp = null; get_tree().paused = false

func _on_camp_specialty_requested(camp: Camp) -> void:
    _pending_camp = camp; get_tree().paused = true
    if is_instance_valid(specialty_panel): specialty_panel.show(); specialty_panel.move_to_front()

func _connect_camp(camp: Camp) -> void:
    if not camp.specialty_requested.is_connected(_on_camp_specialty_requested):
        camp.specialty_requested.connect(_on_camp_specialty_requested)

func _process(_delta: float) -> void:
    if "time_elapsed" in GameManager: timer_label.text = _format_time(GameManager.time_elapsed)

func _on_player_health_changed(current: float, max_val: float) -> void:
    health_bar.max_value = max_val
    create_tween().tween_property(health_bar, "value", current, 0.2).set_trans(Tween.TRANS_SINE)

func _on_player_xp_changed(current: int, next_level: int) -> void:
    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_property(xp_bar, "max_value", float(next_level), 0.2)
    tween.tween_property(xp_bar, "value", float(current), 0.2)

func _on_player_level_up(new_level: int) -> void:
    level_label.text = "LVL: " + str(new_level)
    level_label.pivot_offset = level_label.size / 2
    var tween: Tween = create_tween()
    tween.tween_property(level_label, "scale", Vector2(1.2, 1.2), 0.1)
    tween.chain().tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.1)

func _format_time(time_in_seconds: float) -> String:
    var total_minutes: int = int(time_in_seconds / 60.0)
    var seconds: int = int(fmod(time_in_seconds, 60.0))
    return "%02d:%02d" % [total_minutes, seconds]

func _setup_player_connections(player: Player) -> void:
    var health_node: Node = player.find_child("HealthComponent", true, false)
    if health_node is HealthComponent:
        _player_health_component = health_node as HealthComponent
        _player_health_component.health_changed.connect(_on_player_health_changed)
        health_bar.max_value = _player_health_component.max_health
        health_bar.value = _player_health_component.current_health
    player.xp_changed.connect(_on_player_xp_changed)
    player.level_up.connect(_on_player_level_up)
    xp_bar.max_value = player.xp_to_next_level; xp_bar.value = player.current_xp
    level_label.text = "LVL: " + str(player.current_level)

func show_results() -> void:
    get_tree().paused = true
    if is_instance_valid(results_panel) and is_instance_valid(stats_label):
        results_panel.show(); results_panel.move_to_front()
        var player = get_tree().get_first_node_in_group("player")
        var final_lvl = player.current_level if player else 0
        var stats_text = "--- МИССИЯ ВЫПОЛНЕНА ---\n\n"
        stats_text += "Уровень: %d\n" % final_lvl
        stats_text += "Захвачено зон: %d\n" % GameManager.zones_captured
        stats_text += "Уничтожено баз: %d\n" % GameManager.rival_camps_destroyed
        stats_text += "Всего опыта: %d\n" % GameManager.total_xp_collected
        stats_text += "Время: %s" % _format_time(GameManager.time_elapsed)
        stats_label.text = stats_text
        if is_instance_valid(restart_button): restart_button.show()
