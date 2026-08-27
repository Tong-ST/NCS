class_name CompHealth
extends ComponentBase

# You can still write logic on component script, But keep logic that need to...
# interact with local node, e.g. Update UI, Emit VFX, Local specific, etc.
# For core logic that should share across all component write at SysSystem instead.
signal on_damaged

var health_data: DataHealth
var ent_name: String


func _on_init_comp() -> void:
	health_data = config.get_data(DataHealth)
	# NCS Observer pattern for event-based call.
	config.watch_data(DataHealth, &"state", _on_state_changed)
	config.watch_data(DataHealth, &"current_health", _on_health_changed)

	ent_name = entity_node.get_script().get_global_name()


# Example on create custom logic bind to this components
func take_damage(amount: float) -> void:
	if not health_data:
		health_data = config.get_data(DataHealth)
	
	# This below just for example, Recommend comp method to be Read-only to avoid conflict.
	# Write-data should consider to be in system, But it's flexible and Up-to-you.

	# Use change data will also send signal to watch_data().
	var new_health = health_data.current_health - amount
	config.change_data(DataHealth, &"current_health", new_health)
	# Use change_data() will heavy than doing just heath_data.current_health = new_health
	# Recommend to use on event-base property and avoid every-frame use.

	# send godot native signal.
	on_damaged.emit()


func _on_state_changed(state: String) -> void:
	if state == "DEAD":
		# Safely despawn entity at the end of current_frame via command-buffer.
		NCS.despawn(config) # NCS.depawn(target_node) also work if call somewhere else e.g. on Player

		# Native queue_free() work fine, it will trigger immediately
		# Instead of use end of current_frame.
		#entity_node.queue_free() 


# In real usecase this watcher pattern can be useful for e.g. UpdateUI
# It might be live in CompUI and use to signal on related data changes, It up-to-you.
func _on_health_changed(current_health: int) -> void:
	print(ent_name, " HP: ", int(health_data.max_health), "/", current_health)
