class_name EntityConfig
extends NCSBase

# Drag your e.g. 'player_data.tres' (NCSEntityDataSet Resource) here in the Inspector
@export var base_config: NCSEntityDataSet 
# The unique runtime instance of the data configuration
var runtime_config: NCSEntityDataSet
# Internal memory pointer to track down the sibling folder without string paths
var _components_hub_cache: NCSComponentsHub


func _enter_tree() -> void:
	if base_config:
		# Deep duplicate (true) ensures nested resources inside the array 
		# are uniquely duplicated for every single spawned creature instance.
		runtime_config = base_config.duplicate(true) as NCSEntityDataSet

	NCS.register_entity(self)

func _exit_tree() -> void:
	NCS.unregister_entity(self)


# ==============================================================================
# DATA AND COMP GETTERS
# ==============================================================================

## GETTER: Accepts a raw script type (e.g., D_Movement)
func get_data(data_script: Script) -> NCSDataBase:
	if not runtime_config:
		push_warning("EntityConfig on '" + get_parent().name + "' has no base_config assigned!")
		return null

	if not data_script: return null
	
	# Find our data using ultra-fast script pointer matching directly from the array
	var data_block: NCSDataBase = null
	var data_array = runtime_config.get("data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script() == data_script:
				data_block = res as NCSDataBase
				break
	
	if not is_instance_valid(data_block):
		var entity_name = get_parent().name
		var scene_path = get_parent().scene_file_path if get_parent().scene_file_path else "Runtime Spawned Entity"
		var class_str = data_script.get_global_name() if data_script.get_global_name() else "UnnamedScript"
		
		push_error("NCS Error: Entity '" + entity_name + "' is missing the data block class -> [" + class_str + "]. " +
			"Open the scene [" + scene_path + "] and add this asset to its EntityConfig resource data array.")
		return null
		
	return data_block


## GETTER: Safe dynamic lookup for specific component script classes
func get_comp(comp_script: Script) -> NCSComponentBase:
	if not comp_script: return null
	
	var hub = _get_components_hub()
	if not hub: return null
		
	# Loop through our active hub tree and match by direct memory script references
	for child in hub.get_children():
		if child.name.begins_with("__DELETED_"):
			continue
			
		if child.get_script() == comp_script:
			return child as NCSComponentBase

	var entity_name = get_parent().name
	var scene_path = get_parent().scene_file_path if get_parent().scene_file_path else "Runtime Spawned Entity"
	var class_str = comp_script.get_global_name() if comp_script.get_global_name() else "UnnamedScript"
	
	push_warning("NCS Warning: Entity '" + entity_name + "' requested a component script class -> [" + class_str + "], but it was not found in the Components hub. " +
		"Check your scene layout inside [" + scene_path + "].")

	return null


# ==============================================================================
# RUNTIME COMPONENT MUTATIONS
# ==============================================================================

## Adds a component via its Class Name safely (e.g. ent.add_comp(C_Dead))
func add_comp(comp_script: Script) -> void:
	if Engine.is_editor_hint() or not comp_script: return
	
	var hub = _get_components_hub()
	if not hub: return
		
	# Direct pointer check: instantly skip if the component script already exists
	for child in hub.get_children():
		if child.get_script() == comp_script:
			return
		
	# 🎯 HIGH-SPEED INSTANTIATION: 
	# Because we are passing the raw Script type directly into this function, 
	# we don't need to look up anything in a loop! We call .new() instantly.
	var new_node = comp_script.new() as Node
	if not new_node: return
	
	var class_str = comp_script.get_global_name()
	new_node.name = class_str if not class_str.is_empty() else "NCSComponent"

	hub.add_child(new_node)
	
	if new_node is NCSComponentBase:
		new_node.owner_node = hub.owner_node
		new_node.ent = self
		if new_node.has_method("_init_comp"):
			new_node._init_comp()

	NCS.force_update_system_queries()


## Remove a component node completely out of loops using its Class Name
func remove_comp(comp_script: Script) -> void:
	if not comp_script: return
	
	var hub = _get_components_hub()
	if not hub: return
	
	var target_comp: Node = null
	for child in hub.get_children():
		if child.name.begins_with("__DELETED_"):
			continue
		if child.get_script() == comp_script:
			target_comp = child
			break
				
	if target_comp:
		# Rename instantly to clear it from ongoing system queries right on this line!
		target_comp.name = "__DELETED_" + target_comp.name
		target_comp.queue_free()
		
		NCS.force_update_system_queries()


# ==============================================================================
# RUNTIME DATA MUTATIONS
# ==============================================================================
func add_data_by_name(data_class_name: String) -> void:
	if Engine.is_editor_hint() or not runtime_config: return
	
	# If the entity already has this specific data tracked, don't duplicate it
	if runtime_config.find_data_by_class(data_class_name) != null:
		return
		
	# 🎯 THE LOOP-KILLING LOOKUP:
	# Fetches the path string out of our optimized RAM dictionary instantly!
	var script_path = NCS.get_cached_script_path(data_class_name)
	if not script_path.is_empty():
		var loaded_script = load(script_path) as Script
		if loaded_script:
			var new_data_instance = loaded_script.new() as NCSDataBase
			if new_data_instance:
				var data_array = runtime_config.get("data_sets")
				if data_array is Array:
					data_array.append(new_data_instance)
					NCS.force_update_system_queries()

## Injects a dynamic Data Resource block (e.g. ent.add_data(D_Frozen))
func add_data(data_script: Script) -> void:
	if not runtime_config or not data_script: return
	
	# Direct loop pointer check to prevent duplicate resource tracks
	var data_array = runtime_config.get("data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script() == data_script:
				return
				
	# Allocate a clean, isolated memory segment from the script class template
	var new_data_instance = data_script.new() as NCSDataBase
	if new_data_instance:
		data_array.append(new_data_instance)
		print("NCS: Dynamically allocated data tracking class: ", data_script.get_global_name())
		
		# Force systems to remap their data index caches to absorb the new data layout block
		NCS.force_update_system_queries()


## Remove a dynamic data profile cleanly out of memory array lists
func remove_data(data_script: Script) -> void:
	if not runtime_config or not data_script: return
	
	var data_array = runtime_config.get("data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script() == data_script:
				data_array.erase(res)
				print("NCS: Safely detached data tracking class: ", data_script.get_global_name())
				
				# Force systems to remap their data arrays to drop the deleted data layout track
				NCS.force_update_system_queries()
				return


# ==============================================================================
# UTILITY CORE
# ==============================================================================

## Slices through siblings using strict class type matching to bypass path lookup errors
func _get_components_hub() -> NCSComponentsHub:
	if is_instance_valid(_components_hub_cache):
		return _components_hub_cache
		
	var parent_root = get_parent()
	if not parent_root: return null
		
	for child in parent_root.get_children():
		if child is NCSComponentsHub:
			_components_hub_cache = child
			return _components_hub_cache
			
	return null
