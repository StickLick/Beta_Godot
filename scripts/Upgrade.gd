extends Resource
class_name Upgrade

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var name: String
@export var icon: Texture2D
@export var description: String
@export var stat_to_modify: String # Например: "damage", "speed", "max_health"
@export var amount: float

@export_group("Evolution System")
@export var rarity: Rarity = Rarity.COMMON
@export var prerequisites: Array[String] = [] # Список имен апгрейдов, нужных для этого
@export var is_unique: bool = false # Если true, апгрейд исчезает из пула после выбора
