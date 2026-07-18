extends Control

@export var default_icon: Texture2D
@export var industry_icon: Texture2D
@export var military_icon: Texture2D
@export var boss_icon: Texture2D

@onready var icon: Sprite2D = $Icon
@onready var distance_label: Label = $Distance

var target: Node2D = null
var _is_pulsing: bool = false
var _tween: Tween

func setup(new_target: Node2D) -> void:
    # Если цель та же — ничего не делаем, чтобы не сбрасывать анимации
    if target == new_target:
        return
    
    _stop_pulse()
    target = new_target
    _update_visual_state()

func update_indicator(screen_rect: Rect2, margin: float = 50.0) -> void:
    if not is_instance_valid(target):
        hide()
        return

    # 1. Считаем направление (Мировое для вращения, Экранное для позиции)
    var cam = get_viewport().get_camera_2d()
    if not cam: return
    
    var cam_pos = cam.get_screen_center_position()
    var target_pos = target.global_position
    var world_direction = (target_pos - cam_pos).normalized()
    
    var screen_center = screen_rect.size / 2
    var target_screen_pos = target.get_global_transform_with_canvas().origin
    var screen_direction = (target_screen_pos - screen_center).normalized()
    
    # 2. Дистанция
    var dist = cam_pos.distance_to(target_pos)
    distance_label.text = str(int(dist / 100.0)) + "m"
    
    # 3. Позиция на краю
    global_position = _get_intersection_point(screen_center, screen_direction, screen_rect, margin)
    
    # 4. ВРАЩЕНИЕ ИКОНКИ (теперь иконка сама указывает направление)
    if is_instance_valid(icon):
        icon.rotation = world_direction.angle()
    
    # 5. ОБНОВЛЕНИЕ ВИЗУАЛА И ТРЕВОГИ
    _update_visual_state()
    
    if target is Camp and target.alignment == 1: # Только для лагерей игрока
        if target.get("is_under_attack"):
            _start_pulse()
        else:
            _stop_pulse()
    else:
        _stop_pulse()

func _update_visual_state() -> void:
    if not is_instance_valid(target): return
    
    if target is RivalBoss:
        if not _is_pulsing: modulate = Color.YELLOW
        if boss_icon: icon.texture = boss_icon
    elif target is Camp:
        match target.specialty:
            1: if industry_icon: icon.texture = industry_icon
            2: if military_icon: icon.texture = military_icon
            _: if default_icon: icon.texture = default_icon
        
        if not _is_pulsing:
            match target.alignment:
                1: modulate = Color.CORNFLOWER_BLUE
                2: modulate = Color.INDIAN_RED
                _: modulate = Color.GRAY

func _start_pulse() -> void:
    if _is_pulsing: return
    _is_pulsing = true
    if _tween: _tween.kill()
    _tween = create_tween().set_loops()
    _tween.tween_property(self, "modulate", Color.RED, 0.2)
    _tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _stop_pulse() -> void:
    if not _is_pulsing: return
    _is_pulsing = false
    if _tween: _tween.kill()
    _update_visual_state()

func _get_intersection_point(center: Vector2, dir: Vector2, rect: Rect2, margin: float) -> Vector2:
    var size = rect.size / 2 - Vector2(margin, margin)
    var x_ratio = abs(size.x / dir.x) if dir.x != 0 else INF
    var y_ratio = abs(size.y / dir.y) if dir.y != 0 else INF
    var min_ratio = min(x_ratio, y_ratio)
    return center + dir * min_ratio
