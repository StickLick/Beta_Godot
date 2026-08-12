extends Control
## World-space UI для шахты: уровень, хранилище/строительство, HP-бар.
## Только визуальная логика — данные приходят из Mine.
## Все размеры/шрифты/позиции редактируются в MineWorldUI.tscn.

@onready var level_label: Label = $MineLevelLabel
@onready var storage_label: Label = $MineStorageLabel
@onready var health_bar: ProgressBar = $HealthBar


func update_level(level: int) -> void:
    level_label.text = "Шахта Lv.%d" % level


func update_storage(text: String) -> void:
    storage_label.text = text
    storage_label.visible = text != ""


func update_health(current: float, max_val: float) -> void:
    health_bar.max_value = max_val
    health_bar.value = current


func set_visible_state(alignment: int) -> void:
    match alignment:
        0:  # NEUTRAL — скрыть весь UI
            hide()
        1:  # PLAYER — уровень + хранилище + HP
            show()
            storage_label.show()
        2:  # RIVAL — уровень + HP, без хранилища
            show()
            storage_label.hide()
