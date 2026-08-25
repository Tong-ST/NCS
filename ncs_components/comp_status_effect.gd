class_name CompStatusEffect
extends ComponentBase

# This Comp mainly focus on event-base StatusEffect watcher
# It may contain multiple StatusFX watcher e.g. poison, freeze, burn, etc.

var ent_name: String


func _on_init_comp() -> void:
	# NCS Observer pattern for event-based call.
	config.watch_data_lifecycle(
			DataPoisonStatus,
			_on_posion_added,
			_on_posion_removed,
	)
	# config.watch_data_added(), watch_data_removed() also available separately.

	ent_name = entity_node.get_script().get_global_name()


func _on_posion_added(_posion_data: NCSDataBase) -> void:
	print(ent_name, " Get poison!")


func _on_posion_removed(_posion_data: NCSDataBase) -> void:
	await get_tree().create_timer(1).timeout # Just timer delay print to keep it stacking cleanly.
	print("Poison was removed from ", ent_name)
