# NCS global singleton (autoload as "NCS"). Owns the master entity list and all system refs.
# Most calls come through EntityConfig (add_comp, remove_comp, add_data, remove_data).
extends Node

const MASS_UPDATE_THRESHOLD: int = 500

var active_entities: Array[EntityConfig] = []

var _systems: Dictionary = {}
var _active_entities_map: Dictionary = {}

var _query_dirty: bool = false
var _pending_single_updates: Dictionary = {}
var _is_batching: bool = false
var _script_to_systems: Dictionary = {}


## Returns systems that care about the entity's current components/data OR specific changed scripts.
func _get_candidate_systems_for(
			entity: EntityConfig,
			changed_scripts: Array = []) -> Array[NCSSystemBase]:
	if not is_instance_valid(entity):
		return []

	var candidates: Dictionary = {}
	var all_scripts: Array[Script] = []

	if entity.has_method(&"get_component_scripts"):
		all_scripts.append_array(entity.get_component_scripts())
	if entity.has_method(&"get_data_scripts"):
		all_scripts.append_array(entity.get_data_scripts())

	for script in changed_scripts:
		if script and not all_scripts.has(script):
			all_scripts.append(script)

	for script in all_scripts:
		if _script_to_systems.has(script):
			for sys in _script_to_systems[script]:
				candidates[sys] = true

	var result: Array[NCSSystemBase] = []
	result.assign(candidates.keys())
	return result


## Called by EntityConfig._enter_tree(). Do not call manually.
func register_entity(entity: EntityConfig) -> void:
	if not _active_entities_map.has(entity):
		_active_entities_map[entity] = active_entities.size()
		active_entities.append(entity)

		if _is_batching:
			return

		var candidates = _get_candidate_systems_for(entity)
		# Fallback to all systems if entity has no initial scripts attached yet
		if candidates.is_empty():
			for sys in _systems.values():
				if sys.has_method(&"_evaluate_single_entity"):
					sys._evaluate_single_entity(entity)
		else:
			for system in candidates:
				if system.has_method(&"_evaluate_single_entity"):
					system._evaluate_single_entity(entity)


## Called by EntityConfig._exit_tree(). Do not call manually.
func unregister_entity(entity: EntityConfig) -> void:
	if _active_entities_map.has(entity):
		var idx: int = _active_entities_map[entity]
		var last_idx: int = active_entities.size() - 1
		var last_entity: EntityConfig = active_entities[last_idx]
		active_entities[idx] = last_entity
		_active_entities_map[last_entity] = idx
		active_entities.pop_back()
		_active_entities_map.erase(entity)

	if _is_batching:
		return

	_pending_single_updates.erase(entity)

	# Notify all systems on departure to guarantee pool cleanups
	for sys in _systems.values():
		if sys.has_method(&"_handle_incremental_departure"):
			sys._handle_incremental_departure(entity)


## Call after mutating an entity's components or data at runtime.
## Usage: NCS.update_single_entity(config, D_PoisonStatus)
func update_single_entity(entity: EntityConfig, changed_script: Script = null) -> void:
	if _is_batching or not is_instance_valid(entity):
		return

	if not _pending_single_updates.has(entity):
		_pending_single_updates[entity] = []

	if changed_script and not _pending_single_updates[entity].has(changed_script):
		_pending_single_updates[entity].append(changed_script)

	force_update_system_queries()


## Opens a batch window — suppresses incremental system updates until end_batch().
func begin_batch() -> void:
	_is_batching = true


## Closes the batch window and triggers a single full-world re-query sweep.
func end_batch() -> void:
	_is_batching = false
	_pending_single_updates.clear()
	_remap_all_system_queries()


## Runs a callable inside an automatic begin/end_batch scope.
func batch_mutate(action: Callable) -> void:
	begin_batch()
	action.call()
	end_batch()


## Registers a system into the world. Called automatically by NCSWorld.
func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance
	if system_instance.has_method(&"_update_query_filter"):
		system_instance._update_query_filter()

	# Index system under each Component & Data script it queries
	var scripts_to_index: Array = []
	if "interest_scripts" in system_instance:
		scripts_to_index.append_array(system_instance.interest_scripts)

	for script in scripts_to_index:
		if not _script_to_systems.has(script):
			_script_to_systems[script] = []

		var sys_list: Array = _script_to_systems[script]
		if not sys_list.has(system_instance):
			sys_list.append(system_instance)


## Removes a system from the registry.
func unregister_system(system_name: String) -> void:
	var system_instance = _systems.get(system_name)
	if system_instance:
		for script in _script_to_systems.keys():
			var sys_list: Array = _script_to_systems[script]
			sys_list.erase(system_instance)
			if sys_list.is_empty():
				_script_to_systems.erase(script)

	_systems.erase(system_name)


## Returns a live system instance by class name, or null.
func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)


## Schedules a deferred frame-end re-query. Multiple calls collapse into one.
func force_update_system_queries() -> void:
	if not _query_dirty:
		_query_dirty = true
		_deferred_query_remap.call_deferred()


## Flushes pending entity updates at frame end.
func _deferred_query_remap() -> void:
	_query_dirty = false

	if _pending_single_updates.is_empty():
		return

	if _pending_single_updates.size() >= MASS_UPDATE_THRESHOLD:
		_pending_single_updates.clear()
		_remap_all_system_queries()
		return

	var updates = _pending_single_updates.duplicate()
	_pending_single_updates.clear()

	for entity in updates.keys():
		if is_instance_valid(entity):
			var changed_scripts: Array = updates[entity]
			var candidates = _get_candidate_systems_for(entity, changed_scripts)
			for system in candidates:
				if system.has_method(&"_evaluate_single_entity"):
					system._evaluate_single_entity(entity)


## Full world filter sweep — asks every system to re-evaluate all active entities.
func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method(&"_update_query_filter"):
			system._update_query_filter()
