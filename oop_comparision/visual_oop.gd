class_name VisualOOP
extends Node

@export var actor: EnemyOOP


func _process(_delta: float) -> void:
	if not is_instance_valid(actor):
		return
	
	var viewport = actor.get_viewport()
	if not viewport:
		return

	# Calculate camera visible world rect with a 64px padding buffer
	var canvas_transform = viewport.get_canvas_transform()
	var scale_factor = canvas_transform.get_scale()
	var screen_origin = -canvas_transform.origin / scale_factor
	var screen_size = viewport.get_visible_rect().size / scale_factor
	var screen_rect = Rect2(screen_origin, screen_size).grow(64.0)

	# Skip until MovementOOP has seeded the real spawn position on its first physics tick
	if not actor.is_pos_initialized:
		return

	var on_screen = screen_rect.has_point(actor.next_global_pos)
	if on_screen:
		actor.global_position = actor.next_global_pos
		if not actor.is_on_screen:
			actor.is_on_screen = true
			actor.show()
	else:
		if actor.is_on_screen:
			actor.is_on_screen = false
			actor.hide()
