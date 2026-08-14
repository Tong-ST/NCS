class_name D_EnemyAI
extends NCSDataBase

@export var is_aggressive: bool = true

var current_wander_direction: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var choose_time_target: float = 0.0
var is_idling: bool = false
