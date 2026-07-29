## WeaponManager — фабрика оружия.
## Спавнит сцену оружия из Upgrade ресурса, больше не содержит боевой логики.
## Боевая логика разнесена:
##   Aura  → res://scripts/weapons/aura_weapon.gd  (AuraWeapon extends BaseWeapon)
##   Spear → res://scripts/weapons/spear_weapon.gd (SpearWeapon extends BaseWeapon)
class_name WeaponManager
extends Node2D


## Загружает сцену для upgrade.weapon_tag, инстанцирует и возвращает.
## Используется из Player._spawn_weapon_scene().
static func spawn_weapon(upgrade: Upgrade, parent: Node) -> BaseWeapon:
    if not upgrade or upgrade.weapon_tag == "":
        push_error("[WeaponManager] upgrade missing or weapon_tag empty")
        return null

    var scene_path = "res://Assets/Scenes/" + upgrade.weapon_tag + "Weapon.tscn"
    print("[WeaponManager] trying to load: ", scene_path)
    var weapon_scene = load(scene_path) as PackedScene
    if not weapon_scene:
        push_warning("[WeaponManager] No weapon scene found at: " + scene_path)
        return null

    var new_weapon = weapon_scene.instantiate()
    if not new_weapon is BaseWeapon:
        push_error("[WeaponManager] scene root is not BaseWeapon: " + scene_path)
        new_weapon.queue_free()
        return null

    new_weapon.weapon_tag = upgrade.weapon_tag
    parent.add_child(new_weapon)
    print("[WeaponManager] spawned ", new_weapon.name, " (tag=", new_weapon.weapon_tag, ")")
    return new_weapon
