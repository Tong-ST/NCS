class_name D_Movement
extends NCSDataBase

@export var max_speed: float = 300.0
@export var acceleration: float = 2000.0

var input_vector := Vector2.ZERO
var velocity := Vector2.ZERO

var next_global_pos := Vector2.ZERO
