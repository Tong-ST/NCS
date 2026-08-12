@tool
class_name EntityConfig
extends NCSBase

# Drag your 'wolf_base.tres' (NCSEntityConfig Resource) here in the Inspector
@export var base_config: NCSEntityConfig 

# The unique runtime instance of the data configuration
var runtime_config: NCSEntityConfig


func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	if base_config:
		# Deep duplicate (true) ensures nested resources inside the array 
		# are uniquely duplicated for every single spawned creature instance.
		runtime_config = base_config.duplicate(true) as NCSEntityConfig

	NCS.register_entity(self)


func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	NCS.unregister_entity(self)

## A safe getter function used by child components or entity scripts to grab raw data
func get_data(data_class: String) -> NCSDataBase:
	if not runtime_config:
		push_warning("EntityConfig on '" + get_parent().name + "' has no base_config assigned!")
		return null
	return runtime_config.find_data_by_class(data_class)
