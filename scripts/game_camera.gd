extends Camera2D

@export var shake_decay: float = 5.0
@export var max_shake_offset: Vector2 = Vector2(15.0, 15.0)

var _shake_strength: float = 0.0
var _random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
var _hurtbox_component: HurtboxComponent = null

func _ready() -> void:
    # Enable native camera smoothing for seamless player following
    position_smoothing_enabled = true
    
    _random_generator.randomize()
    
    var player: Node2D = get_parent() if get_parent() is Node2D else null
    if player != null:
        # Find HurtboxComponent by type as specified in requirements
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
        
        if _shake_strength <= 0.0:
            offset = Vector2.ZERO
    else:
        offset = Vector2.ZERO

func _on_player_hit_received(damage: float) -> void:
    # Scale damage to shake intensity, clamped between min/max bounds
    _shake_strength = clamp(damage * 0.1, 0.3, 1.0)
