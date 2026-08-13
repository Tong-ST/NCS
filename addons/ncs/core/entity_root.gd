@tool
class_name EntityConfig
extends NCSBase
# Drag your e.g. 'player_data.tres' (NCSEntityConfig Resource) here in the Inspector
@export var base_config: NCSEntityConfig 
# The unique runtime instance of the data configuration
var runtime_config: NCSEntityConfig
# Internal memory pointer to track down the sibling folder without string paths
var _components_hub_cache: NCSComponentsHub


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

	var data_block = runtime_config.find_data_by_class(data_class)
	
	if not is_instance_valid(data_block):
		var entity_name = get_parent().name
		var scene_path = get_parent().scene_file_path if get_parent().scene_file_path else "Runtime Spawned Entity"
		
		push_error("NCS Error: Entity '" + entity_name + "' is missing the data block -> [" + data_class + "]. " +
			"Open the scene [" + scene_path + "] and add [" + data_class + "] to its EntityConfig resource data array")
		return null
		
	return data_block

## GETTER: Safe dynamic lookup for specific component nodes
func get_comp(comp_identifier: String) -> Node:
	if Engine.is_editor_hint(): return null
	
	# Fetch our type-safe cached components folder hub
	var hub = _get_components_hub()
	if not hub: 
		return null
		
	# 1. High-Speed Route: Check if a node with that exact name exists in the folder tree
	if hub.has_node(comp_identifier):
		return hub.get_node(comp_identifier)
		
	# 2. Fallback Route: If renamed in the editor, search by its global class_name script definition
	for child in hub.get_children():
		# Skip nodes currently cleaning up in memory
		if child.name.begins_with("__DELETED_"):
			continue
			
		if child.get_script() and child.get_script().get_global_name() == comp_identifier:
			return child

	var entity_name = get_parent().name
	var scene_path = get_parent().scene_file_path if get_parent().scene_file_path else "Runtime Spawned Entity"
	
	push_warning("NCS Warning: Entity '" + entity_name + "' requested a component node named -> [" + comp_identifier + "], but it was not found in the Components hub " +
		"Check your scene layout inside [" + scene_path + "].")

	return null

## Adds a new component tag or juicy script node at runtime safely
func add_comp(comp_identifier: String, with_script: bool = true) -> void:
	if Engine.is_editor_hint(): return
	
	# Fetch via our safe type matching getter
	var hub = _get_components_hub()
	if not hub:
		push_error("NCS Error: Cannot add component '" + comp_identifier + "'. No NCSComponentsHub node class found on entity root '" + get_parent().name)
		return
		
	# Safe check: loop through children by script class or node name to prevent duplication duplicates
	for child in hub.get_children():
		if child.name == comp_identifier or (child.get_script() and child.get_script().get_global_name() == comp_identifier):
			return
		
	var new_node: Node = null
	
	# Check if this identifier is a registered script class_name (e.g. C_Dead)
	if with_script:
		for script_info in ProjectSettings.get_global_class_list():
			if script_info.class == comp_identifier:
				var loaded_script = load(script_info.path) as Script
				if loaded_script:
					new_node = loaded_script.new()
					break
				
	# If no script class matches, treat it as a pure text-based Tag Component node
	if not new_node:
		new_node = NCSComponentBase.new()
		new_node.name = comp_identifier

	# Add it to the hub folder branch natively
	hub.add_child(new_node)
	
	# If it's an NCS script, inject references and initialized
	if new_node is NCSComponentBase:
		new_node.owner_node = hub.owner_node
		new_node.ent = self
		if new_node.has_method("_init_comp"):
			new_node._init_comp()

	# Instantly notify all active world systems to refresh their query arrays
	NCS.force_update_system_queries()

## Removes a component tag or node safely without interrupting ongoing loop steps
func remove_comp(comp_identifier: String) -> void:
	if Engine.is_editor_hint(): return
	
	var hub = _get_components_hub()
	if not hub: return
	
	var target_comp: Node = null
	
	# Look through children using strict name matching and class verification loops
	for child in hub.get_children():
		# Skip nodes that are already marked for deletion
		if child.name.begins_with("__DELETED_"):
			continue
		if child.name == comp_identifier or (child.get_script() and child.get_script().get_global_name() == comp_identifier):
			target_comp = child
			break
				
	if target_comp:
		# Rename the node instantly so the query algorithm drops it immediately on this exact frame line
		target_comp.name = "__DELETED_" + target_comp.name
		target_comp.queue_free()
		
		# Force an immediate system cache recalculation pass
		NCS.force_update_system_queries()

## Dynamically allocates a new custom Data Resource block to this entity's unique storage pool
func add_data(data_class_name: String) -> void:
	if Engine.is_editor_hint(): return
	if not runtime_config: return
	
	# If the entity already has this specific data tracked, don't duplicate it
	if runtime_config.find_data_by_class(data_class_name) != null:
		return
		
	# Locate the target resource file script via the project settings registry
	for script_info in ProjectSettings.get_global_class_list():
		if script_info.class == data_class_name:
			var loaded_script = load(script_info.path) as Script
			if loaded_script:
				var new_data_instance = loaded_script.new() as NCSDataBase
				if new_data_instance:
					# Push the fresh resource memory segment directly into our active array
					runtime_config.data_sets.append(new_data_instance)
					print("NCS: Dynamically allocated data tracking: ", data_class_name)
					return

## Safely strips an active data track out of the entity's running resource list
func remove_data(data_class_name: String) -> void:
	if Engine.is_editor_hint(): return
	if not runtime_config: return
	
	var target_data = runtime_config.find_data_by_class(data_class_name)
	if target_data:
		runtime_config.data_sets.erase(target_data)
		print("NCS: Detached data tracking: ", data_class_name)

# Helper to get components_hub
func _get_components_hub() -> NCSComponentsHub:
	# If we already found it before, return it instantly
	if is_instance_valid(_components_hub_cache):
		return _components_hub_cache
		
	var parent_root = get_parent()
	if not parent_root:
		return null
		
	# Loop through all immediate siblings on the root entity tree
	for child in parent_root.get_children():
		if child is NCSComponentsHub:
			_components_hub_cache = child
			return _components_hub_cache
			
	return null
