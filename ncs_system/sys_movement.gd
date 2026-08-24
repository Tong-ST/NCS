class_name SysMovement
extends SystemBase


func setup_query() -> void:
	with_all([CompMovement]) # filter entities
	iterate_data([DataMovement, DataInput])  # caching data & filter all ent. must have these data.


func ncs_physics_process(entities: Array[Node], data_pools: Array, _node_pools: Array, delta: float) -> void:
	var current_entities = entities as Array[CharacterBody2D]
	var move_pool = data_pools[0] as Array[DataMovement]
	var input_pool = data_pools[1] as Array[DataInput]

	# Iterate and prepare data for each entity.
	for i in current_entities.size():
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		var move_data = move_pool[i]
		var input_data = input_pool[i]

		# Run regular logic:
		var current_input = input_data.movement_vector
		if current_input != Vector2.ZERO:
			move_data.velocity = move_data.velocity.move_toward(
					current_input * move_data.max_speed,
					move_data.acceleration * delta
			)
		else:
			move_data.velocity = move_data.velocity.move_toward(
					Vector2.ZERO, move_data.acceleration * delta
			)

		# Simulate movement purely in data and separate scene-tree mutation to SysVisual
		if not move_data.is_pos_initialized:
			move_data.next_global_pos = ent.global_position
			move_data.is_pos_initialized = true
		move_data.next_global_pos += move_data.velocity * delta
