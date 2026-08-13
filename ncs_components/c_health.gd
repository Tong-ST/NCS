class_name C_Health
extends NCSComponentBase

# You can still write logic on component script, But keep logic that need to...
# interact with local node, e.g. Update UI, Emit VFX, Local specific, etc.
# For core logic that should share across all component write at S_System instead.
signal on_damaged

# Example on create custom logic bind to this components
func take_damage(amount: float) -> void:
	# Example how to access data and manipulated via component itself.
	var health_data = ent.get_data(D_Health) as D_Health
	if health_data:
		health_data.current_health -= amount
		on_damaged.emit()
		if health_data.current_health <= 0:
			health_data.current_health = 0

			ent.add_comp(C_Dead) # By add comp it auto attached script.
			# with class_name C_Dead.
			# And it simply add now comp to this ent. get filter by other system

	var movement_data = ent.get_data(D_Movement) as D_Movement
	if movement_data:
		movement_data.max_speed -= 40
