class_name DataHealth
extends NCSDataBase

@export_enum("ALIVE", "DEAD") var state: String = "ALIVE"

@export var max_health: float = 100.0
@export var current_health: float = 100.0
