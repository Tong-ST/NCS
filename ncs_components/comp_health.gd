class_name CompHealth
extends NCSComponentBase

# You can still write logic on component script, But keep logic that need to...
# interact with local node, e.g. Update UI, Emit VFX, Local specific, etc.
# For core logic that should share across all component write at SysSystem instead.
signal on_damaged

var health_data: DataHealth


func _on_init_comp() -> void:
	health_data = config.get_data(DataHealth)
	# NCS Observer pattern for event-based call.
	config.watch_data(DataHealth, &"state", _on_state_changed)
	config.watch_data_lifecycle(
			DataPoisonStatus,
			_on_posion_applied,
			_on_posion_removed,
	)


# Example on create custom logic bind to this components
func take_damage(amount: float) -> void:
	if not health_data:
		health_data = config.get_data(DataHealth)
	
	# This just for example, Recommend comp method to be Read-only to avoid conflict.
	# Write to data as below should be in system.
	if health_data:
		health_data.current_health -= amount
		on_damaged.emit()


# This will run once this component was remove from entity.
func _on_remove_comp() -> void:
	print('Health component was removed from ', entity.name)


func _on_state_changed(state: Variant) -> void:
	if state == "DEAD":
		# Safely despawn entity at the end of frame use NCS.despawn(target_node)
		NCS.despawn(entity)


func _on_posion_applied(_posion_data: NCSDataBase) -> void:
	print(entity.name, " Get poison!")


func _on_posion_removed(_posion_data: NCSDataBase) -> void:
	print("Poison was removed from ", entity.name)
