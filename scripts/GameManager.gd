extends Node

var time_elapsed: float = 0.0
var is_game_active: bool = true

func _process(delta: float) -> void:
    if is_game_active:
        time_elapsed += delta

func get_time_formatted() -> String:
    var minutes = int(time_elapsed) / 60
    var seconds = int(time_elapsed) % 60
    return "%02d:%02d" % [minutes, seconds]

func reset_game() -> void:
    time_elapsed = 0.0
    is_game_active = true
