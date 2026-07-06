extends CanvasLayer

@onready var health_bar: ProgressBar = %HealthBar
@onready var timer_label: Label = %TimerLabel

var _elapsed_time: float = 0.0
var _player_health_component: HealthComponent = null

func _ready() -> void:
    var player: Node2D = get_tree().get_first_node_in_group("player")
    if player != null:
        var health_node: Node = player.find_child("HealthComponent", true, false)
        if health_node is HealthComponent:
            _player_health_component = health_node as HealthComponent
            _player_health_component.health_changed.connect(_on_player_health_changed)
            
            health_bar.max_value = _player_health_component.max_health
            health_bar.value = _player_health_component.current_health

func _process(delta: float) -> void:
    _elapsed_time += delta
    timer_label.text = _format_time(_elapsed_time)

func _on_player_health_changed(current: float, max: float) -> void:
    health_bar.max_value = max
    var tween: Tween = create_tween()
    tween.tween_property(health_bar, "value", current, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _format_time(time_in_seconds: float) -> String:
    var total_minutes: int = int(time_in_seconds / 60.0)
    var seconds: int = int(fmod(time_in_seconds, 60.0))
    return "%02d:%02d" % [total_minutes, seconds]
