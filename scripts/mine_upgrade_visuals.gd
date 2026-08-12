extends Node2D
## Визуальный слой апгрейдов шахты: индикаторы экономического (золото) и военного (сталь) уровня.
## Чисто визуальная логика — данные (уровни) приходят из Mine.
## Все позиции/формы/цвета редактируются через Inspector в MineUpgradeVisuals.tscn.

## Слоты экономического уровня (Polygon2D-наследники), от 1 до MAX_ECONOMIC_LEVEL.
@export var eco_pips: Array[NodePath] = []
## Слоты военного уровня (Polygon2D-наследники), от 0 до MAX_MILITARY_LEVEL.
@export var mil_pips: Array[NodePath] = []

## Цвет активного экономического пипса.
@export var eco_color := Color(1.0, 0.84, 0.0, 1.0)
## Цвет активного военного пипса.
@export var mil_color := Color(0.85, 0.25, 0.25, 1.0)
## Цвет пустого слота (фон — показывает потенциал апгрейда).
@export var empty_color := Color(0.35, 0.35, 0.4, 0.35)
## Показывать ли пустые слоты рядом с заполненными.
@export var show_empty_slots := true

var _last_eco := 0
var _last_mil := 0


func update_levels(economic_level: int, military_level: int) -> void:
    ## Обновляет состояние индикаторов по текущим уровням шахты.
    ## Вызывается из Mine._update_visuals().
    var eco_changed := economic_level != _last_eco
    var mil_changed := military_level != _last_mil
    _last_eco = economic_level
    _last_mil = military_level

    _set_pips(eco_pips, economic_level, eco_color, eco_changed)
    _set_pips(mil_pips, military_level, mil_color, mil_changed)


func _set_pips(paths: Array[NodePath], active: int, active_color: Color, animate: bool) -> void:
    for i in paths.size():
        var pip := get_node_or_null(paths[i]) as Polygon2D
        if not is_instance_valid(pip):
            continue
        var filled := i < active
        pip.color = active_color if filled else empty_color
        pip.visible = filled or show_empty_slots
        if animate and filled:
            _pop_pip(pip)


func _pop_pip(pip: Polygon2D) -> void:
    ## Лёгкий scale-пульс при повышении уровня (чисто визуально, без геймплея).
    pip.scale = Vector2.ONE * 1.6
    var tween := create_tween()
    tween.tween_property(pip, "scale", Vector2.ONE, 0.25)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
