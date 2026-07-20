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

@export_group("Weapon System")
@export var target_weapon_name: String = "" # Если заполнено, апгрейд качает это оружие
@export var evolved_weapon_scene: PackedScene # Сцена нового оружия для эволюции
