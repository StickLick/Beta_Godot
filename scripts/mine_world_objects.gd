extends Node2D
## Визуальные world-объекты шахты: рабочие у руды и форт/башни.
## Только визуальные объекты — никакой геймплейной логики.
## Все позиции контролируются Marker2D-узлами в редакторе (Inspector-driven).
## Данные (уровни) приходят из Mine.

## Сцена рабочего (назначается дизайнером в Inspector).
@export var worker_scene: PackedScene
## Сцена форта (назначается дизайнером в Inspector).
@export var fort_scene: PackedScene
## Сцена защитника форта (FortArcher и т.п.; спавнится на DefenderSocket форта).
@export var defender_scene: PackedScene
## Позиции для рабочих (Marker2D — двигаются в редакторе).
@export var worker_slots: Array[Marker2D] = []
## Позиция форта (Marker2D — двигается в редакторе).
@export var fort_position: Marker2D

@onready var worker_container: Node2D = $WorkerContainer
@onready var fort_container: Node2D = $FortContainer

var _spawned_workers: Array = []
var _current_fort: Node2D = null
var _spawned_defender: Node2D = null


## Единая точка входа из Mine._update_visuals().
func update_levels(economic_level: int, military_level: int) -> void:
    update_economic_level(economic_level)
    update_military_level(military_level)


## Правило: уровень 1 → 1 рабочий, 2 → 2 рабочих, 3 → 3 рабочих.
func update_economic_level(level: int) -> void:
    _clear_workers()
    if not worker_scene or worker_slots.is_empty():
        return
    var count := clampi(level, 1, worker_slots.size())
    for i in count:
        var w := worker_scene.instantiate()
        worker_container.add_child(w)
        w.global_position = worker_slots[i].global_position
        _spawned_workers.append(w)


## Правило: уровень 0 → форт и защитник убраны, уровень > 0 → форт на FortPosition
## и защитник (турель) на DefenderSocket форта.
## military_level передаётся защитнику → FortArcher масштабирует свои статы.
func update_military_level(level: int) -> void:
    _clear_fort()
    if level > 0 and fort_scene and is_instance_valid(fort_position):
        var fort := fort_scene.instantiate()
        fort_container.add_child(fort)
        fort.global_position = fort_position.global_position
        _current_fort = fort
        _spawn_defender(fort, level)


func _clear_workers() -> void:
    for w in _spawned_workers:
        if is_instance_valid(w):
            w.queue_free()
    _spawned_workers.clear()


func _spawn_defender(fort: Node2D, level: int) -> void:
    ## Спавнит защитника (FortArcher) на позицию DefenderSocket форта.
    ## Сокет — Marker2D в MineFort.tscn, позиция редактируется дизайнером.
    ## Передаёт military_level защитнику сразу при спавне.
    if not defender_scene:
        return
    var socket := fort.get_node_or_null("DefenderSocket") as Marker2D
    if not is_instance_valid(socket):
        return
    var defender := defender_scene.instantiate()
    fort_container.add_child(defender)
    defender.global_position = socket.global_position
    if defender.has_method("set_fort_level"):
        defender.set_fort_level(level)
    _spawned_defender = defender


func _clear_fort() -> void:
    if is_instance_valid(_spawned_defender):
        _spawned_defender.queue_free()
    _spawned_defender = null
    if is_instance_valid(_current_fort):
        _current_fort.queue_free()
    _current_fort = null
