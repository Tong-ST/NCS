class_name D_Health
extends NCSDataBase

@export_enum("ALIVE", "DEAD") var status: String = "ALIVE"

@export var max_health: float = 100.0
@export var current_health: float = 100.0
