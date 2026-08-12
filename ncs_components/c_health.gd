class_name C_Health
extends NCSComponentBase

# You can still write logic on component script, But keep logic that need to...
# interact with local node, e.g. Update UI, Emit VFX, Local specific, etc.
# For core logic that should share across all component write at CustomSystem instead.

func take_damage() -> void:
	var body = owner_node as CharacterBody2D
	if not body: return

	var sprite = body.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

	# Example how to access data and manipulated via component itself.
	var health_data = entity_config.get_data("D_Health") as D_Health
	if health_data:
		health_data.current_health -= 20
		if health_data.current_health <= 0:
			health_data.current_health = 0

			entity_config.add_comp("C_Dead")
			# Simply add now comp to this ent. and it get filter out by other system
			# e.g. S_Movement, Or run logic on S_Dead for world dead system.

	var movement_data = entity_config.get_data("D_Movement") as D_Movement
	if movement_data:
		movement_data.max_speed -= 40
