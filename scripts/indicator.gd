extends Control

@export var default_icon: Texture2D
@export var industry_icon: Texture2D
@export var military_icon: Texture2D
@export var boss_icon: Texture2D
@export var safe_zone_icon: Texture2D
@export var courier_icon: Texture2D

@onready var icon: Sprite2D = $Icon
@onready var distance_label: Label = $Distance

var target: Node2D = null
var _is_pulsing: bool = false
var _tween: Tween

func setup(new_target: Node2D) -> void:
    if target == new_target: return
    _stop_pulse(); target = new_target; _update_visual_state()

func update_indicator(screen_rect: Rect2, margin: float = 24.0) -> void:
    if not is_instance_valid(target): hide(); return

    _update_visual_state()
    var cam = get_viewport().get_camera_2d()
    if not cam: return
    
    var cam_pos = cam.get_screen_center_position()
    var target_pos = target.global_position
    var world_direction = (target_pos - cam_pos).normalized()
    
    var screen_center = screen_rect.size / 2
    var target_screen_pos = target.get_global_transform_with_canvas().origin
    var screen_direction = (target_screen_pos - screen_center).normalized()
    
    global_position = _get_intersection_point(screen_center, screen_direction, screen_rect, margin)
    # global_position — левый верхний угол Control, а не центр.
    # При целях справа/снизу сдвигаем на размер Control, чтобы внешняя кромка была
    # ровно на margin от края экрана (симметрия с левой/верхней стороной).
    if screen_direction.x > 0.0:
        global_position.x -= size.x
    if screen_direction.y > 0.0:
        global_position.y -= size.y
    if is_instance_valid(icon): icon.rotation = world_direction.angle()
    
    var dist = cam_pos.distance_to(target_pos)
    distance_label.text = str(int(dist / 100.0)) + "m"
    # Для курьера подпись дистанции скрывается — только золотая пульсирующая иконка.
    if is_instance_valid(distance_label):
        distance_label.visible = not (target is Courier)
    
    # Логика пульсации
    if target.is_in_group("safe_zone"):
        _start_pulse() # Зона всегда мигает синим
    elif target is Courier:
        _start_pulse()
    elif target is Camp and target.alignment == 1 and target.get("is_under_attack"):
        _start_pulse()
    elif target is Mine and target.get("is_under_attack"):
        _start_pulse()
    else:
        _stop_pulse()

func _update_visual_state() -> void:
    if not is_instance_valid(target): return
    
    # Иконка курьера — в 2 раза меньше остальных (золотой слиток крупнее стрелки).
    icon.scale = Vector2(0.5, 0.5) if target is Courier else Vector2.ONE
    
    if target.is_in_group("safe_zone"):
        modulate = Color.CYAN
        if safe_zone_icon: icon.texture = safe_zone_icon
        return

    if target is Courier:
        if not _is_pulsing: modulate = Color(1.0, 0.84, 0.0, 1.0)  # золотой
        if courier_icon: icon.texture = courier_icon
        return

    if target is RivalBoss:
        if not _is_pulsing: modulate = Color.YELLOW
        if boss_icon: icon.texture = boss_icon
    elif target is Mine:
        # Шахты игрока — дружественный стиль как у своих лагерей.
        # Вражеские/нейтральные шахты сюда не попадают (фильтр по группе player_mines в IndicatorManager).
        if not _is_pulsing: modulate = Color.CORNFLOWER_BLUE
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
    var pulse_color := Color.CYAN
    if target is Courier: pulse_color = Color(1.0, 0.84, 0.0, 1.0)
    elif not target.is_in_group("safe_zone"): pulse_color = Color.RED
    _tween = create_tween().set_loops()
    _tween.tween_property(self, "modulate", Color.WHITE, 0.2)
    _tween.tween_property(self, "modulate", pulse_color, 0.2)

func _stop_pulse() -> void:
    if not _is_pulsing: return
    _is_pulsing = false; if _tween: _tween.kill(); _update_visual_state()

func _get_intersection_point(center: Vector2, dir: Vector2, rect: Rect2, margin: float) -> Vector2:
    var half_rect = rect.size / 2 - Vector2(margin, margin)
    var x_ratio = abs(half_rect.x / dir.x) if dir.x != 0 else INF
    var y_ratio = abs(half_rect.y / dir.y) if dir.y != 0 else INF
    var min_ratio = min(x_ratio, y_ratio)
    return center + dir * min_ratio
