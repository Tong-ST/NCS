class_name C_Health
extends NCSComponentBase

# You can still write logic on component script, But keep logic that need to...
# interact with local node, e.g. Update UI, Emit VFX, Local specific, etc.
# For core logic that should share across all component write at S_System instead.
signal on_damaged


# Example on create custom logic bind to this components
func take_damage(amount: float) -> void:
	# Example how to access data and manipulated via component itself.
	var health_data = config.get_data(D_Health) as D_Health
	if health_data:
		health_data.current_health -= amount
		on_damaged.emit()
