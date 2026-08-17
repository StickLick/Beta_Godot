extends CanvasLayer

const HERO_DATA := preload("res://scripts/hero_data.gd")

# Цвета заголовка экрана результатов (акцентная палитра проекта).
const RESULT_VICTORY_COLOR := Color(1, 0.85, 0.4, 1)
const RESULT_DEFEAT_COLOR := Color(0.85, 0.5, 0.5, 1)

@onready var health_bar: ProgressBar = %HealthBar
@onready var hp_fill_bar: TextureProgressBar = %TextureProgressBar
@onready var timer_label: Label = %TimerLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel
@onready var gold_label: Label = %GoldLabel

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
@onready var carried_gold_row: Label = %CarriedGoldRow
@onready var mine_gold_row: Label = %MineGoldRow
@onready var kill_gold_row: Label = %KillGoldRow
@onready var gold_gain_row: Label = %GoldGainRow
@onready var victory_bonus_row: Label = %VictoryBonusRow
@onready var total_reward_row: Label = %TotalRewardRow
@onready var restart_button: Button = %RestartButton 
@onready var menu_button: Button = %MenuButton

@onready var specialty_panel: Control = %SpecialtyPanel
@onready var industry_button: Button = %IndustryButton
@onready var military_button: Button = %MilitaryButton
@onready var decline_button: Button = %DeclineButton

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

## Иконка замка для закрытых слотов инвентаря + настройки отображения (Inspector).
const DEFAULT_LOCK_ICON := preload("res://Texture/Lock 256 px.png")
@export var lock_icon: Texture2D = DEFAULT_LOCK_ICON
@export var lock_icon_size: Vector2 = Vector2(24, 24)
@export var lock_icon_offset: Vector2 = Vector2.ZERO

# Unused - kept for forward compat
var _pending_target: Node2D = null
var _active_anomaly_key: String = ""
var _current_anomaly_visual = null

# --- ОХОТА НА КУРЬЕРА ---
var courier_event: Node = null
var courier_banner: Label = null
var courier_intro_time: float = 0.0   # сколько секунд осталось показывать вводную надпись

# --- MINE UPGRADE (переиспользование specialty_panel) ---
const MINE_ECO_BUTTON_TEXT: String = "ШАХТА"
const MINE_MIL_BUTTON_TEXT: String = "ФОРТ"
const CAMP_ECO_BUTTON_TEXT: String = "ИНДУСТРИЯ"
const CAMP_MIL_BUTTON_TEXT: String = "ВОЕННЫЙ"
const MINE_ECO_MAX_TEXT: String = "Max"
const MINE_MIL_MAX_TEXT: String = "Max"

