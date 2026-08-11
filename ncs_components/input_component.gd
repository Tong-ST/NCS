class_name InputComponent
extends NCSComponentBase

# You can still write logic on component script, But keep logic that need to...
# interact with local node, e.g. Update UI, Emit VFX, Local specific, etc.
# For core logic that should share across all component write at CustomSystem instead.

func _process(_delta: float) -> void:
	var input_data: InputData = data

	if input_data:
		var raw_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		input_data.movement_vector = raw_dir

	# Example of access other component data
#	if config_node:
#		var movement_data = config_node.get_data("MovementData") as MovementData
#		print(movement_data.max_speed)
