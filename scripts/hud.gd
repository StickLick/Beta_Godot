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

# --- ИНВЕНТАРЬ ---
@onready var weapon_container: HBoxContainer = %WeaponSlots
@onready var passive_container: HBoxContainer = %PassiveSlots

var _player_health_component: HealthComponent = null
var _pending_camp: Node2D = null

func _ready() -> void:
    add_to_group("hud")
    if is_instance_valid(results_panel): results_panel.hide()
    if is_instance_valid(specialty_panel): specialty_panel.hide()
    if is_instance_valid(anomaly_label): 
        anomaly_label.hide()
        anomaly_label.modulate.a = 0
        
    # Настройка кнопок специальностей
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
    GameManager.anomaly_ended.connect(_on_anomaly_ended)

    var player: Player = get_tree().get_first_node_in_group("player") as Player
    if player != null: 
        _setup_player_connections(player)
        player.inventory_updated.connect(update_inventory_ui)
    
    get_tree().node_added.connect(func(n): if n is Camp: _connect_camp(n))
    for camp in get_tree().get_nodes_in_group("camps"): _connect_camp(camp)
    
    if is_instance_valid(anomaly_overlay):
        anomaly_overlay.show()
        _update_overlay_shader(0.0, 5.0, Color(0,0,0,0), 0.1)
            
    update_inventory_ui()

func update_inventory_ui() -> void:
    var player = get_tree().get_first_node_in_group("player") as Player
    if not player: return
    _fill_slots(weapon_container, player.active_weapons, player.unlocked_weapon_slots, 3, Vector2(20, 20))
    _fill_slots(passive_container, player.active_passives, player.unlocked_passive_slots, 3, Vector2(20, 20))

func _fill_slots(container: HBoxContainer, items: Array, max_slots: int, total_slots: int, slot_size: Vector2) -> void:
    if not is_instance_valid(container): return
    for child in container.get_children(): child.queue_free()
    
    for i in range(total_slots):
        var slot = ColorRect.new()
        slot.custom_minimum_size = slot_size
        
        if i < items.size():
            slot.color = Color(0.2, 0.2, 0.2, 0.8)
            var icon = TextureRect.new()
            icon.texture = items[i].icon
            icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            slot.add_child(icon)
        elif i < max_slots:
            slot.color = Color(1, 1, 1, 0.15)
        else:
            slot.color = Color(0, 0, 0, 0.6)
        container.add_child(slot)

# --- АНОМАЛИИ ---
func _on_anomaly_started(type_name: String, _duration: float) -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = type_name; anomaly_label.show(); anomaly_label.modulate = Color.WHITE
        create_tween().tween_property(anomaly_label, "modulate:a", 1.0, 0.5)
    if is_instance_valid(anomaly_overlay):
        var target_color = Color(0, 0.3, 0.8, 0.4) if "КОЛЛАПС" in type_name else Color(0,0,0,1)
        _update_overlay_shader(100.0, 10.0, target_color, 1.5)

func _on_anomaly_ended(): _update_overlay_shader(0, 10, Color(0,0,0,0), 1.0)

func _update_overlay_shader(radius, soft, color, duration):
    var mat = anomaly_overlay.material as ShaderMaterial
    if mat:
        var tw = create_tween().set_parallel(true)
        tw.tween_method(func(v): mat.set_shader_parameter("radius_px", v), 0, radius, duration)
        tw.tween_method(func(c): mat.set_shader_parameter("fog_color", c), Color(0,0,0,0), color, duration)

func _process(_delta: float) -> void:
    if "time_elapsed" in GameManager: timer_label.text = _format_time(GameManager.time_elapsed)
    var sz = get_tree().get_first_node_in_group("safe_zone")
    if is_instance_valid(sz) and is_instance_valid(anomaly_overlay):
        var mat = anomaly_overlay.material as ShaderMaterial
        mat.set_shader_parameter("center_px", sz.get_global_transform_with_canvas().origin)
        mat.set_shader_parameter("radius_px", (100.0 * sz.get_global_transform_with_canvas().get_scale().y) + 5.0)

# --- ЛОГИКА ЛАГЕРЕЙ ---
func _on_specialty_selected(type_index: int) -> void:
    if is_instance_valid(_pending_camp): _pending_camp.apply_specialty(type_index)
    if is_instance_valid(specialty_panel): specialty_panel.hide()
    _pending_camp = null; get_tree().paused = false

func _on_camp_specialty_requested(camp: Node2D) -> void:
    _pending_camp = camp; get_tree().paused = true
    if is_instance_valid(specialty_panel): specialty_panel.show(); specialty_panel.move_to_front()

func _connect_camp(camp: Node2D) -> void:
    if camp.has_signal("specialty_requested"):
        camp.specialty_requested.connect(_on_camp_specialty_requested)

# --- ЛОГИКА ИГРОКА ---
func _on_player_health_changed(c, m): health_bar.max_value = m; health_bar.value = c
func _on_player_xp_changed(c, n): xp_bar.max_value = n; xp_bar.value = c

func _on_player_level_up(new_level: int) -> void:
    level_label.text = "LVL: " + str(new_level)
    # ВСЕ АНИМАЦИИ УДАЛЕНЫ ПО ПРОСЬБЕ. ШРИФТ БУДЕТ ТАКИМ, КАК В ИНСПЕКТОРЕ.

func _format_time(t): return "%02d:%02d" % [int(t/60), int(fmod(t,60))]

func _setup_player_connections(player: Player) -> void:
    var health_node: Node = player.find_child("HealthComponent", true, false)
    if health_node is HealthComponent:
        health_node.health_changed.connect(_on_player_health_changed)
        # Инициализируем health_bar сразу, чтобы не было 0 HP
        _on_player_health_changed(health_node.current_health, health_node.max_health)
    player.xp_changed.connect(_on_player_xp_changed)
    player.level_up.connect(_on_player_level_up)
    level_label.text = "LVL: " + str(player.current_level)

func show_results() -> void:
    get_tree().paused = true
    if is_instance_valid(results_panel) and is_instance_valid(stats_label):
        results_panel.show(); results_panel.move_to_front()
        var player = get_tree().get_first_node_in_group("player")
        var final_lvl = player.current_level if player else 0
        var stats_text = "--- МИССИЯ ВЫПОЛНЕНА ---\n\nУровень: %d\nЗахвачено зон: %d\nУничтожено баз: %d\nВсего опыта: %d\nВремя: %s" % [final_lvl, GameManager.zones_captured, GameManager.rival_camps_destroyed, GameManager.total_xp_collected, _format_time(GameManager.time_elapsed)]
        stats_label.text = stats_text
        if is_instance_valid(restart_button): restart_button.show()

func _on_restart_pressed(): GameManager.reset_game(); get_tree().reload_current_scene()
