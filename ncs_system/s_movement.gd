class_name S_Movement
extends NCSSystemBase

func setup_query() -> void:
	with_all([C_Movement, C_Input]).with_not([C_Dead])
	iterate_data([D_Movement, D_Input])

func _physics_process(delta: float) -> void:
	# 🎯 THE PERFORMANCE MASTERY EXTRACTION:
	# Grab your pre-sorted, type-safe flat channels outside the loop!
	var bodies = get_body_pool()
	var move_pool = get_data_pool(0)
	var input_pool = get_data_pool(1)
	
	# Raw sequential iteration loop over the raw array size
	for i in entities.size():
		var body = bodies[i] as Node2D
		var move_data = move_pool[i] as D_Movement
		var input_data = input_pool[i] as D_Input
		
		# 🗲 Direct vector variable translation math
		var current_input = input_data.movement_vector
		
		if current_input != Vector2.ZERO:
			move_data.velocity = move_data.velocity.move_toward(current_input * move_data.max_speed, move_data.acceleration * delta)
		else:
			move_data.velocity = move_data.velocity.move_toward(Vector2.ZERO, move_data.acceleration * delta)
			
		# Pure kinematic translation matching your OOP template exactly!
		body.global_position += move_data.velocity * delta
