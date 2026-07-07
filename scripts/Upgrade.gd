extends Resource
class_name Upgrade

@export var name: String
@export var icon: Texture2D
@export var description: String
@export var stat_to_modify: String # Например: "damage", "speed", "max_health"
@export var amount: float
