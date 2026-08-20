## This is completely optional but recommend to separate scene-tree edit
## From pure data calculation in previous system, e.g. S_Input, S_Movement
##
## And this example try simulate of object off-screen they still change position
## But only update physics/visual position when on-screen.
class_name S_Visual
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Movement]).with_not([C_Dead]) # Filter entities with movement components
	iterate_data([D_Movement]) # Cache movement data
	fetch_nodes([Sprite2D]) # Optional cache Node into node_pools give null if not exist.


func ncs_process(entities: Array[Node], data_pools: Array, node_pools: Array, _delta: float) -> void:
	if entities.is_empty(): return
	var current_entities = entities as Array[Node]

	var move_pool = data_pools[0] as Array[D_Movement]
	if not move_pool: return

	var sprite_pool = node_pools[0] as Array[Sprite2D]
	if not sprite_pool: return
	
	var viewport = get_viewport()
	if not viewport: return

	# Calculate visible world viewport rectangle with a 64px padding buffer
	var canvas_transform = viewport.get_canvas_transform()
	var scale_factor = canvas_transform.get_scale()
	var screen_origin = -canvas_transform.origin / scale_factor
	var screen_size = viewport.get_visible_rect().size / scale_factor
	var screen_rect = Rect2(screen_origin, screen_size).grow(64.0)

	# Synchronize transforms and handle on-screen culling
	for i in current_entities.size():
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		var move_data = move_pool[i]
		if not move_data: continue

		var sprite = sprite_pool[i]

		# Skip until S_Movement has seeded the real spawn position on its first physics tick
		if not move_data.is_pos_initialized: continue

		var on_screen = screen_rect.has_point(move_data.next_global_pos)
		if on_screen:
			ent.global_position = move_data.next_global_pos
			if not move_data.is_on_screen:
				move_data.is_on_screen = true
				if sprite:
					sprite.visible = true
		else:
			if move_data.is_on_screen:
				move_data.is_on_screen = false
				if sprite:
					sprite.visible = false
