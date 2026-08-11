class_name NCSComponentBase
extends NCSBase

var data: NCSDataBase
var config_node: EntityConfig
var owner_node: Node

## Called automatically by the NCSComponentsHub parent node
func initialize_component() -> void:
	# 1. Derive targets smoothly based on the component's name
	var script_class_name = get_script().get_global_name()
	var base_identity = ""

	if not script_class_name.is_empty() and script_class_name != "NCSComponentBase":
		base_identity = script_class_name.replace("Component", "")
	else:
		base_identity = name.replace("Component", "")

	var required_data_class = base_identity + "Data"
	var target_system_name = base_identity + "System"

	# 2. Extract the data block from the pre-found config node
	if config_node:
		data = config_node.get_data(required_data_class)
		
	# 3. Register to the running NCSWorld system layout
	var target_system = NCS.get_system_by_name(target_system_name)
	if target_system and target_system.has_method("register_component"):
		target_system.register_component(self)
