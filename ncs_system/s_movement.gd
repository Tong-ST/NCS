class_name S_Movement
extends NCSSystemBase

## Step 1: Explicitly configure entity query template on initialization
func setup_query() -> void:
	# Name of Components Matter!, Make sure they are the same in your scene node
	with_all([C_Movement, C_Input]).with_not([C_Dead])
	iterate_data([D_Movement, D_Input])

## Step 2: Run your logic loop.
func _physics_process(delta: float) -> void:
	var move_pool = get_data_pool(0)
	var input_pool = get_data_pool(1)
	# Iterate through all filtered entities.
	for i in entities.size():
		# Pull essential body/data for this system
		var ent = entities[i]
		var body = ent.get_parent() as CharacterBody2D

		# Get data required data
		var move_data = move_pool[i] as D_Movement
		var input_data = input_pool[i] as D_Input
		
		# Always safety check for those fetched data
		if not is_instance_valid(body) or not move_data or not input_data: 
			continue

		# Handle multi-component logic relationships e.g. Movement and Input
		var current_input = input_data.movement_vector
		
		# Process physics
		if current_input != Vector2.ZERO:
			move_data.velocity = move_data.velocity.move_toward(current_input * move_data.max_speed, move_data.acceleration * delta)
		else:
			move_data.velocity = move_data.velocity.move_toward(Vector2.ZERO, move_data.acceleration * delta)
			
		#body.velocity = move_data.velocity
		#body.move_and_slide()
		body.global_position += move_data.velocity * delta
