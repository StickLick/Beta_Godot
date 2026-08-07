extends CanvasLayer

const HERO_DATA := preload("res://scripts/hero_data.gd")

# Цвета заголовка экрана результатов (акцентная палитра проекта).
const RESULT_VICTORY_COLOR := Color(1, 0.85, 0.4, 1)
const RESULT_DEFEAT_COLOR := Color(0.85, 0.5, 0.5, 1)

@onready var health_bar: ProgressBar = %HealthBar
@onready var timer_label: Label = %TimerLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel

@onready var results_panel: Control = %ResultsPanel
@onready var title_label: Label = %TitleLabel
@onready var hero_label: Label = %HeroLabel
@onready var hero_icon: TextureRect = %HeroIcon
@onready var stats_vbox: VBoxContainer = %StatsVBox
@onready var level_row: Label = %LevelRow
@onready var zones_row: Label = %ZonesRow
@onready var camps_row: Label = %CampsRow
@onready var units_row: Label = %UnitsRow
@onready var kills_row: Label = %KillsRow
@onready var xp_row: Label = %XpRow
@onready var time_row: Label = %TimeRow
@onready var reward_row: Label = %RewardRow
@onready var restart_button: Button = %RestartButton 
@onready var menu_button: Button = %MenuButton

@onready var specialty_panel: Control = %SpecialtyPanel
@onready var industry_button: Button = %IndustryButton
@onready var military_button: Button = %MilitaryButton

@onready var anomaly_label: Label = %AnomalyLabel
@onready var anomaly_overlay: ColorRect = get_node_or_null("AnomalyOverlay")

# --- ПАУЗА ---
@onready var pause_button: Button = %PauseButton
@onready var pause_panel: Control = %PausePanel
@onready var continue_button: Button = %ContinueButton
@onready var restart_run_button: Button = %RestartRunButton
@onready var exit_menu_button: Button = %ExitMenuButton

# --- ИНВЕНТАРЬ ---
@onready var weapon_container: HBoxContainer = %WeaponSlots
@onready var passive_container: HBoxContainer = %PassiveSlots

# unused - kept for forward compat
var _pending_camp: Node2D = null
var _active_anomaly_key: String = ""
var _current_anomaly_visual = null

# Maps anomaly display name -> visual config
const ANOMALY_VISUALS = {
    "\u041f\u0420\u0418\u041a\u0410\u0417: \u041e\u0425\u041e\u0422\u0410":           {"radius": 0.0, "color": Color(0.5, 0.0, 0.0, 0.6), "softness": 10.0, "follow": null},
    "\u041f\u0420\u0418\u041a\u0410\u0417: \u0417\u0410\u0425\u0412\u0410\u0422":       {"radius": 0.0, "color": Color(0.5, 0.3, 0.0, 0.5), "softness": 10.0, "follow": null},
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u041a\u041e\u041b\u041b\u0410\u041f\u0421 \u0420\u0415\u0410\u041b\u042c\u041d\u041e\u0421\u0422\u0418": {"radius": 100.0, "color": Color(0.0, 0.3, 0.8, 0.4), "softness": 10.0, "follow": "safe_zone"},
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u0418\u041d\u0415\u0420\u0426\u0418\u042f":   {"radius": 0.0, "color": Color(0.3, 0.0, 0.3, 0.5), "softness": 10.0, "follow": null},
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u0413\u0420\u0410\u0412\u0418\u0422\u0410\u0426\u0418\u042f": {"radius": 0.0, "color": Color(0.0, 0.2, 0.2, 0.5), "softness": 10.0, "follow": null},
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u0414\u0415\u0424\u0418\u0426\u0418\u0422":   {"radius": 0.0, "color": Color(0.2, 0.2, 0.0, 0.4), "softness": 10.0, "follow": null},
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u0418\u0417\u041e\u0411\u0418\u041b\u0418\u0415":  {"radius": 0.0, "color": Color(0.0, 0.2, 0.0, 0.4), "softness": 10.0, "follow": null},
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u0422\u0415\u041d\u0415\u0412\u041e\u0419 \u041f\u0418\u0420": {"radius": 200.0, "color": Color(0.0, 0.0, 0.0, 1.0), "softness": 50.0, "follow": "player"},
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u0413\u0418\u041f\u0415\u0420\u0414\u0420\u0410\u0419\u0412": {"radius": 0.0, "color": Color(1.0, 0.5, 0.0, 0.3), "softness": 10.0, "follow": null},
}

