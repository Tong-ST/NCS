class_name S_EnemyAI
extends NCSSystemBase

func setup_query() -> void:
	with_all([C_EnemyAI]).with_not([C_Dead])
	iterate_data([D_EnemyAI, D_Input])

func _physics_process(_delta: float) -> void:
	var enemy_ai_pool = get_data_pool(0)
	var input_pool = get_data_pool(1)

	for i in entities.size():
		var enemy_ai = enemy_ai_pool[i] as D_EnemyAI
		var input_data = input_pool[i] as D_Input

		if not enemy_ai.is_aggressive:
			input_data.movement_vector = Vector2.ZERO
			continue

		enemy_ai.state_timer += _delta

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
