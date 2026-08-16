class_name S_Visual
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Movement]).with_not([C_Dead]) # Filter entities with movement components
	iterate_data([D_Movement]) # Cache movement data


func ncs_process(entities: Array[Node], data_pools: Array, _delta: float) -> void:
	var move_pool = data_pools[0]
	
	var viewport = get_viewport()
	if not viewport:
		return

	# Calculate visible world viewport rectangle with a 64px padding buffer
	var canvas_transform = viewport.get_canvas_transform()
	var scale_factor = canvas_transform.get_scale()
	var screen_origin = -canvas_transform.origin / scale_factor
	var screen_size = viewport.get_visible_rect().size / scale_factor
	var screen_rect = Rect2(screen_origin, screen_size).grow(64.0)

	# Synchronize transforms and handle on-screen culling
	for i in entities.size():
		var ent = entities[i] as CharacterBody2D
		var move_data = move_pool[i] as D_Movement

		if not is_instance_valid(ent) or not move_data:
			continue

		# Skip until S_Movement has seeded the real spawn position on its first physics tick
		if not move_data.is_pos_initialized:
			continue

		var on_screen = screen_rect.has_point(move_data.next_global_pos)
		if on_screen:
			ent.global_position = move_data.next_global_pos
			if not move_data.is_on_screen:
				move_data.is_on_screen = true
				ent.show()
		else:
			if move_data.is_on_screen:
				move_data.is_on_screen = false
				ent.hide()