# Maps anomaly display name -> visual config
const ANOMALY_VISUALS = {
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u041a\u041e\u041b\u041b\u0410\u041f\u0421 \u0420\u0415\u0410\u041b\u042c\u041d\u041e\u0421\u0422\u0418": {"radius": 100.0, "color": Color(0.0, 0.3, 0.8, 0.4), "softness": 10.0, "follow": "safe_zone"},
    "\u0410\u041d\u041e\u041c\u0410\u041b\u0418\u042f: \u0422\u0415\u041d\u0415\u0412\u041e\u0419 \u041f\u0418\u0420": {"radius": 200.0, "color": Color(0.0, 0.0, 0.0, 1.0), "softness": 50.0, "follow": "player"},
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
    if is_instance_valid(decline_button):
        if not decline_button.pressed.is_connected(_on_decline_pressed):
            decline_button.pressed.connect(_on_decline_pressed)
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

    # CourierHuntEvent может инициализироваться ПОЗЖЕ HUD (порядок нод в Main.tscn).
    # Надёжно подключаемся в _process при появлении события в группе.
    _create_courier_banner()
    var ev := get_tree().get_first_node_in_group("courier_hunt_event")
    if ev:
        _connect_courier_event(ev)

    var player: Player = get_tree().get_first_node_in_group("player") as Player
    if player != null: 
        _setup_player_connections(player)
        player.inventory_updated.connect(update_inventory_ui)
    
    get_tree().node_added.connect(func(n):
        if n is Camp: _connect_camp(n)
        if n is Mine: _connect_mine(n)
    )
    for camp in get_tree().get_nodes_in_group("camps"): _connect_camp(camp)
    for mine in get_tree().get_nodes_in_group("mines"): _connect_mine(mine)
    
    if is_instance_valid(anomaly_overlay):
        anomaly_overlay.show()
        _update_overlay_shader(0.0, 5.0, Color(0,0,0,0), 0.1)
            
    update_inventory_ui()

func update_inventory_ui() -> void:
    var player = get_tree().get_first_node_in_group("player") as Player
    if not player: return
    _fill_slots(weapon_container, player.active_weapons, player.unlocked_weapon_slots, player.max_weapon_slots, Vector2(30, 30))
    _fill_slots(passive_container, player.active_passives, player.unlocked_passive_slots, player.max_passive_slots, Vector2(30, 30))

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
            if lock_icon != null:
                var lock_rect := TextureRect.new()
                lock_rect.texture = lock_icon
                lock_rect.custom_minimum_size = lock_icon_size
                lock_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                lock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                lock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
                lock_rect.position = (slot_size - lock_icon_size) * 0.5 + lock_icon_offset
                slot.add_child(lock_rect)
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


func _create_courier_banner() -> void:
    courier_banner = Label.new()
    courier_banner.name = "CourierBanner"
    courier_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    courier_banner.add_theme_font_size_override("font_size", 18)
    courier_banner.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
    # Растяжка по всей ширине верха экрана с центрированным текстом
    # (horizontal_alignment = CENTER уже задан выше), чтобы Label не уезжал за экран.
    courier_banner.anchor_left = 0.0
    courier_banner.anchor_right = 1.0
    courier_banner.anchor_top = 0.0
    courier_banner.anchor_bottom = 0.0
    courier_banner.offset_left = 0.0
    courier_banner.offset_right = 0.0
    courier_banner.offset_top = 90.0
    courier_banner.offset_bottom = 122.0
    courier_banner.hide()
    add_child(courier_banner)

func _connect_courier_event(ev: Node) -> void:
    if ev == courier_event:
        return
    courier_event = ev
    ev.hunt_started.connect(_on_courier_hunt_started)
    ev.hunt_ended.connect(_on_courier_hunt_ended)

func _on_courier_hunt_started(duration: float) -> void:
    if is_instance_valid(courier_banner):
        courier_banner.show()
        courier_banner.text = "⚔ ОХОТА НА КУРЬЕРА"   # вводная надпись
        courier_intro_time = 2.0                     # показываем 2 секунды

func _on_courier_hunt_ended() -> void:
    courier_intro_time = 0.0
    if is_instance_valid(courier_banner):
        courier_banner.hide()


func _process(_delta: float) -> void:
    if "time_elapsed" in GameManager:
        timer_label.text = _format_time(GameManager.time_elapsed)

    # Ожидание появления CourierHuntEvent (инициализируется позже HUD)
    if courier_event == null:
        var ev := get_tree().get_first_node_in_group("courier_hunt_event")
        if ev:
            _connect_courier_event(ev)

    # Таймер баннера охоты на курьера: сначала вводная надпись, затем цифры
    if is_instance_valid(courier_event) and is_instance_valid(courier_banner) and courier_banner.visible:
        if courier_intro_time > 0.0:
            courier_intro_time -= _delta
            # Пока идёт вводная надпись — ничего не меняем
        else:
            courier_banner.text = str(int(ceil(courier_event.time_left)))

    # Обновление счётчика золота игрока (только число, иконка в сцене)
    var gold_player = get_tree().get_first_node_in_group("player")
    gold_label.text = str(gold_player.gold if is_instance_valid(gold_player) else 0)
    
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
        var follower_player = get_tree().get_first_node_in_group("player")
        if is_instance_valid(follower_player):
            var cam = get_viewport().get_camera_2d()
            if is_instance_valid(cam):
                var canvas_transform = cam.get_canvas_transform()
                var player_screen_pixel = canvas_transform * follower_player.global_position
                mat.set_shader_parameter("center_px", player_screen_pixel)

# --- ЛОГИКА ЛАГЕРЕЙ И ШАХТ (общая панель specialty) ---
func _on_specialty_selected(type_index: int) -> void:
    if is_instance_valid(_pending_target):
        if _pending_target is Camp:
            _pending_target.apply_specialty(type_index)
        elif _pending_target is Mine:
            # Защита: не выбираем апгрейд, если строительство уже идёт (state == BUILDING).
            if _pending_target.get("state") == _pending_target.MineState.BUILDING:
                _close_specialty_panel()
                return
            match type_index:
                1: _pending_target.start_construction("economic")
                2: _pending_target.start_construction("military")
    _close_specialty_panel()

func _on_decline_pressed() -> void:
    # Кнопка «Забрать»: только для шахт собирает ресурсы и сбрасывает state в PRODUCING.
    if _pending_target is Mine:
        var player := get_tree().get_first_node_in_group("player")
        _pending_target.collect_resources(player)
    _close_specialty_panel()

func _close_specialty_panel() -> void:
    if is_instance_valid(specialty_panel): specialty_panel.hide()
    _pending_target = null; get_tree().paused = false

func _on_camp_specialty_requested(camp: Node2D) -> void:
    if camp is Camp:
        # Восстанавливаем тексты/состояние кнопок для лагеря (общие с шахтой).
        if is_instance_valid(industry_button): industry_button.text = CAMP_ECO_BUTTON_TEXT
        if is_instance_valid(military_button): military_button.text = CAMP_MIL_BUTTON_TEXT
        if is_instance_valid(industry_button): industry_button.disabled = false
        if is_instance_valid(military_button): military_button.disabled = false
        if is_instance_valid(decline_button): decline_button.visible = false  # decline не для лагерей
    _pending_target = camp; get_tree().paused = true
    if is_instance_valid(specialty_panel): specialty_panel.show(); specialty_panel.move_to_front()

func _connect_camp(camp: Node2D) -> void:
    if camp.has_signal("specialty_requested"):
        camp.specialty_requested.connect(_on_camp_specialty_requested)

# --- ЛОГИКА ШАХТ (улучшение через ту же панель) ---
func _on_mine_upgrade_ready(mine: Mine) -> void:
    # Защитный гейт: только player-шахта может открывать меню улучшения.
    # (mine.gd уже проверяет alignment при эмите, это второй слой безопасности.)
    if mine.get("alignment") != 1:
        return
    # Защитный гейт: панель открывается только для шахт в состоянии READY.
    # BUILDING (стройка идёт) и PRODUCING (хранилище не заполнено) не открывают панель.
    if mine.get("state") != mine.MineState.READY:
        return
    # Панель уже открыта — игнорируем (не ставим в очередь).
    if is_instance_valid(specialty_panel) and specialty_panel.visible:
        return
    # Игрок должен физически находиться у этой шахты.
    var player := get_tree().get_first_node_in_group("player")
    if not is_instance_valid(player) or player.get("current_mine") != mine:
        return
    # Мета-фильтр: апгрейды шахты доступны только в пределах разблокированного
    # уровня шахты (MetaProgress.get_mine_level). Уровень 1 = только база без апгрейдов;
    # уровень N разрешает N-1 суммарных апгрейдов. Запертые апгрейды не попадают в пул выбора.
    var meta := get_node_or_null("/root/MetaProgress")
    var meta_max_upgrades: int = int(meta.get_mine_level()) - 1 if meta and meta.has_method("get_mine_level") else 999
    # Шахты ещё не открыты для прокачки (mine level 1) — меню не появится.
    # Автосбор заполненного хранилища при входе в зону.
    if meta_max_upgrades <= 0:
        if mine.resources_accumulated > 0.0:
            mine.collect_resources(player)
        return
    if mine.total_upgrades_used() >= meta_max_upgrades:
        return
    # Тексты/состояние кнопок для шахты (Max + disabled при достижении предела ветки).
    if is_instance_valid(industry_button):
        if mine.get("economic_level") >= mine.MAX_ECONOMIC_LEVEL:
            industry_button.text = MINE_ECO_MAX_TEXT
            industry_button.disabled = true
        else:
            industry_button.text = MINE_ECO_BUTTON_TEXT
            industry_button.disabled = false
    if is_instance_valid(military_button):
        if mine.get("military_level") >= mine.MAX_MILITARY_LEVEL:
            military_button.text = MINE_MIL_MAX_TEXT
            military_button.disabled = true
        else:
            military_button.text = MINE_MIL_BUTTON_TEXT
            military_button.disabled = false
    if is_instance_valid(decline_button): decline_button.visible = true  # decline только для шахт
    _pending_target = mine; get_tree().paused = true
    if is_instance_valid(specialty_panel): specialty_panel.show(); specialty_panel.move_to_front()

func _connect_mine(mine: Mine) -> void:
    if mine.has_signal("upgrade_ready"):
        mine.upgrade_ready.connect(_on_mine_upgrade_ready)

# --- ЛОГИКА ИГРОКА ---
func set_health(current: float, max_health: float) -> void:
    hp_fill_bar.max_value = max_health
    hp_fill_bar.value = current


func _on_player_health_changed(c, m):
    health_bar.max_value = m; health_bar.value = c
    set_health(c, m)
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

func _on_run_ended(victory: bool, reward: int, breakdown: Dictionary) -> void:
    show_results(victory, reward, breakdown)

func show_results(victory: bool = false, reward: int = 0, breakdown: Dictionary = {}) -> void:
    get_tree().paused = true
    if not is_instance_valid(results_panel):
        return
    results_panel.show(); results_panel.move_to_front()

    var player = get_tree().get_first_node_in_group("player") as Player
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
    # --- Разбивка металла за забег (данные посчитаны в GameManager.calculate_run_reward) ---
    var carried_gold: int = int(breakdown.get("carried_gold", 0))
    var mine_remaining_gold: int = int(breakdown.get("mine_remaining_gold", 0))
    var enemy_kill_gold: int = int(breakdown.get("enemy_kill_gold", 0))
    var gold_gain_bonus: int = int(breakdown.get("gold_gain_bonus", 0))
    var victory_bonus_amount: int = int(breakdown.get("victory_bonus", 0))
    var total_reward: int = int(breakdown.get("total", reward))

    if is_instance_valid(carried_gold_row):
        carried_gold_row.text = "Собрано во время забега: %d" % carried_gold
        carried_gold_row.visible = true
    if is_instance_valid(mine_gold_row):
        mine_gold_row.text = "Остаток из шахт: %d" % mine_remaining_gold
        mine_gold_row.visible = victory
    if is_instance_valid(kill_gold_row):
        kill_gold_row.text = "Убийства врагов: %d" % enemy_kill_gold
        kill_gold_row.visible = true
    if is_instance_valid(gold_gain_row):
        var gold_gain_mult: float = 1.0
        if player:
            gold_gain_mult = player.gold_gain
        var percent: int = int(round((gold_gain_mult - 1.0) * 100.0))
        gold_gain_row.text = "Пассивка \"Золото\" (+%d%%): +%d" % [percent, gold_gain_bonus]
        gold_gain_row.visible = gold_gain_bonus > 0
    if is_instance_valid(victory_bonus_row):
        victory_bonus_row.text = "Победа: %d" % victory_bonus_amount
        victory_bonus_row.visible = victory
    if is_instance_valid(total_reward_row):
        total_reward_row.text = "Всего получено: %d" % total_reward
        total_reward_row.visible = true

    if is_instance_valid(reward_row):
        reward_row.text = "Награда: %d" % total_reward
        reward_row.visible = false

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
