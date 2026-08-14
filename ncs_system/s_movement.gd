class_name S_Movement
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Movement, C_Input]).with_not([C_Dead]) # filter entitie
	iterate_data([D_Movement, D_Input]) # caching data


func ncs_physics_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	var move_pool = data_pools[0] # allocate data pool
	var input_pool = data_pools[1] # same index as iterate_data appbrove
	
	# Iterate and fetching data process.
	for i in entities.size():
		var ent = entities[i] as CharacterBody2D
		var move_data = move_pool[i] as D_Movement
		var input_data = input_pool[i] as D_Input

		# Always safely check for data that you query, use "continue" to skip loop.
		if not is_instance_valid(ent) or not move_data or not input_data:
			continue
		
		# Run regular logic:
		var current_input = input_data.movement_vector
		if current_input != Vector2.ZERO:
			move_data.velocity = move_data.velocity.move_toward(current_input * move_data.max_speed, move_data.acceleration * delta)
		else:
			move_data.velocity = move_data.velocity.move_toward(Vector2.ZERO, move_data.acceleration * delta)
		ent.global_position += move_data.velocity * delta
