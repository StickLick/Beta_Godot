extends Node

@export var upgrade_menu_scene: PackedScene
@onready var _ui_container: Control = %UpgradePanel # Reference to a Control covering the screen in your UI root
@export var all_available_upgrades: Array[Upgrade]

var _active_menu: Control = null

## Opens the upgrade selection menu, pauses the game, and handles lifecycle
func open_upgrade_menu(available_upgrades: Array[Upgrade]) -> void:
    # --- ДЕТЕКТОР ---
    print("DEBUG: Пул апгрейдов содержит ", available_upgrades.size(), " элементов:")
    for upgrade in available_upgrades:
        print(" - ", upgrade.name)
    # ----------------
    
    if available_upgrades.size() < 3:
        push_error("Upgrade pool invalid. Requires at least 3 unique upgrades.")
        return

    # Pause all gameplay logic while keeping UI responsive
    get_tree().paused = true

    if not is_instance_valid(upgrade_menu_scene) or not is_instance_valid(_ui_container):
        push_error("Missing configuration: Assign Upgrade Menu PackedScene and ensure %UpgradePanel exists.")
        get_tree().paused = false
        return

    # Select 3 unique, random upgrades
    var shuffled_pool: Array[Upgrade] = available_upgrades.duplicate()
    shuffled_pool.shuffle()
    var selected_upgrades: Array[Upgrade] = shuffled_pool.slice(0, 3)

    _spawn_menu(selected_upgrades)

func _spawn_menu(upgrades: Array[Upgrade]) -> void:
    # Instantiate and anchor to the UI layer
    _active_menu = upgrade_menu_scene.instantiate() as Control
    _ui_container.add_child(_active_menu)

    # Locate the dynamic container inside the instantiated scene
    var options_vbox: VBoxContainer = _active_menu.get_node("UpgradeOptions")
    if not is_instance_valid(options_vbox):
        push_error("'UpgradeOptions' VBoxContainer not found in menu scene hierarchy.")
        get_tree().paused = false
        _active_menu.queue_free()
        return

    # Dynamically populate buttons
    for upgrade in upgrades:
        var btn := Button.new()
        btn.text = upgrade.name
        btn.icon = upgrade.icon
        btn.tooltip_text = "%s\n%s\nModify: %s (%+f)" % [upgrade.name, upgrade.description, upgrade.stat_to_modify, upgrade.amount]
        btn.custom_minimum_size = Vector2(240, 180)
        
        btn.pressed.connect(_on_upgrade_selected.bind(upgrade))
        options_vbox.add_child(btn)

func _on_upgrade_selected(upgrade: Upgrade) -> void:
    
    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if not is_instance_valid(player):
        get_tree().paused = false
        return

    var stat_to_modify: String = upgrade.stat_to_modify
    if stat_to_modify in player:
        var raw_value: Variant = player.get(stat_to_modify)
        var current_value: float = float(raw_value) if raw_value != null else 0.0
        var new_value: float = current_value + float(upgrade.amount)
        
        # --- ЛОГИРОВАНИЕ ДЛЯ ТЕСТА ---
        print("Upgrade: ", stat_to_modify, " | Old: ", current_value, " | New: ", new_value)
        # -----------------------------
        
        player.set(stat_to_modify, new_value)
    else:
        print("Ошибка: У игрока нет свойства ", stat_to_modify)

    get_tree().paused = false
    _cleanup_menu()

func _cleanup_menu() -> void:
    if is_instance_valid(_active_menu):
        _active_menu.queue_free()
        _active_menu = null
