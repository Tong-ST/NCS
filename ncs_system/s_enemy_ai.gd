class_name S_EnemyAI
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_EnemyAI]).with_not([C_Dead]) # ftiler entities by components
	iterate_data([D_EnemyAI, D_Input]) # caching data


func ncs_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	if entities.is_empty(): return
	var current_entities = entities as Array[CharacterBody2D]
	var enemy_ai_pool = data_pools[0] as Array[D_EnemyAI] # allocate data for current frame use
	var input_pool = data_pools[1] as Array[D_Input] # same index as iterate_data abrove
	if not enemy_ai_pool or not input_pool: return

	# Iterate and fetching data process.
	for i in current_entities.size():
		var enemy_ai = enemy_ai_pool[i]
		var input_data = input_pool[i]

		# Always safely check for data that you query, use "continue" to skip loop.
		if not enemy_ai or not input_data:
			continue
		
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
