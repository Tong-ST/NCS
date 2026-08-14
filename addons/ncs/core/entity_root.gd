class_name EntityConfig
extends NCSBase

## The primary design-time resource blueprint containing default entity configurations.
@export var base_config: NCSEntityDataSet 

## The decoupled, duplicate instance utilized safely at runtime by game loops.
var runtime_config: NCSEntityDataSet

## Cached pointer tracking down the companion folder tree hub without string lookup queries.
var _components_hub_cache: NCSComponentsHub


func _enter_tree() -> void:
	if base_config:
		runtime_config = base_config.duplicate(true) as NCSEntityDataSet

	NCS.register_entity(self)


func _exit_tree() -> void:
	NCS.unregister_entity(self)


# ==============================================================================
# DATA & COMPONENT GETTERS
# ==============================================================================

## Retrieves a data resource package out of the memory array slot via its class script.
## Example: var move_data = config.get_data(D_Movement) as D_Movement
func get_data(data_script: Script) -> NCSDataBase:
	if not runtime_config:
		push_warning("EntityConfig on '" + get_parent().name + "' has no base_config assigned!")
		return null

	if not data_script: 
		return null
	
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
		var class_str = data_script.get_global_name() if not data_script.get_global_name().is_empty() else "UnnamedScript"
		
		push_error("NCS Error: Entity '" + entity_name + "' is missing data block -> [" + class_str + "]. Check scene: [" + scene_path + "]")
		return null
		
	return data_block


## Locates an active component node organized inside the local tree hub folder via its class script.
## Example: var health = config.get_comp(C_Health) as C_Health
func get_comp(comp_script: Script) -> NCSComponentBase:
	if not comp_script: 
		return null
	
	var hub = _get_components_hub()
	if not hub: 
		return null
		
	for child in hub.get_children():
		if child.name.begins_with("__DELETED_"):
			continue
			
		if child.get_script() == comp_script:
			return child as NCSComponentBase

	var entity_name = get_parent().name
	var scene_path = get_parent().scene_file_path if get_parent().scene_file_path else "Runtime Spawned Entity"
	var class_str = comp_script.get_global_name() if not comp_script.get_global_name().is_empty() else "UnnamedScript"
	
	push_warning("NCS Warning: Entity '" + entity_name + "' requested missing component -> [" + class_str + "]. Check hub layout: [" + scene_path + "]")
	return null


# ==============================================================================
# RUNTIME COMPONENT MUTATIONS
# ==============================================================================

## Dynamically compiles and attaches a fresh component node onto the folder hub branch.
## Example: config.add_comp(C_Dead)
func add_comp(comp_script: Script) -> void:
	if Engine.is_editor_hint() or not comp_script: 
		return
	
	var hub = _get_components_hub()
	if not hub: 
		return
		
	for child in hub.get_children():
		if child.get_script() == comp_script:
			return
		
	var new_node = comp_script.new() as Node
	if not new_node: 
		return
	
	var class_str = comp_script.get_global_name()
	new_node.name = class_str if not class_str.is_empty() else "NCSComponent"

	hub.add_child(new_node)
	
	if new_node is NCSComponentBase:
		new_node.owner_node = hub.owner_node
		new_node.config = self
		if new_node.has_method("_init_comp"):
			new_node._init_comp()

	NCS.force_update_system_queries()


## Renames and discards an active component node, cleanly removing it from frame loop updates.
## Example: config.remove_comp(C_Movement)
func remove_comp(comp_script: Script) -> void:
	if not comp_script: 
		return
	
	var hub = _get_components_hub()
	if not hub: 
		return
	
	var target_comp: Node = null
	for child in hub.get_children():
		if child.name.begins_with("__DELETED_"):
			continue
		if child.get_script() == comp_script:
			target_comp = child
			break
				
	if target_comp:
		target_comp.name = "__DELETED_" + target_comp.name
		target_comp.queue_free()
		
		NCS.force_update_system_queries()


## Invokes a custom method block on a component script safely if it exists.
## Example: config.send_signal(C_Health, "take_damage", [20.0])
func send_signal(comp_script: Script, method_name: String, args: Array = []) -> bool:
	if Engine.is_editor_hint() or not comp_script: 
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
	
	var data_array = runtime_config.get("data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script() == data_script:
				return
				
	var new_data_instance = data_script.new() as NCSDataBase
	if new_data_instance:
		data_array.append(new_data_instance)
		NCS.force_update_system_queries()


## Completely detaches an existing data resource configuration package from active runtime storage tracking.
## Example: config.remove_data(D_PoisonStatus)
func remove_data(data_script: Script) -> void:
	if not runtime_config or not data_script: 
		return
	
	var data_array = runtime_config.get("data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script() == data_script:
				data_array.erase(res)
				NCS.force_update_system_queries()
				return


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
