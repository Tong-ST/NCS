class_name EntityConfig
extends NCSBase

## The primary design-time resource blueprint containing default entity configurations.
@export var base_config: NCSEntityDataSet 

## The decoupled, duplicate instance utilized safely at runtime by game loops.
var runtime_config: NCSEntityDataSet

## Cached pointer tracking down the companion folder tree hub without string lookup queries.
var _components_hub_cache: NCSComponentsHub

## O(1) High-speed lookup cache maps for runtime performance
var _data_map: Dictionary = {} # Key: Script -> NCSDataBase
var _component_map: Dictionary = {} # Key: Script -> NCSComponentBase
var _active_component_scripts: Array[Script] = []


func _enter_tree() -> void:
	if base_config:
		runtime_config = base_config.duplicate(true) as NCSEntityDataSet

	_rebuild_data_cache()
	_rebuild_component_cache()

	NCS.register_entity(self)


func _exit_tree() -> void:
	NCS.unregister_entity(self)


## Rebuilds the O(1) data lookup cache map
func _rebuild_data_cache() -> void:
	_data_map.clear()
	if not runtime_config:
		return
	var data_array = runtime_config.get("data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script():
				_data_map[res.get_script()] = res


## Rebuilds the O(1) component lookup cache map and script list
func _rebuild_component_cache() -> void:
	_component_map.clear()
	_active_component_scripts.clear()
	
	var parent_body = get_parent()
	if not parent_body:
		return

	# Scan direct children of parent body first
	for child in parent_body.get_children():
		if child.name.begins_with("__DELETED_"):
			continue
		var script = child.get_script()
		if script:
			_component_map[script] = child as NCSComponentBase
			_active_component_scripts.append(script)
			
		if child is NCSComponentsHub or child.name == "NCSComponentsHub":
			_components_hub_cache = child as NCSComponentsHub
			for sub_child in child.get_children():
				if sub_child.name.begins_with("__DELETED_"):
					continue
				var sub_script = sub_child.get_script()
				if sub_script:
					_component_map[sub_script] = sub_child as NCSComponentBase
					if not _active_component_scripts.has(sub_script):
						_active_component_scripts.append(sub_script)


# ==============================================================================
# DATA & COMPONENT GETTERS
# ==============================================================================

## Retrieves a data resource package out of memory via its class script in O(1) time.
## Example: var move_data = config.get_data(D_Movement) as D_Movement
func get_data(data_script: Script) -> NCSDataBase:
	if not data_script: 
		return null

	var data_block = _data_map.get(data_script, null) as NCSDataBase
	if not is_instance_valid(data_block):
		if not runtime_config:
			push_warning("EntityConfig on '" + get_parent().name + "' has no base_config assigned!")
			return null
		_rebuild_data_cache()
		data_block = _data_map.get(data_script, null) as NCSDataBase

	if not is_instance_valid(data_block):
		var entity_name = get_parent().name
		var scene_path = get_parent().scene_file_path if get_parent().scene_file_path else "Runtime Spawned Entity"
		var class_str = data_script.get_global_name() if not data_script.get_global_name().is_empty() else "UnnamedScript"
		
		push_error("NCS Error: Entity '" + entity_name + "' is missing data block -> [" + class_str + "]. Check scene: [" + scene_path + "]")
		return null
		
	return data_block


## Locates an active component node in O(1) time via its class script.
## Example: var health = config.get_comp(C_Health) as C_Health
func get_comp(comp_script: Script) -> NCSComponentBase:
	if not comp_script: 
		return null
	
	var comp = _component_map.get(comp_script, null) as NCSComponentBase
	if not is_instance_valid(comp):
		_rebuild_component_cache()
		comp = _component_map.get(comp_script, null) as NCSComponentBase

	if not is_instance_valid(comp):
		var entity_name = get_parent().name
		var scene_path = get_parent().scene_file_path if get_parent().scene_file_path else "Runtime Spawned Entity"
		var class_str = comp_script.get_global_name() if not comp_script.get_global_name().is_empty() else "UnnamedScript"
		
		push_warning("NCS Warning: Entity '" + entity_name + "' requested missing component -> [" + class_str + "]. Check hub layout: [" + scene_path + "]")
		return null
		
	return comp


## Fast O(1) check if this entity has a specific component script
func has_comp(comp_script: Script) -> bool:
	if not comp_script:
		return false
	return _component_map.has(comp_script)


# ==============================================================================
# RUNTIME COMPONENT MUTATIONS
# ==============================================================================

## Dynamically compiles and attaches a fresh component node onto the folder hub branch.
## Example: config.add_comp(C_Dead)
func add_comp(comp_script: Script) -> void:
	if Engine.is_editor_hint() or not comp_script: 
		return
	
	if _component_map.has(comp_script):
		return
		
	var hub = _get_components_hub()
	if not hub: 
		return
		
	var new_node = comp_script.new() as Node
	if not new_node: 
		return
	
	var class_str = comp_script.get_global_name()
	new_node.name = class_str if not class_str.is_empty() else "C_Newcomp"

	hub.add_child(new_node)
	
	if new_node is NCSComponentBase:
		new_node.owner_node = hub.owner_node
		new_node.config = self
		if new_node.has_method("_init_comp"):
			new_node._init_comp()

	_component_map[comp_script] = new_node as NCSComponentBase
	if not _active_component_scripts.has(comp_script):
		_active_component_scripts.append(comp_script)

	NCS.update_single_entity(self)


## Renames and discards an active component node, cleanly removing it from frame loop updates.
## Example: config.remove_comp(C_Movement)
func remove_comp(comp_script: Script) -> void:
	if not comp_script: 
		return
	
	var target_comp = _component_map.get(comp_script, null) as Node
	if target_comp:
		_component_map.erase(comp_script)
		_active_component_scripts.erase(comp_script)
		target_comp.name = "__DELETED_" + target_comp.name
		target_comp.queue_free()
		
		NCS.update_single_entity(self)


## Invokes a custom method block on a component script safely if it exists.
## Example: config.send_signal(C_Health, "take_damage", [20.0])
func send_signal(comp_script: Script, method_name: String, args: Array = []) -> bool:
	if not comp_script: 
		return false
	
	var comp = get_comp(comp_script)
	if not is_instance_valid(comp):
		return false
		
	if comp.has_method(method_name):
		comp.callv(method_name, args)
		return true
		
	return false


# ==============================================================================
# RUNTIME DATA MUTATIONS
# ==============================================================================

## Dynamically instantiates a fresh custom Data Resource container and slots it into runtime storage.
## Example: config.add_data(D_PoisonStatus)
func add_data(data_script: Script) -> void:
	if not runtime_config or not data_script: 
		return
	
	if _data_map.has(data_script):
		return
				
	var new_data_instance = data_script.new() as NCSDataBase
	if new_data_instance:
		var data_array = runtime_config.get("data_sets")
		if data_array is Array:
			data_array.append(new_data_instance)
		_data_map[data_script] = new_data_instance
		NCS.update_single_entity(self)


## Completely detaches an existing data resource configuration package from active runtime storage tracking.
## Example: config.remove_data(D_PoisonStatus)
func remove_data(data_script: Script) -> void:
	if not runtime_config or not data_script: 
		return
	
	var res = _data_map.get(data_script, null)
	if res:
		_data_map.erase(data_script)
		var data_array = runtime_config.get("data_sets")
		if data_array is Array:
			data_array.erase(res)
		NCS.update_single_entity(self)


# ==============================================================================
# INTERNAL HELPER PIPELINES
# ==============================================================================

## Scans the parent node tree via strict type checking to retrieve the organized components folder hub.
func _get_components_hub() -> NCSComponentsHub:
	if is_instance_valid(_components_hub_cache):
		return _components_hub_cache
		
	var parent_root = get_parent()
	if not parent_root: 
		return null
		
	for child in parent_root.get_children():
		if child is NCSComponentsHub:
			_components_hub_cache = child
			return _components_hub_cache
			
	return null
