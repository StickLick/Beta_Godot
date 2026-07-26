class_name DebugPanel
extends CanvasLayer

@onready var control_node: Control = $Control
@onready var btn_levelup: Button = $Control/PanelContainer/ScrollContainer/VBoxContainer/Btn_LevelUp
@onready var btn_max_all: Button = $Control/PanelContainer/ScrollContainer/VBoxContainer/Btn_MaxAll
@onready var btn_evo_aura: Button = $Control/PanelContainer/ScrollContainer/VBoxContainer/Btn_Evo_Aura
@onready var btn_evo_spear: Button = $Control/PanelContainer/ScrollContainer/VBoxContainer/Btn_Evo_Spear
@onready var btn_evo_siege: Button = $Control/PanelContainer/ScrollContainer/VBoxContainer/Btn_Evo_Siege

var _was_paused_before: bool = false


func _ready() -> void:
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    control_node.process_mode = Node.PROCESS_MODE_ALWAYS
    
    btn_levelup.pressed.connect(_on_btn_levelup)
    btn_max_all.pressed.connect(_on_btn_max_all)
    btn_evo_aura.pressed.connect(_on_btn_evo.bind("res://Upgrades/Evolutions/AuraEvolution.tres"))
    btn_evo_spear.pressed.connect(_on_btn_evo.bind("res://Upgrades/Evolutions/SpearEvolution.tres"))
    btn_evo_siege.pressed.connect(_on_btn_evo.bind("res://Upgrades/Evolutions/BowSiegeEvolution.tres"))


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
        _toggle_panel()


func _toggle_panel() -> void:
    visible = !visible
    if visible:
        _was_paused_before = get_tree().paused
        get_tree().paused = true
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        var other_ui_visible = _is_any_ui_visible()
        get_tree().paused = other_ui_visible
        if other_ui_visible:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _is_any_ui_visible() -> bool:
    # Check group
    var ui_nodes = get_tree().get_nodes_in_group("ui")
    for node in ui_nodes:
        if is_instance_valid(node) and node is CanvasItem and node.visible:
            if node != self:
                return true
    # Check by name
    var upgrade_menu = get_tree().root.find_child("UpgradeMenu", true, false)
    if is_instance_valid(upgrade_menu) and upgrade_menu is CanvasItem and upgrade_menu.visible:
        return true
    return false


# ── Button callbacks ──

func _on_btn_levelup() -> void:
    var player = get_player()
    if not player:
        return
    var needed = player.xp_to_next_level - player.current_xp
    if needed > 0:
        player.collect_xp(needed)
    print("[DEBUG] Player leveled up to ", player.current_level)


func _on_btn_max_all() -> void:
    var player = get_player()
    if not player:
        return
    for key in player.tag_levels.keys():
        player.tag_levels[key] = 8
    player.inventory_updated.emit()
    print("[DEBUG] All tags set to level 8: ", player.tag_levels)


func _on_btn_evo(resource_path: String) -> void:
    var player = get_player()
    if not player:
        return
    var evo = load(resource_path) as Upgrade
    if not evo:
        push_error("[DEBUG] Failed to load evolution: " + resource_path)
        return
    player.apply_custom_upgrade(evo)
    print("[DEBUG] Force evolution applied: ", evo.name)


func get_player() -> Player:
    return get_tree().get_first_node_in_group("player") as Player