func _ready() -> void:
    add_to_group("hud")
    if is_instance_valid(results_panel): results_panel.hide()
    if is_instance_valid(specialty_panel): specialty_panel.hide()
    if is_instance_valid(pause_panel): pause_panel.hide()
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
    if is_instance_valid(menu_button):
        if not menu_button.pressed.is_connected(_on_menu_pressed):
            menu_button.pressed.connect(_on_menu_pressed)
    if is_instance_valid(continue_button):
        if not continue_button.pressed.is_connected(_on_continue_pressed):
            continue_button.pressed.connect(_on_continue_pressed)
    if is_instance_valid(restart_run_button):
        if not restart_run_button.pressed.is_connected(_on_restart_run_pressed):
            restart_run_button.pressed.connect(_on_restart_run_pressed)
    if is_instance_valid(exit_menu_button):
        if not exit_menu_button.pressed.is_connected(_on_exit_to_menu_pressed):
            exit_menu_button.pressed.connect(_on_exit_to_menu_pressed)
    if is_instance_valid(pause_button):
        if not pause_button.pressed.is_connected(_on_pause_pressed):
            pause_button.pressed.connect(_on_pause_pressed)

    GameManager.run_ended.connect(_on_run_ended)
    GameManager.anomaly_started.connect(_on_anomaly_started)
    GameManager.anomaly_warning.connect(_on_anomaly_warning)
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
    _fill_slots(weapon_container, player.active_weapons, player.unlocked_weapon_slots, player.max_weapon_slots, Vector2(20, 20))
    _fill_slots(passive_container, player.active_passives, player.unlocked_passive_slots, player.max_passive_slots, Vector2(20, 20))

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
    _active_anomaly_key = type_name
    _current_anomaly_visual = ANOMALY_VISUALS.get(type_name, null)
    
    if is_instance_valid(anomaly_label):
        anomaly_label.text = type_name
        anomaly_label.show()
        anomaly_label.modulate = Color.WHITE
        create_tween().tween_property(anomaly_label, "modulate:a", 1.0, 0.5)
    
    if is_instance_valid(anomaly_overlay) and _current_anomaly_visual != null:
        var v = _current_anomaly_visual
        _update_overlay_shader(v.radius, v.softness, v.color, 1.5)

