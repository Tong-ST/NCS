## Core entity node. Add one as a child of every NCS entity root (CharacterBody2D etc.).
## Owns the per-entity runtime data resource and component/data lookup maps.
# Scene layout:
#   EntityRoot
#     |-- NCSEntityConfig   <- this node
#     |-- NCSComponentsHub
#          |-- C_Movement
#          |-- C_Health
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

## False when entity is pooled/disabled. Systems skip entities where is_active = false.
var is_active: bool = true

## Scene this entity was spawned from. Set by NCSEntityPool for correct pool return.
var pooled_scene_key: PackedScene = null

var _initial_component_scripts: Array[Script] = []
var _baseline_component_nodes: Dictionary = {}
var _has_snapshot: bool = false


func _enter_tree() -> void:
	if base_config and not runtime_config:
		if base_config.has_method(&"duplicate_runtime"):
			runtime_config = base_config.duplicate_runtime()
		else:
			runtime_config = base_config.duplicate(true) as NCSEntityDataSet

	_rebuild_data_cache()
	_rebuild_component_cache()

	if is_active:
		NCS.register_entity(self)


func _exit_tree() -> void:
	if is_active:
		NCS.unregister_entity(self)


## Resets entity to design-time state. Called automatically by NCSEntityPool on recycle.
## Duplicates fresh runtime_config, removes runtime-added components, re-inits baseline ones.
func reset_entity() -> void:
	is_active = true
	if base_config:
		if base_config.has_method(&"duplicate_runtime"):
			runtime_config = base_config.duplicate_runtime()
		else:
			runtime_config = base_config.duplicate(true) as NCSEntityDataSet

	_rebuild_data_cache()

	if _has_snapshot:
		var current_scripts = _component_map.keys()
		for comp_script in current_scripts:
			if not _initial_component_scripts.has(comp_script):
				remove_comp(comp_script)

		for initial_script in _initial_component_scripts:
			var baseline_node = _baseline_component_nodes.get(initial_script, null) as Node
			if is_instance_valid(baseline_node):
				baseline_node.process_mode = PROCESS_MODE_INHERIT
				if baseline_node is CanvasItem or baseline_node is Node3D:
					baseline_node.show()
				if baseline_node is NCSComponentBase and baseline_node.has_method("_init_comp"):
					baseline_node._init_comp()
				_component_map[initial_script] = baseline_node as NCSComponentBase
				if not _active_component_scripts.has(initial_script):
					_active_component_scripts.append(initial_script)
			else:
				add_comp(initial_script)

	_rebuild_component_cache()
	NCS.update_single_entity(self)


## Alias for reset_entity(). Kept for backwards compatibility.
func reset_data() -> void:
	reset_entity()


## Removes entity from active play. Returns to pool if spawned via NCSEntityPool, else queue_free.
func despawn() -> void:
	is_active = false
	NCS.unregister_entity(self)

	var pool = get_tree().root.get_node_or_null("NCSEntityPool") if get_tree() else null
	if pool and pool.has_method(&"despawn"):
		pool.despawn(get_parent())
		return

	if get_parent():
		get_parent().queue_free()


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


## Rebuilds _component_map by scanning the entity tree. Captures baseline snapshot on first call.
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

	if not _has_snapshot and not _active_component_scripts.is_empty():
		_initial_component_scripts = _active_component_scripts.duplicate()
		_baseline_component_nodes = _component_map.duplicate()
		_has_snapshot = true


# ==============================================================================
# GETTERS
# ==============================================================================

## Returns the runtime data resource of the given type in O(1). Logs push_error if missing.
## Usage: var move = config.get_data(D_Movement) as D_Movement
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


## Returns the component node of the given type in O(1). Logs push_warning if missing.
## Usage: var hp = config.get_comp(C_Health) as C_Health
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


## Returns true if this entity currently has the given component type active.
## Usage: if config.has_comp(C_Dead): ...
func has_comp(comp_script: Script) -> bool:
	if not comp_script:
		return false
	return _component_map.has(comp_script)


# ==============================================================================
# RUNTIME MUTATIONS
# ==============================================================================

## Adds a new component at runtime. No-op if already present. Triggers deferred NCS re-query.
## Usage: config.add_comp(C_Dead)
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
	new_node.name = class_str if not class_str.is_empty() else "C_Newcomp"
	hub.add_child(new_node)
	if new_node is NCSComponentBase:
		new_node.owner_node = hub.owner_node
		new_node.config = self
		if new_node.has_method(&"_init_comp"):
			new_node._init_comp()

	_component_map[comp_script] = new_node as NCSComponentBase

	if not _active_component_scripts.has(comp_script):
		_active_component_scripts.append(comp_script)

	NCS.update_single_entity(self)


## Removes a component at runtime. Baseline components are disabled (kept for pool restore).
## Runtime-added components are queue_freed. Triggers deferred NCS re-query.
## Usage: config.remove_comp(C_Movement)
func remove_comp(comp_script: Script) -> void:
	if not comp_script:
		return

	var target_comp = _component_map.get(comp_script, null) as Node
	if target_comp:
		_component_map.erase(comp_script)
		_active_component_scripts.erase(comp_script)
		if _baseline_component_nodes.has(comp_script):
			target_comp.process_mode = PROCESS_MODE_DISABLED
			if target_comp is CanvasItem or target_comp is Node3D:
				target_comp.hide()
		else:
			target_comp.name = "__DELETED_" + target_comp.name
			target_comp.queue_free()
		NCS.update_single_entity(self)


## Calls a method on a component node. Returns true if the call succeeded.
## Usage: config.send_signal(C_Health, &"take_damage", [20.0])
func send_signal(comp_script: Script, method_name: StringName, args: Array = []) -> bool:
	if not comp_script:
		return false

	var comp = get_comp(comp_script)
	if not is_instance_valid(comp):
		return false

	if comp.has_method(method_name):
		comp.callv(method_name, args)
		return true

	return false


## Adds a new data resource at runtime. No-op if already present. Triggers deferred NCS re-query.
## Usage: config.add_data(D_PoisonStatus)
func add_data(data_script: Script) -> void:
	if not runtime_config or not data_script or _data_map.has(data_script):
		return

	var new_data_instance = data_script.new() as NCSDataBase
	if new_data_instance:
		var data_array = runtime_config.get(&"data_sets")
		if data_array is Array:
			data_array.append(new_data_instance)
		_data_map[data_script] = new_data_instance

		NCS.update_single_entity(self)


## Removes a data resource at runtime. Triggers deferred NCS re-query.
## Usage: config.remove_data(D_PoisonStatus)
func remove_data(data_script: Script) -> void:
	if not runtime_config or not data_script:
		return

	var res = _data_map.get(data_script, null)
	if res:
		_data_map.erase(data_script)
		var data_array = runtime_config.get(&"data_sets")
		if data_array is Array:
			data_array.erase(res)

		NCS.update_single_entity(self)


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
