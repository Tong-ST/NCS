class_name EnemyAISystem
extends NCSSystemBase

func _physics_process(_delta: float) -> void:
	# 1. Find the player character body in the game world
	var player_body = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player_body): 
		return

	# 2. Iterate through all entities that explicitly have the EnemyAI component node!
	for comp in active_components:
		var body = comp.owner_node as CharacterBody2D
		
		# Skip if entity is player
		if not is_instance_valid(body) or body.is_in_group("player"): 
			continue
		
		# 3. Pull essential data for chasing logic
		var enemy_ai = comp.config_node.get_data("EnemyAIData") as EnemyAIData
		var input_stats = comp.config_node.get_data("InputData") as InputData

		# Skip chasing if not aggressive
		if enemy_ai.is_aggressive == false:
			input_stats.movement_vector = Vector2.ZERO
			continue

		if input_stats:
			var direction = (player_body.global_position - body.global_position).normalized()
			input_stats.movement_vector = direction
