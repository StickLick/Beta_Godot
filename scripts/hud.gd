extends CanvasLayer

# Основные элементы интерфейса
@onready var health_bar: ProgressBar = %HealthBar
@onready var timer_label: Label = %TimerLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel

# Элементы экрана итогов (Должны быть отмечены как Unique Name)
@onready var results_panel: Control = get_node_or_null("%ResultsPanel")
@onready var stats_label: Label = get_node_or_null("%StatsLabel")
@onready var restart_button: Button = get_node_or_null("%RestartButton")

# Элементы выбора специализации (Должны быть отмечены как Unique Name)
@onready var specialty_panel: Control = get_node_or_null("%SpecialtyPanel")
@onready var industry_button: Button = get_node_or_null("%IndustryButton")
@onready var military_button: Button = get_node_or_null("%MilitaryButton")

# Новые элементы аномалий
@onready var anomaly_label: Label = get_node_or_null("%AnomalyLabel")
@onready var anomaly_overlay: ColorRect = get_node_or_null("AnomalyOverlay")

var _player_health_component: HealthComponent = null
var _pending_camp: Camp = null

func _ready() -> void:
    add_to_group("hud")
    
    # Скрываем панели при старте
    if is_instance_valid(results_panel): results_panel.hide()
    if is_instance_valid(specialty_panel): specialty_panel.hide()
    if is_instance_valid(anomaly_label): anomaly_label.hide()
        
    # Безопасное подключение кнопок специализации
    if is_instance_valid(industry_button):
        if not industry_button.pressed.is_connected(_on_specialty_selected):
            industry_button.pressed.connect(_on_specialty_selected.bind(1))
    if is_instance_valid(military_button):
        if not military_button.pressed.is_connected(_on_specialty_selected):
            military_button.pressed.connect(_on_specialty_selected.bind(2))
        
    # ИСПРАВЛЕНИЕ ОШИБКИ: Проверяем, не подключена ли уже кнопка рестарта
    if is_instance_valid(restart_button):
        if not restart_button.pressed.is_connected(_on_restart_pressed):
            restart_button.pressed.connect(_on_restart_pressed)

    # Подключение сигналов аномалий
    GameManager.anomaly_started.connect(_on_anomaly_started)
    GameManager.anomaly_ended.connect(_on_anomaly_ended)

    # Поиск игрока
    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if player != null:
        _setup_player_connections(player)
        
    # Подключение к системе лагерей
    get_tree().node_added.connect(_on_node_added)
    for camp in get_tree().get_nodes_in_group("camps"):
        _connect_camp(camp)

func _setup_player_connections(player: Player) -> void:
    var health_node: Node = player.find_child("HealthComponent", true, false)
    if health_node is HealthComponent:
        _player_health_component = health_node as HealthComponent
        _player_health_component.health_changed.connect(_on_player_health_changed)
        health_bar.max_value = _player_health_component.max_health
        health_bar.value = _player_health_component.current_health

    player.xp_changed.connect(_on_player_xp_changed)
    player.level_up.connect(_on_player_level_up)
    xp_bar.max_value = player.xp_to_next_level
    xp_bar.value = player.current_xp
    level_label.text = "LVL: " + str(player.current_level)

func _on_node_added(node: Node) -> void:
    if node is Camp:
        _connect_camp(node)

func _connect_camp(camp: Camp) -> void:
    if not camp.specialty_requested.is_connected(_on_camp_specialty_requested):
        camp.specialty_requested.connect(_on_camp_specialty_requested)

func _on_camp_specialty_requested(camp: Camp) -> void:
    _pending_camp = camp
    get_tree().paused = true
    if is_instance_valid(specialty_panel):
        specialty_panel.show()
        specialty_panel.move_to_front()

func _on_specialty_selected(type_index: int) -> void:
    if is_instance_valid(_pending_camp):
        _pending_camp.apply_specialty(type_index as Camp.Specialty)
    if is_instance_valid(specialty_panel):
        specialty_panel.hide()
    _pending_camp = null
    get_tree().paused = false

func _on_anomaly_started(type: String, _duration: float) -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = "!!! GLOBAL ANOMALY: " + type + " !!!"
        anomaly_label.show()
    if is_instance_valid(anomaly_overlay):
        var color = Color.WHITE
        match type:
            "OVERDRIVE": color = Color(1.0, 0.8, 0.0, 0.2)
            "SCARCITY": color = Color(0.5, 0.0, 1.0, 0.2)
            "PRESSURE_WAVE": color = Color(1.0, 0.0, 0.0, 0.2)
        create_tween().tween_property(anomaly_overlay, "color", color, 1.0)

func _on_anomaly_ended() -> void:
    if is_instance_valid(anomaly_label): anomaly_label.hide()
    if is_instance_valid(anomaly_overlay):
        create_tween().tween_property(anomaly_overlay, "color", Color(0,0,0,0), 1.0)

func _process(_delta: float) -> void:
    if "time_elapsed" in GameManager:
        timer_label.text = _format_time(GameManager.time_elapsed)

func _on_player_health_changed(current: float, max_val: float) -> void:
    health_bar.max_value = max_val
    var tween: Tween = create_tween()
    tween.tween_property(health_bar, "value", current, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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

func show_results() -> void:
    get_tree().paused = true
    if is_instance_valid(results_panel) and is_instance_valid(stats_label):
        results_panel.show()
        results_panel.move_to_front()
        
        var player = get_tree().get_first_node_in_group("player")
        var final_lvl = player.current_level if player else 0
        
        var stats_text = "--- MISSION COMPLETE ---\n\n"
        stats_text += "Final Level: %d\n" % final_lvl
        stats_text += "Zones Captured: %d\n" % GameManager.zones_captured
        stats_text += "Rival Bases Seized: %d\n" % GameManager.rival_camps_destroyed
        stats_text += "Total XP: %d\n" % GameManager.total_xp_collected
        stats_text += "Final Time: %s" % _format_time(GameManager.time_elapsed)
        
        stats_label.text = stats_text
        if is_instance_valid(restart_button): 
            restart_button.show()
            restart_button.grab_focus()

func _on_restart_pressed() -> void:
    print("[HUD] Restarting game...")
    get_tree().paused = false
    GameManager.reset_game()
    get_tree().reload_current_scene()
