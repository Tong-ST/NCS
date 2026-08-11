class_name MovementSystem
extends NCSSystemBase


func _physics_process(delta: float) -> void:
	for comp in active_components:
		# Use comp.owner_node will get ref. at parent/owner node
		var body = comp.owner_node as CharacterBody2D
		var move_stats = comp.data as MovementData # use comp.data to get own comp data

		if not is_instance_valid(body) or not move_stats: 
			continue

		# Sibling Look up to access data of other components
		var input_stats = comp.config_node.get_data("InputData") as InputData
		var current_input = input_stats.movement_vector if input_stats else Vector2.ZERO

		# Calculate physics logic
		if current_input != Vector2.ZERO:
			move_stats.velocity = move_stats.velocity.move_toward(current_input * move_stats.max_speed, move_stats.acceleration * delta)
		else:
			move_stats.velocity = move_stats.velocity.move_toward(Vector2.ZERO, move_stats.acceleration * delta)
			
		body.velocity = move_stats.velocity
		body.move_and_slide()
