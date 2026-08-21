class_name C_Health
extends NCSComponentBase

# You can still write logic on component script, But keep logic that need to...
# interact with local node, e.g. Update UI, Emit VFX, Local specific, etc.
# For core logic that should share across all component write at S_System instead.
signal on_damaged


func _on_init_comp() -> void:
	# NCS Observer pattern for signal base event.
	config.watch_data(D_Health, &"status", _on_status_changed)
	config.watch_data_lifecycle(
		D_PoisonStatus,
		_on_posion_applied,
		_on_posion_removed,
	)


# Example on create custom logic bind to this components
func take_damage(amount: float) -> void:
	# Example how to access data and manipulated via component itself.
	if not config.has_data(D_Health): return
	var health_data = config.get_data(D_Health) as D_Health
	if health_data:
		health_data.current_health -= amount
		on_damaged.emit()


# This will run once this component was remove from entity.
func _on_remove_comp() -> void:
	print('Health component was removed from ', owner_node.name)


func _on_status_changed(status: Variant) -> void:
	if status == "DEAD":
		# Do something, Play anim, etc. than queue_free parent.
		owner_node.queue_free()


func _on_posion_applied(_posion_data: NCSDataBase) -> void:
	print(owner_node.name, " Get poison!")


func _on_posion_removed(_posion_data: NCSDataBase) -> void:
	print("Poison was removed from ", owner_node.name)
