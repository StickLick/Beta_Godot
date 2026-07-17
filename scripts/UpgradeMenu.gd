extends Node

@export var upgrade_menu_scene: PackedScene
@onready var _ui_container: Control = %UpgradePanel
@export var all_available_upgrades: Array[Upgrade]

var _active_menu: Control = null
var _pending_upgrades: int = 0 # Очередь уровней

## Основной метод открытия меню
func open_upgrade_menu(available_upgrades: Array[Upgrade]) -> void:    
    if available_upgrades.size() < 3:
        push_error("Upgrade pool invalid. Requires at least 3 unique upgrades.")
        return

    # Ставим игру на паузу
    get_tree().paused = true

    if not is_instance_valid(upgrade_menu_scene) or not is_instance_valid(_ui_container):
        push_error("Missing configuration: Assign Upgrade Menu PackedScene and ensure %UpgradePanel exists.")
        get_tree().paused = false
        return

    # Выбираем 3 случайных улучшения
    var shuffled_pool: Array[Upgrade] = available_upgrades.duplicate()
    shuffled_pool.shuffle()
    var selected_upgrades: Array[Upgrade] = shuffled_pool.slice(0, 3)

    _spawn_menu(selected_upgrades)

func _spawn_menu(upgrades: Array[Upgrade]) -> void:
    _active_menu = upgrade_menu_scene.instantiate() as Control
    _ui_container.add_child(_active_menu)
    
    # Убеждаемся, что меню на переднем плане
    _active_menu.move_to_front()

    var options_vbox: VBoxContainer = _active_menu.get_node_or_null("UpgradeOptions")
    if not is_instance_valid(options_vbox):
        push_error("'UpgradeOptions' VBoxContainer not found in menu scene hierarchy.")
        get_tree().paused = false
        _active_menu.queue_free()
        return

    for upgrade in upgrades:
        var btn := Button.new()
        btn.text = upgrade.name
        btn.icon = upgrade.icon
        btn.tooltip_text = "%s\n%s\nModify: %s (%+f)" % [upgrade.name, upgrade.description, upgrade.stat_to_modify, upgrade.amount]
        btn.custom_minimum_size = Vector2(240, 180)
        
        btn.pressed.connect(_on_upgrade_selected.bind(upgrade))
        options_vbox.add_child(btn)

func _on_upgrade_selected(upgrade: Upgrade) -> void:
    var player: Player = get_tree().get_first_node_in_group("player") as Player
    if not is_instance_valid(player):
        get_tree().paused = false
        return

    print("--- Applying Upgrade: ", upgrade.name, " ---")

    if player.has_method("apply_custom_upgrade"):
        player.apply_custom_upgrade(upgrade)

    var stat: String = upgrade.stat_to_modify
    var amount: float = float(upgrade.amount)
    var applied: bool = false

    # Применение характеристик
    if stat in player:
        var current_val = player.get(stat)
        player.set(stat, current_val + amount)
        applied = true

    if not applied:
        var weapons = player.find_children("*", "WeaponComponent", true)
        for weapon in weapons:
            if stat in weapon:
                var current_val = weapon.get(stat)
                weapon.set(stat, current_val + amount)
                applied = true

    # Очищаем текущее меню
    _cleanup_menu()

    # ПРОВЕРКА ОЧЕРЕДИ:
    if _pending_upgrades > 0:
        print("[UPGRADE] More levels pending. Opening next menu. Remaining: ", _pending_upgrades)
        _pending_upgrades -= 1
        open_upgrade_menu(all_available_upgrades)
    else:
        # Если уровней больше нет — снимаем паузу
        print("[UPGRADE] All levels processed. Resuming game.")
        get_tree().paused = false

func _cleanup_menu() -> void:
    if is_instance_valid(_active_menu):
        _active_menu.queue_free()
        _active_menu = null

## ЭТОТ МЕТОД ВЫЗЫВАЕТСЯ СИГНАЛОМ ОТ ИГРОКА
func _on_player_level_up(_new_level: int) -> void:
    if _active_menu == null:
        # Если меню не открыто — открываем
        open_upgrade_menu(all_available_upgrades)
    else:
        # Если меню уже висит на экране — добавляем уровень в очередь
        _pending_upgrades += 1
        print("[UPGRADE] Level up during pause! Added to queue. Pending: ", _pending_upgrades)
