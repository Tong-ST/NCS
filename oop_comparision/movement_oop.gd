class_name MovementOOP
extends Node

@export var actor: Node
@export var input_comp: InputOOP


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(input_comp): 
		return
		
	if not actor.is_aggressive:
		actor.current_velocity = Vector2.ZERO
		return

	var current_input = input_comp.movement_vector
	
	if current_input != Vector2.ZERO:
		actor.current_velocity = actor.current_velocity.move_toward(
			current_input * actor.max_speed, 
			actor.acceleration * delta
		)
	else:
		actor.current_velocity = actor.current_velocity.move_toward(
			Vector2.ZERO, 
			actor.acceleration * delta
		)
		
	actor.global_position += actor.current_velocity * delta
