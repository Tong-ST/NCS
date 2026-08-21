# NCS global singleton (autoload as "NCS"). Owns the master entity list and all system refs.
# Most calls come through EntityConfig (add_comp, remove_comp).
extends Node

var _systems: Dictionary = {}
var active_entities: Array[EntityConfig] = []
var _active_entities_map: Dictionary = {}

var _query_dirty: bool = false
var _pending_single_updates: Array[EntityConfig] = []

const MASS_UPDATE_THRESHOLD: int = 200
var is_batching: bool = false

# Key: Component Script, Value: Array[NCSSystemBase]
var _component_to_systems: Dictionary = {}


## Returns only systems that care about for entity update.
func _get_candidate_systems_for(entity: EntityConfig) -> Array[NCSSystemBase]:
	if not is_instance_valid(entity):
		return []

	var candidates: Dictionary = {}
	var comp_scripts = entity.get_component_scripts()

	for comp_script in comp_scripts:
		if _component_to_systems.has(comp_script):
			for sys in _component_to_systems[comp_script]:
				candidates[sys] = true

	var result: Array[NCSSystemBase] = []
	result.assign(candidates.keys())
	return result


## Called by EntityConfig._enter_tree(). Do not call manually.
func register_entity(entity: EntityConfig) -> void:
	if not _active_entities_map.has(entity):
		_active_entities_map[entity] = active_entities.size()
		active_entities.append(entity)

		if is_batching:
			return

		# Dispatch exclusively to interested systems
		var candidates = _get_candidate_systems_for(entity)
		for system in candidates:
			system._handle_incremental_arrival(entity)


## Called by EntityConfig._exit_tree() Do not call manually.
func unregister_entity(entity: EntityConfig) -> void:
	if _active_entities_map.has(entity):
		var idx: int = _active_entities_map[entity]
		var last_idx: int = active_entities.size() - 1
		var last_entity: EntityConfig = active_entities[last_idx]
		active_entities[idx] = last_entity
		_active_entities_map[last_entity] = idx
		active_entities.pop_back()
		_active_entities_map.erase(entity)

	if is_batching:
		return

	# Dispatch exclusively to interested systems
	var candidates = _get_candidate_systems_for(entity)
	for system in candidates:
		system._handle_incremental_departure(entity)


## Call after mutating an entity's components or data at runtime.
## Multiple calls per frame are coalesced — only one re-query runs at frame end.
## Usage: NCS.update_single_entity(config)
func update_single_entity(entity: EntityConfig) -> void:
	if is_batching:
		return

	if is_instance_valid(entity) and not _pending_single_updates.has(entity):
		_pending_single_updates.append(entity)
		force_update_system_queries()


## Opens a batch window — suppresses incremental system updates until end_batch().
## Use before bulk spawns or multi-entity mutations. Always pair with end_batch().
func begin_batch() -> void:
	is_batching = true


## Closes the batch window and triggers a single full-world re-query sweep.
func end_batch() -> void:
	is_batching = false
	_pending_single_updates.clear()
	_remap_all_system_queries()


## Runs a callable inside an automatic begin/end_batch scope.
## Usage: NCS.batch_mutate(func(): config.add_comp(C_Dead))
func batch_mutate(action: Callable) -> void:
	begin_batch()
	action.call()
	end_batch()


## Registers a system into the world. Called automatically by NCSWorld.
## Call manually only if not using an NCSWorld node.
func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance
	if system_instance.has_method(&"_update_query_filter"):
		system_instance._update_query_filter()

	# Index system under each component it queries
	if "interest_components" in system_instance:
		for comp_script in system_instance.interest_components:
			if not _component_to_systems.has(comp_script):
				_component_to_systems[comp_script] = []
			
			var sys_list: Array = _component_to_systems[comp_script]
			if not sys_list.has(system_instance):
				sys_list.append(system_instance)


## Removes a system from the registry.
func unregister_system(system_name: String) -> void:
	var system_instance = _systems.get(system_name)
	if system_instance:
		# Clean system out of index map
		for comp_script in _component_to_systems.keys():
			var sys_list: Array = _component_to_systems[comp_script]
			sys_list.erase(system_instance)
			if sys_list.is_empty():
				_component_to_systems.erase(comp_script)

	_systems.erase(system_name)


## Returns a live system instance by class name, or null.
## Usage: var sys = NCS.get_system_by_name("S_EnemyAI") as S_EnemyAI
func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)


## Schedules a deferred frame-end re-query. Multiple calls collapse into one.
func force_update_system_queries() -> void:
	if not _query_dirty:
		_query_dirty = true
		_deferred_query_remap.call_deferred()


## Flushes pending entity updates at frame end. Falls back to a full sweep
## when pending count exceeds MASS_UPDATE_THRESHOLD (cheaper than N dispatches).
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

	for entity in updates:
		if is_instance_valid(entity):
			var candidates = _get_candidate_systems_for(entity)
			for system in candidates:
				system._evaluate_single_entity(entity)


## Full world filter sweep — asks every system to re-evaluate all active entities.
## Called by end_batch() and the mass update fallback path.
func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method(&"_update_query_filter"):
			system._update_query_filter()
