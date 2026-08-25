class_name CompPlayer
extends ComponentBase

var input_data: DataInput
var health_data: DataHealth

var movement_comp: CompMovement


# Original Godot _ready() run first at component enter scene-tree,
# But will NOT have entity, config references yet.
func _ready() -> void:
	print("GAME START!")


func _exit_tree() -> void:
	# This just for demostrate remove comp when Player despawn.
	if config.has_comp(CompPlayer):
		config.remove_comp(CompPlayer)


# This will execute at start when entity enter to scene-tree,
# with entity and config references.
func _on_init_comp() -> void:
	input_data = config.get_data(DataInput)
	print(entity_node.name, " Is ready!, use WASD/Arrow keys to move")

	health_data = config.get_data(DataHealth)
	if config.has_data(DataHealth):
		print("Current HP: ", health_data.current_health)

	movement_comp = config.get_comp(CompMovement)
	if config.has_comp(CompMovement):
		print("Movement Component: ", movement_comp.name)


# This will run once this component was added to entity at runtime
# via config.add_comp() work from both SysSystem or Comp.
func _on_add_comp() -> void:
	pass


# This will run once this component was removed from entity at runtime
# via config.remove() work from both SysSystem or Comp.
func _on_remove_comp() -> void:
	print(self.get_script().get_global_name(), ' was removed from ', entity_node.name)


## Use for track player input, Specific for player.
func get_player_input() -> void:
	var raw_dir = Input.get_vector("left", "right", "up", "down")
	input_data.movement_vector = raw_dir
