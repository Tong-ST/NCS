class_name EnemyAIOOP
extends Node

@export var actor: Node
@export var input_comp: InputOOP

var state_timer: float = 0.0
var choose_time_target: float = 0.0
var is_idling: bool = false


func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(input_comp): 
		return
		
	if not actor.is_aggressive:
		input_comp.movement_vector = Vector2.ZERO
		return

	state_timer += delta

	if state_timer >= choose_time_target:
		state_timer = 0.0
		choose_time_target = randf_range(1.5, 3.5)
		
		if randf() > 0.5:
			is_idling = true
			input_comp.movement_vector = Vector2.ZERO
		else:
			is_idling = false
			var random_angle = randf_range(0.0, TAU)
			input_comp.movement_vector = Vector2(cos(random_angle), sin(random_angle))
