## Core entity node. Add one as a child of every NCS entity root (CharacterBody2D etc.).
## Owns the per-entity runtime data resource and component/data lookup maps.
class_name EntityConfig
extends NCSBase

## Design-time blueprint resource. Set in the inspector. Never mutate at runtime.
@export var base_config: NCSEntityDataSet

## Per-entity isolated data copy created from base_config at spawn. Systems read/write here.
var runtime_config: NCSEntityDataSet

var _components_hub_cache: NCSComponentsHub
var _data_map: Dictionary = {}
var _component_map: Dictionary = {}
var _active_component_scripts: Array[Script] = []

# data watcher for changed, add, remove at runtime.
var _data_watchers: Dictionary = {}
var _data_added_watchers: Dictionary = {}
var _data_removed_watchers: Dictionary = {}


func _enter_tree() -> void:
	if base_config and not runtime_config:
		if base_config.has_method(&"duplicate_runtime"):
			runtime_config = base_config.duplicate_runtime()
		else:
			runtime_config = base_config.duplicate(true) as NCSEntityDataSet

	_rebuild_data_cache()
	_rebuild_component_cache()

	NCS.register_entity(self)


func _exit_tree() -> void:
	NCS.unregister_entity(self)


# ==============================================================================
# CACHE REBUILDS
# ==============================================================================

