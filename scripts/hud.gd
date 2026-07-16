extends CanvasLayer

@onready var health_bar: ProgressBar = %HealthBar
@onready var timer_label: Label = %TimerLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel

@onready var results_panel: Control = %ResultsPanel
@onready var stats_label: Label = %StatsLabel

var _player_health_component: HealthComponent = null

func _ready() -> void:
    # Добавляем в группу для легкого поиска боссом
    add_to_group("hud")
    
    if is_instance_valid(results_panel):
        results_panel.hide()
        
    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if player != null:
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
    tween.tween_property(level_label, "scale", Vector2(1.3, 1.3), 0.1)
    tween.chain().tween_property(level_label, "scale", Vector2(1.1, 1.1), 0.1)

func _format_time(time_in_seconds: float) -> String:
    var total_minutes: int = int(time_in_seconds / 60.0)
    var seconds: int = int(fmod(time_in_seconds, 60.0))
    return "%02d:%02d" % [total_minutes, seconds]

func show_results() -> void:
    print("[HUD] Showing results panel...")
    # Ставим всю игру на паузу
    get_tree().paused = true
    
    if is_instance_valid(results_panel) and is_instance_valid(stats_label):
        results_panel.show()
        
        var stats_text = "--- MISSION COMPLETE ---\n\n"
        stats_text += "Total XP Collected: %d\n" % GameManager.total_xp_collected
        stats_text += "Rival Bases Seized: %d\n" % GameManager.rival_camps_destroyed
        stats_text += "Units Produced: %d\n" % GameManager.units_spawned
        stats_text += "Final Time: %s" % _format_time(GameManager.time_elapsed)
        
        stats_label.text = stats_text
    else:
        push_error("ResultsPanel or StatsLabel not found in HUD scene!")

func _on_restart_pressed() -> void:
    get_tree().paused = false
    GameManager.reset_game()
    get_tree().reload_current_scene()
