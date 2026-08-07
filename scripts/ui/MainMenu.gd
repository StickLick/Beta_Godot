extends Control
class_name MainMenu

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var shop_button: Button = %ShopButton
@onready var shop_panel: Control = %ShopPanel
@onready var luck_button: Button = %LuckButton
@onready var gacha_screen: Control = get_node_or_null("GachaScreen")
@onready var hero_select_screen: Control = get_node_or_null("HeroSelectScreen")
@onready var collection_screen: Control = get_node_or_null("CollectionScreen")


func _ready() -> void:
    GameManager.stop_game()
    quit_button.pressed.connect(_on_quit_pressed)
    if is_instance_valid(shop_panel):
        shop_panel.hide()
        _refresh_shop()
    if is_instance_valid(gacha_screen):
        gacha_screen.hide()
    if is_instance_valid(hero_select_screen):
        hero_select_screen.hide()
    if is_instance_valid(collection_screen):
        collection_screen.hide()


func _meta() -> Node:
    return get_node_or_null("/root/MetaProgress")


func _on_start_pressed() -> void:
    if is_instance_valid(hero_select_screen):
        hero_select_screen.visible = true
        if hero_select_screen.has_method("refresh"):
            hero_select_screen.refresh()


func _on_quit_pressed() -> void:
    get_tree().quit()


# --- МАГАЗИН ---

func _on_shop_pressed() -> void:
    if is_instance_valid(shop_panel):
        shop_panel.visible = not shop_panel.visible
        if shop_panel.visible:
            _refresh_shop()


func _on_luck_pressed() -> void:
    if is_instance_valid(gacha_screen):
        gacha_screen.visible = not gacha_screen.visible
        if gacha_screen.visible and gacha_screen.has_method("refresh"):
            gacha_screen.refresh()


func _on_collection_pressed() -> void:
    if is_instance_valid(collection_screen):
        collection_screen.visible = not collection_screen.visible
        if collection_screen.visible and collection_screen.has_method("refresh"):
            collection_screen.refresh()


func _refresh_shop() -> void:
    var meta: Node = _meta()
    if meta == null:
        return
    var currency_label: Label = shop_panel.get_node_or_null("CenterContainer/VBoxContainer/CurrencyLabel")
    var weapon_button: Button = shop_panel.get_node_or_null("CenterContainer/VBoxContainer/WeaponSlotButton")
    var passive_button: Button = shop_panel.get_node_or_null("CenterContainer/VBoxContainer/PassiveSlotButton")
    if currency_label:
        currency_label.text = "Валюта: %d" % GameManager.get_meta_currency()
    if weapon_button:
        var w_cur: int = meta.get_weapon_slots()
        var w_max: int = meta.MAX_WEAPON_SLOTS
        if w_cur >= w_max:
            weapon_button.text = "Слот оружия: MAX"
            weapon_button.disabled = true
        else:
            var price: int = meta.get_weapon_slot_upgrade_price()
            weapon_button.text = "Слот оружия (%d -> %d) — %d" % [w_cur, w_cur + 1, price]
            weapon_button.disabled = price < 0 or not meta.can_afford(price)
    if passive_button:
        var p_cur: int = meta.get_passive_slots()
        var p_max: int = meta.MAX_PASSIVE_SLOTS
        if p_cur >= p_max:
            passive_button.text = "Слот пассивок: MAX"
            passive_button.disabled = true
        else:
            var price: int = meta.get_passive_slot_upgrade_price()
            passive_button.text = "Слот пассивок (%d -> %d) — %d" % [p_cur, p_cur + 1, price]
            passive_button.disabled = price < 0 or not meta.can_afford(price)


func _on_weapon_slot_pressed() -> void:
    var meta: Node = _meta()
    if meta and meta.increase_weapon_slots():
        _refresh_shop()


func _on_passive_slot_pressed() -> void:
    var meta: Node = _meta()
    if meta and meta.increase_passive_slots():
        _refresh_shop()
