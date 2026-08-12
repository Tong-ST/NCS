class_name C_Input
extends NCSComponentBase

# You can still write logic on component script, But keep logic that need to...
# interact with local node, e.g. Update UI, Emit VFX, Local specific, etc.
# For core logic that should share across all component write at CustomSystem instead.

func _process(_delta: float) -> void:
	var input_data = entity_config.get_data("D_Input") as D_Input
	if input_data:
		var raw_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		input_data.movement_vector = raw_dir

	var player: Player = owner_node
	if player:
		#print(player)
		pass

	# Example of access other component data
#	if entity_config:
#		var movement_data = entity_config.get_data("D_Movement") as D_Movement
#		print(movement_data.max_speed)