func _on_anomaly_warning(_time_left: float) -> void:
    if is_instance_valid(anomaly_label):
        anomaly_label.text = "\u0421\u0422\u0410\u0411\u0418\u041b\u0418\u0417\u0410\u0426\u0418\u042f..."
        anomaly_label.modulate = Color.RED
        create_tween().tween_property(anomaly_label, "modulate:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)

func _on_anomaly_ended():
    _active_anomaly_key = ""
    _current_anomaly_visual = null
    if is_instance_valid(anomaly_label):
        anomaly_label.text = "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f \u0417\u0410\u0412\u0415\u0420\u0428\u0415\u041d\u0410"
        create_tween().tween_property(anomaly_label, "modulate:a", 0.0, 0.5)
        anomaly_label.modulate.a = 0
    _update_overlay_shader(0, 10, Color(0,0,0,0), 1.0)

func _update_overlay_shader(radius, _soft, color, duration):
    var mat = anomaly_overlay.material as ShaderMaterial
    if mat:
        var tw = create_tween().set_parallel(true)
        tw.tween_method(func(v): mat.set_shader_parameter("radius_px", v), 0, radius, duration)
        tw.tween_method(func(c): mat.set_shader_parameter("fog_color", c), Color(0,0,0,0), color, duration)

func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_cancel"):
        return
    # Не перехватываем Esc, когда открыты другие паузы/меню.
    if is_instance_valid(results_panel) and results_panel.visible:
        return
    if is_instance_valid(specialty_panel) and specialty_panel.visible:
        return
    if is_instance_valid(pause_panel) and pause_panel.visible:
        _on_continue_pressed()
    else:
        _on_pause_pressed()
    get_viewport().set_input_as_handled()


## True, когда открыто меню выбора апгрейдов (UpgradeMenu._active_menu != null).
func _is_upgrade_menu_active() -> bool:
    var upgrade_menu := get_node_or_null("/root/Main/UpgradeMenu")
    if upgrade_menu == null:
        return false
    return upgrade_menu.get("_active_menu") != null


# --- ПАУЗА ---
func _on_pause_pressed() -> void:
    # Индимпотентность: пауза уже открыта — ничего не делаем.
    if is_instance_valid(pause_panel) and pause_panel.visible:
        return
    # Поднимаем HUD поверх всех CanvasLayer (включая UpgradeMenu).
    layer = 10
    # PausePanel показывается даже поверх UpgradeMenu (paused уже true).
    if is_instance_valid(pause_panel):
        pause_panel.show()
        pause_panel.move_to_front()
    # Игра уже стоит на паузе, если открыто меню апгрейдов.
    if not get_tree().paused:
        get_tree().paused = true


func _hide_pause() -> void:
    if is_instance_valid(pause_panel):
        pause_panel.hide()
    layer = 0


func _on_continue_pressed() -> void:
    _hide_pause()
    # Если UpgradeMenu ещё открыт — оставляем паузу.
    if not _is_upgrade_menu_active():
        get_tree().paused = false


## Закрыть панель паузы и снять паузу. Если UpgradeMenu открыт — только скрыть панель.
func close_pause() -> void:
    _hide_pause()
    if not _is_upgrade_menu_active():
        get_tree().paused = false


func _on_restart_run_pressed() -> void:
    _cleanup_upgrade_menu_if_active()
    _hide_pause()
    get_tree().paused = false
    GameManager.reset_game()
    get_tree().reload_current_scene()


func _on_exit_to_menu_pressed() -> void:
    _cleanup_upgrade_menu_if_active()
    _hide_pause()
    get_tree().paused = false
    GameManager.return_to_menu()


## Удаляет меню апгрейдов, если оно открыто (не должно висеть в дереве при рестарте/выходе).
func _cleanup_upgrade_menu_if_active() -> void:
    var upg := get_node_or_null("/root/Main/UpgradeMenu")
    if upg == null:
        return
    var menu = upg.get("_active_menu")
    if menu != null and is_instance_valid(menu):
        menu.queue_free()
        upg.set("_active_menu", null)


func _process(_delta: float) -> void:
    if "time_elapsed" in GameManager:
        timer_label.text = _format_time(GameManager.time_elapsed)
    
    if not is_instance_valid(anomaly_overlay):
        return
    
    var mat = anomaly_overlay.material as ShaderMaterial
    if not mat:
        return
    
    # Handle safe_zone follower (COLLAPSE)
    var sz = get_tree().get_first_node_in_group("safe_zone")
    if is_instance_valid(sz):
        mat.set_shader_parameter("center_px", sz.get_global_transform_with_canvas().origin)
        mat.set_shader_parameter("radius_px", (100.0 * sz.get_global_transform_with_canvas().get_scale().y) + 5.0)
        return
    
    # Handle player follower (FEAST/Shadow Feast)
    if _current_anomaly_visual != null and _current_anomaly_visual.get("follow") == "player":
        var player = get_tree().get_first_node_in_group("player")
        if is_instance_valid(player):
            var cam = get_viewport().get_camera_2d()
            if is_instance_valid(cam):
                var canvas_transform = cam.get_canvas_transform()
                var player_screen_pixel = canvas_transform * player.global_position
                mat.set_shader_parameter("center_px", player_screen_pixel)

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
        _on_player_health_changed(health_node.current_health, health_node.max_health)
    player.xp_changed.connect(_on_player_xp_changed)
    player.level_up.connect(_on_player_level_up)
    level_label.text = "LVL: " + str(player.current_level)

func _on_run_ended(victory: bool, reward: int) -> void:
    show_results(victory, reward)

func show_results(victory: bool = false, reward: int = 0) -> void:
    get_tree().paused = true
    if not is_instance_valid(results_panel):
        return
    results_panel.show(); results_panel.move_to_front()

    var player = get_tree().get_first_node_in_group("player")
    var final_lvl = player.current_level if player else 0

    if is_instance_valid(title_label):
        title_label.text = "ПОБЕДА!" if victory else "ПОРАЖЕНИЕ"
        title_label.add_theme_color_override("font_color", RESULT_VICTORY_COLOR if victory else RESULT_DEFEAT_COLOR)
    if is_instance_valid(hero_label):
        hero_label.text = _get_hero_display_name()
    if is_instance_valid(hero_icon):
        hero_icon.texture = _get_hero_icon_texture()
    if is_instance_valid(level_row):
        level_row.text = "Уровень: %d" % final_lvl
    if is_instance_valid(zones_row):
        zones_row.text = "Захвачено зон: %d" % GameManager.zones_captured
    if is_instance_valid(camps_row):
        camps_row.text = "Уничтожено баз: %d" % GameManager.rival_camps_destroyed
    if is_instance_valid(units_row):
        units_row.text = "Создано юнитов: %d" % GameManager.units_spawned
    if is_instance_valid(kills_row):
        kills_row.text = "Убито врагов: %d" % GameManager.enemies_killed
    if is_instance_valid(xp_row):
        xp_row.text = "Всего опыта: %d" % GameManager.total_xp_collected
    if is_instance_valid(time_row):
        time_row.text = "Время: %s" % _format_time(GameManager.time_elapsed)
    if is_instance_valid(reward_row):
        reward_row.text = "Награда: %d" % reward

    if is_instance_valid(restart_button): restart_button.show()
    if is_instance_valid(menu_button): menu_button.show()


## Имя героя из GameManager.selected_hero_id через HeroData (без новой проводки данных).
func _get_hero_display_name() -> String:
    var hero_id: String = GameManager.selected_hero_id if GameManager.get("selected_hero_id") != "" else ""
    if hero_id == "":
        hero_id = HERO_DATA.DEFAULT_HERO_ID
    return str(HERO_DATA.get_hero(hero_id).get("display_name", hero_id))


## Иконка героя (первый кадр Idle из visual SpriteFrames) — как в HeroSelectScreen.
func _get_hero_icon_texture() -> Texture2D:
    var hero_id: String = GameManager.selected_hero_id if GameManager.get("selected_hero_id") != "" else ""
    if hero_id == "":
        hero_id = HERO_DATA.DEFAULT_HERO_ID
    var hero: Dictionary = HERO_DATA.get_hero(hero_id)
    var visual: String = str(hero.get("visual", ""))
    if visual == "":
        return null
    var frames: SpriteFrames = load(visual) as SpriteFrames
    if frames and frames.get_frame_count("Idle") > 0:
        return frames.get_frame_texture("Idle", 0)
    return null

func _on_restart_pressed() -> void:
    get_tree().paused = false
    GameManager.reset_game()
    get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
    get_tree().paused = false
    GameManager.return_to_menu()