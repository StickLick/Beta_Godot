extends Resource
class_name Upgrade

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var name: String
@export var icon: Texture2D
@export var description: String
@export var stat_to_modify: String 
@export var amount: float

@export_group("Evolution System")
@export var rarity: Rarity = Rarity.COMMON
@export var prerequisites: Array[String] = [] 
@export var is_unique: bool = false 
@export var required_passive_tag: String = ""
@export var max_level_for_evo: int = 8

@export_group("Weapon System")
@export var is_weapon: bool = false 
@export var weapon_tag: String = "General" # "Spear", "Aura", "General"
@export var target_weapon_name: String = "" 
@export var evolved_weapon_scene: PackedScene 
@export var change_mechanic_on_apply: bool = false
