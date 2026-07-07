extends Node2D

func _ready() -> void:
    var player: Player = $Player
    var upgrade_menu = $UpgradeMenu
    
    # Соединяем: при уровне -> вызываем меню, передавая массив из самого менеджера
    player.level_up.connect(func(_new_level): upgrade_menu.open_upgrade_menu(upgrade_menu.all_available_upgrades))
