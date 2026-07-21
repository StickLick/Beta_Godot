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

    var player: Player = get_tree().get_first_node_in_group("player") as Player
    if player != null: _setup_player_connections(player)
    
    get_tree().node_added.connect(func(n): if n is Camp: _connect_camp(n))
    for camp in get_tree().get_nodes_in_group("camps"): _connect_camp(camp)
    
    if is_instance_valid(anomaly_overlay):
        anomaly_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        anomaly_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        anomaly_overlay.color = Color(1, 1, 1, 0)
        anomaly_overlay.show()
        # Инициализируем параметры шейдера, чтобы избежать Nil ошибок
        var mat = anomaly_overlay.material as ShaderMaterial
        if mat:
            mat.set_shader_parameter("radius_px", 0.0)
            mat.set_shader_parameter("softness_px", 10.0)
            mat.set_shader_parameter("fog_color", Color(0,0,0,0))
            mat.set_shader_parameter("center_px", get_viewport().get_visible_rect().size / 2.0)

func _on_anomaly_started(type_name: String, _duration: float) -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = type_name
        anomaly_label.show()
        anomaly_label.modulate = Color.WHITE
        var lt = create_tween()
        lt.tween_property(anomaly_label, "modulate:a", 1.0, 0.5)
        lt.tween_property(anomaly_label, "modulate:a", 0.0, 1.0).set_delay(3.0)
    
    if is_instance_valid(anomaly_overlay):
        var target_color: Color = Color(0, 0, 0, 0)
        var target_radius: float = 0.0 
        var target_soft: float = 10.0
        
        var screen_size = get_viewport().get_visible_rect().size

        if "ОХОТА" in type_name: target_color = Color(0.8, 0, 0, 0.25)
        elif "ЗАХВАТ" in type_name: target_color = Color(1, 0.5, 0, 0.25)
        elif "КОЛЛАПС" in type_name: 
            target_color = Color(0, 0.3, 0.8, 0.4)
            target_soft = 5.0 # Четкая граница
            target_radius = screen_size.y
        elif "ГРАВИТАЦИЯ" in type_name: target_color = Color(0.5, 0.2, 0.8, 0.2)
        elif "ДЕФИЦИТ" in type_name: target_color = Color(0.4, 0, 0.6, 0.3)
        elif "ИЗОБИЛИЕ" in type_name: target_color = Color(1, 0.8, 0, 0.15)
        elif "ПИР" in type_name: 
            target_color = Color(0, 0, 0, 1.0)
            target_radius = screen_size.y * 0.12
            target_soft = screen_size.y * 0.15
        elif "ГИПЕРДРАЙВ" in type_name: target_color = Color(0, 1, 0.8, 0.15)
        
        _update_overlay_shader(target_radius, target_soft, target_color, 1.5)

func _on_anomaly_warning(_time_left: float) -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = "СТАБИЛИЗАЦИЯ..."
        anomaly_label.show()
        var lt = create_tween().set_loops(4)
        lt.tween_property(anomaly_label, "modulate:a", 0.3, 0.3)
        lt.tween_property(anomaly_label, "modulate:a", 1.0, 0.3)

func _on_anomaly_ended() -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = "СИСТЕМА СТАБИЛИЗИРОВАНА"
        anomaly_label.modulate = Color.GREEN
        var lt = create_tween()
        lt.tween_property(anomaly_label, "modulate:a", 1.0, 0.2)
        lt.tween_property(anomaly_label, "modulate:a", 0.0, 0.8).set_delay(1.5)
        
    if is_instance_valid(anomaly_overlay):
        _update_overlay_shader(0.0, 10.0, Color(0,0,0,0), 1.0)

func _update_overlay_shader(radius: float, soft: float, color: Color, duration: float) -> void:
    if not is_instance_valid(anomaly_overlay): return
    var mat = anomaly_overlay.material as ShaderMaterial
    if not mat: return
    
    # Безопасное получение текущих значений (защита от Nil)
    var cur_r = mat.get_shader_parameter("radius_px")
    if cur_r == null: cur_r = 0.0
    var cur_s = mat.get_shader_parameter("softness_px")
    if cur_s == null: cur_s = 10.0
    var cur_c = mat.get_shader_parameter("fog_color")
    if cur_c == null: cur_c = Color(0,0,0,0)
    
    var tween = create_tween().set_parallel(true)
    tween.tween_method(func(v): mat.set_shader_parameter("radius_px", v), cur_r, radius, duration)
    tween.tween_method(func(s): mat.set_shader_parameter("softness_px", s), cur_s, soft, duration)
    tween.tween_method(func(c): mat.set_shader_parameter("fog_color", c), cur_c, color, duration)

func _process(_delta: float) -> void:
    if "time_elapsed" in GameManager: timer_label.text = _format_time(GameManager.time_elapsed)
    
    if GameManager.current_anomaly == "COLLAPSE":
        _process_collapse_overlay()
    elif GameManager.current_anomaly == "FEAST":
        _process_feast_overlay()

func _process_collapse_overlay() -> void:
    if not is_instance_valid(anomaly_overlay): return
    var mat = anomaly_overlay.material as ShaderMaterial
    if not mat: return
    
    var sz = get_tree().get_first_node_in_group("safe_zone")
    if is_instance_valid(sz):
        var screen_pos = sz.get_global_transform_with_canvas().origin
        mat.set_shader_parameter("center_px", screen_pos)
        
        var screen_scale = sz.get_global_transform_with_canvas().get_scale().y
        # Добавляем +5 пикселей запаса, чтобы внутри кольца было идеально чисто
        var radius_in_pixels = (100.0 * screen_scale) + 5.0
        mat.set_shader_parameter("radius_px", radius_in_pixels)

func _process_feast_overlay() -> void:
    if not is_instance_valid(anomaly_overlay): return
    var mat = anomaly_overlay.material as ShaderMaterial
    if not mat: return
    
    var player = get_tree().get_first_node_in_group("player")
    if is_instance_valid(player):
        var screen_pos = player.get_global_transform_with_canvas().origin
        mat.set_shader_parameter("center_px", screen_pos)

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
