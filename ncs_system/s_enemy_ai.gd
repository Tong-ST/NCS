class_name S_EnemyAI
extends NCSSystemBase

## Step 1: Explicitly configure entity query template on initialization
func setup_query() -> void:
	# Name of Components Matter!, Make sure they are the same in your scene node
	with_all(["C_EnemyAI"]).with_not(["C_Dead", "C_Player"])

## Step 2: Run your logic loop.
func _physics_process(_delta: float) -> void:
	# Find the player character body in the game world
	var player_body = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player_body): 
		return

	# Iterate through all filtered entities.
	for ent in entities:
		# Pull essential body/data for this system
		var body = ent.get_parent() as CharacterBody2D
		var enemy_ai = ent.get_data("D_EnemyAI") as D_EnemyAI
		var input_stats = ent.get_data("D_Input") as D_Input

		# Always safety check for those fetched data
		if not is_instance_valid(body) or not enemy_ai or not input_stats:
			# Use continue to skip ent that don't have those
			# If use return, It might break whole loop and have some weird behavior.
			continue

		# Skip chasing if not aggressive
		if enemy_ai.is_aggressive == false:
			input_stats.movement_vector = Vector2.ZERO
			continue

		# Apply data to D_Input so it can be use in S_Movement
		var direction = (player_body.global_position - body.global_position).normalized()
		input_stats.movement_vector = direction
