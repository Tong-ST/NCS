class_name S_EnemyAI
extends NCSSystemBase

## Step 1: Explicitly configure entity query template on initialization
func setup_query() -> void:
	# Keep query constraints beautifully strict and type-safe
	with_all([C_EnemyAI]).with_not([C_Dead])
	iterate_data([D_EnemyAI, D_Input])

## Step 2: Run your logic loop.
func _physics_process(_delta: float) -> void:
	# Find the player character body in the game world
	var player_body = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player_body): 
		return

	# Extract our flat memory pools once at the top of the frame pass
	var enemy_ai_pool = get_data_pool(0)
	var input_pool = get_data_pool(1)

	for i in entities.size():
		var ent = entities[i]
		var body = ent.get_parent() as CharacterBody2D

		# 🎯 THE INDEX POINTER FIX: 
		# Both pools now correctly use 'i' to match their memory tracking rows!
		var enemy_ai = enemy_ai_pool[i] as D_EnemyAI
		var input_data = input_pool[i] as D_Input

		# Safety check for fetched data blocks
		if not is_instance_valid(body) or not enemy_ai or not input_data:
			continue

		# Skip chasing if not aggressive
		if not enemy_ai.is_aggressive:
			input_data.movement_vector = Vector2.ZERO
			continue

		# Calculate the clean direction vector towards our player target
		var direction = (player_body.global_position - body.global_position).normalized()
		
		# Write it straight into their matching data slot row safely
		input_data.movement_vector = direction
