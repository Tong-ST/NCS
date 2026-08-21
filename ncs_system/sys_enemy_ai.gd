class_name SysEnemyAI
extends NCSSystemBase


func setup_query() -> void:
	with_all([CompEnemyAI]) # ftiler entities by components
	iterate_data([DataEnemyAI, DataInput]) # caching data & filter all ent. must have these data.


func ncs_process(entities: Array[Node], data_pools: Array, _node_pools: Array, delta: float) -> void:
	var current_entities = entities as Array[CharacterBody2D]
	var enemy_ai_pool = data_pools[0] as Array[DataEnemyAI] # allocate data for current frame use
	var input_pool = data_pools[1] as Array[DataInput] # same index as iterate_data abrove

	# Iterate and prepare data for each entity.
	for i in current_entities.size():
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		var enemy_ai = enemy_ai_pool[i]
		var input_data = input_pool[i]

		# Run regular logic:
		if not enemy_ai.is_aggressive:
			input_data.movement_vector = Vector2.ZERO
			continue

		enemy_ai.state_timer += delta

		if enemy_ai.state_timer >= enemy_ai.choose_time_target:
			enemy_ai.state_timer = 0.0
			enemy_ai.choose_time_target = randf_range(1.5, 3.5)

			if randf() > 0.5:
				enemy_ai.is_idling = true
				enemy_ai.current_wander_direction = Vector2.ZERO
			else:
				enemy_ai.is_idling = false
				var random_angle = randf_range(0.0, TAU)
				enemy_ai.current_wander_direction = Vector2(cos(random_angle), sin(random_angle))

		input_data.movement_vector = enemy_ai.current_wander_direction
