class_name CompPlayer
extends NCSComponentBase


# Original Godot _ready() run first at component enter scene-tree,
# But will NOT have entity, config references yet.
func _ready() -> void:
	print("GAME START!")


# This will execute at start when entity enter to scene-tree,
# with entity and config references.
func _on_init_comp() -> void:
	print(entity.name, " Is ready!, use WASD/Arrow keys to move")
	if config.has_data(DataHealth):
		var health_data = config.get_data(DataHealth) as DataHealth
		print("Current HP: ", health_data.current_health)

	if config.has_comp(CompMovement):
		var movement_comp = config.get_comp(CompMovement) as CompMovement
		print("Movement Component: ", movement_comp.name)


func get_player_input() -> void:
	# Only specific for player is Fine to just put on player scene.
	var raw_dir = Input.get_vector("left", "right", "up", "down")
	var input_data = config.get_data(DataInput) as DataInput
	input_data.movement_vector = raw_dir
