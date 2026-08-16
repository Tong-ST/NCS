class_name C_Player
extends NCSComponentBase


func _process(_delta: float) -> void:
	# Only specific for player is Fine to just put on player scene.
	var raw_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_data = config.get_data(D_Input) as D_Input
	input_data.movement_vector = raw_dir
