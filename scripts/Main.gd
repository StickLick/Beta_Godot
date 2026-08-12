extends Node2D

@export var map_rect: Rect2 = Rect2(-3000, -3000, 6000, 6000)
@export var boss_scene: PackedScene
@export var ore_count: int = 8
@export var ore_min_distance: float = 800.0

var boss_spawned: bool = false
var _ore_generator: OreGenerator

func _ready() -> void:
    # Сохраняем границы для всех систем
    GameManager.map_rect = map_rect
    GameManager.set_meta("map_rect", map_rect)
    _setup_boundaries()
    _generate_ore_nodes()

func _process(_delta: float) -> void:
    # Спавн босса (600с = 10 мин)
    if not boss_spawned and GameManager.time_elapsed >= 600.0:
        _spawn_rival_boss()

func _setup_boundaries() -> void:
    var bounds = get_node_or_null("MapBoundaries")
    if not bounds: return
    
    var shapes = bounds.get_children()
    var thickness = 400.0 # Стены толще для надежности
    
    # Лево, Право, Верх, Низ
    _set_wall(shapes[0], Vector2(map_rect.position.x - thickness/2, map_rect.get_center().y), Vector2(thickness, map_rect.size.y + thickness))
    _set_wall(shapes[1], Vector2(map_rect.end.x + thickness/2, map_rect.get_center().y), Vector2(thickness, map_rect.size.y + thickness))
    _set_wall(shapes[2], Vector2(map_rect.get_center().x, map_rect.position.y - thickness/2), Vector2(map_rect.size.x + thickness, thickness))
    _set_wall(shapes[3], Vector2(map_rect.get_center().x, map_rect.end.y + thickness/2), Vector2(map_rect.size.x + thickness, thickness))

func _set_wall(node: CollisionShape2D, pos: Vector2, size: Vector2) -> void:
    node.global_position = pos
    var shape = RectangleShape2D.new()
    shape.size = size
    node.shape = shape

func _generate_ore_nodes() -> void:
    _ore_generator = OreGenerator.new()
    _ore_generator.ore_count = ore_count
    _ore_generator.min_distance = ore_min_distance
    add_child(_ore_generator)

func _spawn_rival_boss() -> void:
    if not boss_scene: return
    boss_spawned = true
    var boss = boss_scene.instantiate()
    
    # Спавним босса рядом с игроком
    var player = get_tree().get_first_node_in_group("player")
    if player:
        boss.global_position = player.global_position + Vector2(600, 300)
    else:
        boss.global_position = Vector2.ZERO
        
    add_child(boss)
    print("[SYSTEM] RIVAL BOSS MATERIALIZED")
