extends Camera2D

@export var shake_decay: float = 5.0
@export var max_shake_offset: Vector2 = Vector2(15.0, 15.0)

var _shake_strength: float = 0.0
var _random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
var _hurtbox_component: HurtboxComponent = null

func _ready() -> void:
    position_smoothing_enabled = true
    _random_generator.randomize()
    
    var player: Node2D = get_parent() if get_parent() is Node2D else null
    if player != null:
        for child in player.get_children():
            if child is HurtboxComponent:
                _hurtbox_component = child as HurtboxComponent
                break
        if _hurtbox_component != null:
            _hurtbox_component.hit_received.connect(_on_player_hit_received)

func _process(delta: float) -> void:
    if _shake_strength > 0.0:
        _shake_strength = move_toward(_shake_strength, 0.0, shake_decay * delta)
        offset = Vector2(
            _random_generator.randf_range(-_shake_strength, _shake_strength), 
            _random_generator.randf_range(-_shake_strength, _shake_strength)
        ) * max_shake_offset
    else:
        offset = Vector2.ZERO

func _on_player_hit_received(damage: float) -> void:
    _shake_strength = clamp(damage * 0.1, 0.3, 1.0)

func death_zoom(target_pos: Vector2) -> void:
    var current_global_pos = global_position
    position_smoothing_enabled = false
    set_as_top_level(true)
    global_position = current_global_pos
    
    var tween = create_tween().set_parallel(true)
    # Плавный полет к боссу
    tween.tween_property(self, "global_position", target_pos, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # Отдаленный зум (1.2 вместо 2.5), чтобы видеть всю картину
    tween.tween_property(self, "zoom", Vector2(1.2, 1.2), 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
