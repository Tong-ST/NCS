class_name C_Player
extends NCSComponentBase


# Original Godot _ready() run first at component enter scene-tree,
# But will NOT have owner_node, config references yet. 
func _ready() -> void:
	print("GAME START!")


# This will execute at start when entity enter to scene-tree,
# with owner_node and config references.
func _on_init_comp() -> void:
	print(owner_node.name, " Is ready!, use WASD/Arrow keys to move")
	var health_data = config.get_data(D_Health) as D_Health
	print("Current HP: ", health_data.current_health)


func get_player_input() -> void:
	# Only specific for player is Fine to just put on player scene.
	var raw_dir = Input.get_vector("left", "right", "up", "down")
	var input_data = config.get_data(D_Input) as D_Input
	input_data.movement_vector = raw_dir