## Rebuilds _data_map from runtime_config.data_sets. Called after spawn/reset/data mutations.
func _rebuild_data_cache() -> void:
	_data_map.clear()

	if not runtime_config:
		return

	var data_array = runtime_config.get(&"data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script():
				_data_map[res.get_script()] = res


## Rebuilds _component_map by scanning the entity tree.
func _rebuild_component_cache() -> void:
	_component_map.clear()
	_active_component_scripts.clear()

	var parent_body = get_parent()
	if not parent_body:
		return

	for child in parent_body.get_children():
		if child.name.begins_with(&"__DELETED_"):
			continue

		var script = child.get_script()
		if script:
			_component_map[script] = child as NCSComponentBase
			_active_component_scripts.append(script)

		if child is NCSComponentsHub or child.name == "NCSComponentsHub":
			_components_hub_cache = child as NCSComponentsHub
			for sub_child in child.get_children():
				if sub_child.name.begins_with(&"__DELETED_"):
					continue

				var sub_script = sub_child.get_script()
				if sub_script:
					_component_map[sub_script] = sub_child as NCSComponentBase
					if not _active_component_scripts.has(sub_script):
						_active_component_scripts.append(sub_script)


# ==============================================================================
# GETTERS & DATA MUTATIONS
# ==============================================================================

## Returns the runtime data resource of the given type. Logs push_error if missing.
## Usage: var move = config.get_data(DataMovement) as DataMovement
func get_data(data_script: Script) -> NCSDataBase:
	if not data_script:
		return null

	var data_block = _data_map.get(data_script, null) as NCSDataBase
	if not is_instance_valid(data_block):
		if not runtime_config:
			push_warning(
					"EntityConfig on '" + get_parent().name
					+ "' has no base_config assigned!"
			)
			return null

		_rebuild_data_cache()
		data_block = _data_map.get(data_script, null) as NCSDataBase

	if not is_instance_valid(data_block):
		var entity_name = get_parent().name
		var scene_path = (
				get_parent().scene_file_path
				if get_parent().scene_file_path
				else "Runtime Spawned Entity"
		)
		var class_str = (
				data_script.get_global_name()
				if not data_script.get_global_name().is_empty()
				else "UnnamedScript"
		)
		push_error(
				"NCS Error: Entity '" + entity_name + "
				' is missing data block -> [" + class_str + "]. 
				Check scene: [" + scene_path + "]"
		)
		return null

	return data_block


## Send signal when specific data has changed.
func watch_data(data_script: Script, property_name: StringName, callback: Callable) -> void:
	if not _data_watchers.has(data_script):
		_data_watchers[data_script] = {}
	if not _data_watchers[data_script].has(property_name):
		_data_watchers[data_script][property_name] = []

	_data_watchers[data_script][property_name].append(callback)


## Safely updates a field on an existing data resource in one line. Returns true if successful.
## Usage: config.change_data(DataMovement, &"max_speed", 300.0)
func change_data(data_script: Script, property_name: StringName, new_value: Variant) -> bool:
	var data_block = get_data(data_script)
	if not is_instance_valid(data_block) or not (property_name in data_block):
		return false

	if data_block.get(property_name) == new_value:
		return true

	data_block.set(property_name, new_value)

	# Route change only to components watching this specific property
	if _data_watchers.has(data_script) and _data_watchers[data_script].has(property_name):
		for callback in _data_watchers[data_script][property_name]:
			if callback.is_valid():
				callback.call(new_value)

	return true


## Returns the component node of the given type. Logs push_warning if missing.
## Usage: var hp = config.get_comp(CompHealth) as CompHealth
func get_comp(comp_script: Script) -> NCSComponentBase:
	if not comp_script:
		return null

	var comp = _component_map.get(comp_script, null) as NCSComponentBase
	if not is_instance_valid(comp):
		_rebuild_component_cache()
		comp = _component_map.get(comp_script, null) as NCSComponentBase

	if not is_instance_valid(comp):
		var entity_name = get_parent().name
		var scene_path = (
				get_parent().scene_file_path 
				if get_parent().scene_file_path 
				else "Runtime Spawned Entity"
		)
		var class_str = (
				comp_script.get_global_name()
				if not comp_script.get_global_name().is_empty()
				else "UnnamedScript"
		)
		push_warning(
				"NCS Warning: Entity '" + entity_name
				+ "' requested missing component -> [" + class_str + "].
				Check hub layout: [" + scene_path + "]"
		)
		return null

	return comp


## Returns true if this entity currently has the given data type in entity config.
## Usage: if config.has_data(DataMovement): ...
func has_data(data_script: Script) -> bool:
	if not data_script:
		return false

	return _data_map.has(data_script)


## Returns true if this entity currently has the given component type active.
## Usage: if config.has_comp(CompDead): ...
func has_comp(comp_script: Script) -> bool:
	if not comp_script:
		return false
	return _component_map.has(comp_script)


## Returns an array of component Scripts currently attached to this entity.
func get_component_scripts() -> Array[Script]:
	var scripts: Array[Script] = []
	for script in _component_map.keys():
		scripts.append(script as Script)
	return scripts


func get_data_scripts() -> Array[Script]:
	var scripts: Array[Script] = []
	for script in _data_map.keys():
		if script is Script:
			scripts.append(script)
	return scripts

# ==============================================================================
# RUNTIME MUTATIONS
# ==============================================================================

## Adds a new component at runtime. No-op if already present. Triggers deferred NCS re-query.
## Usage: config.add_comp(CompDead)
func add_comp(comp_script: Script) -> void:
	if not comp_script or _component_map.has(comp_script):
		return

	var hub = _get_components_hub()
	if not hub:
		return

	var new_node = comp_script.new() as Node
	if not new_node:
		return

	var class_str = comp_script.get_global_name()
	new_node.name = class_str if not class_str.is_empty() else "CompNew"
	hub.add_child(new_node)
	if new_node is NCSComponentBase:
		new_node.owner_node = hub.owner_node
		new_node.config = self

	_component_map[comp_script] = new_node as NCSComponentBase
	if not _active_component_scripts.has(comp_script):
		_active_component_scripts.append(comp_script)

	if new_node.has_method(&"_on_add_comp"):
		new_node._on_add_comp()

	NCS.mark_dirty(self, comp_script)


## Removes a component at runtime and triggers deferred NCS re-query.
## Usage: config.remove_comp(CompMovement)
func remove_comp(comp_script: Script) -> void:
	if not comp_script:
		return

	var target_comp = _component_map.get(comp_script, null) as Node
	if target_comp:
		if target_comp.has_method(&"_on_remove_comp"):
			target_comp._on_remove_comp()

		_component_map.erase(comp_script)
		_active_component_scripts.erase(comp_script)
		target_comp.name = "__DELETED_" + target_comp.name
		target_comp.queue_free()
		NCS.mark_dirty(self, comp_script)


## Calls a method on a component node. Returns true if the call succeeded.
## Usage: config.call_method(CompHealth, &"take_damage", [20.0])
func call_method(comp_script: Script, method_name: StringName, args: Array = []) -> bool:
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
# DATA LIFECYCLE WATCHERS
# ==============================================================================

## Call when a specific data script is added to this entity.
func watch_data_added(data_script: Script, callback: Callable) -> void:
	if not _data_added_watchers.has(data_script):
		_data_added_watchers[data_script] = []
	_data_added_watchers[data_script].append(callback)


## Call when a specific data script is removed from this entity.
func watch_data_removed(data_script: Script, callback: Callable) -> void:
	if not _data_removed_watchers.has(data_script):
		_data_removed_watchers[data_script] = []
	_data_removed_watchers[data_script].append(callback)


## Convenience method to watch both addition and removal in one line.
func watch_data_lifecycle(data_script: Script, on_added: Callable, on_removed: Callable) -> void:
	if on_added.is_valid():
		watch_data_added(data_script, on_added)
	if on_removed.is_valid():
		watch_data_removed(data_script, on_removed)


## Adds a new data resource at runtime. No-op if already present. Triggers deferred NCS re-query.
## Usage: config.add_data(DataPoisonStatus)
func add_data(data_script: Script) -> void:
	if not runtime_config or not data_script or _data_map.has(data_script):
		return

	var new_data_instance = data_script.new() as NCSDataBase
	if new_data_instance:
		var data_array = runtime_config.get(&"data_sets")
		if data_array is Array:
			data_array.append(new_data_instance)
		_data_map[data_script] = new_data_instance

		if _data_added_watchers.has(data_script):
			for callback in _data_added_watchers[data_script]:
				if callback.is_valid():
					callback.call(new_data_instance)

		NCS.mark_dirty(self, data_script)


## Removes a data resource at runtime. Triggers deferred NCS re-query.
## Usage: config.remove_data(DataPoisonStatus)
func remove_data(data_script: Script) -> void:
	if not runtime_config or not data_script:
		return

	var res = _data_map.get(data_script, null)
	if res:
		_data_map.erase(data_script)
		var data_array = runtime_config.get(&"data_sets")
		if data_array is Array:
			data_array.erase(res)

		if _data_removed_watchers.has(data_script):
			for callback in _data_removed_watchers[data_script]:
				if callback.is_valid():
					callback.call(res)

		NCS.mark_dirty(self, data_script)


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

## Returns the NCSComponentsHub node. Uses cached ref; falls back to tree scan on miss.
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
