extends Node

# Dictionary tracking all active systems. Key: System Class Name, Value: System Instance
var _systems: Dictionary = {}

# THE CENTRAL ENTITY REGISTRY
var active_entities: Array[EntityConfig] = []
# Map tracks EntityConfig -> Array Index (int) for O(1) Swap-and-Pop lookups
var _active_entities_map: Dictionary = {} 

# High-speed tracking flags and queues for deferred frame-end processing
var _query_dirty: bool = false
var _pending_single_updates: Array[EntityConfig] = []

const MASS_UPDATE_THRESHOLD: int = 200
var is_batching: bool = false


## Registration hook triggered automatically when an entity mounts into the world tree
func register_entity(entity: EntityConfig) -> void:
	if not _active_entities_map.has(entity):
		# Store array index in map for O(1) unregistering
		_active_entities_map[entity] = active_entities.size()
		active_entities.append(entity)

		if is_batching:
			return

		for system_name in _systems:
			var system = _systems[system_name]
			if system.has_method("_handle_incremental_arrival"):
				system._handle_incremental_arrival(entity)


## Unregistration hook triggered automatically when an entity leaves play or is deleted
func unregister_entity(entity: EntityConfig) -> void:
	if _active_entities_map.has(entity):
		# O(1) SWAP-AND-POP REMOVAL
		var idx: int = _active_entities_map[entity]
		var last_idx: int = active_entities.size() - 1
		var last_entity: EntityConfig = active_entities[last_idx]

		# Move last element to the deleted slot
		active_entities[idx] = last_entity
		_active_entities_map[last_entity] = idx

		# Fast remove last element
		active_entities.pop_back()
		_active_entities_map.erase(entity)

	if is_batching:
		return

	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method("_handle_incremental_departure"):
			system._handle_incremental_departure(entity)


## Direct targeted entity update when components or data are mutated at runtime.
func update_single_entity(entity: EntityConfig) -> void:
	if is_batching:
		return

	if is_instance_valid(entity) and not _pending_single_updates.has(entity):
		_pending_single_updates.append(entity)
		force_update_system_queries()


## Starts a manual batch scope to suppress per-entity updates during loops
func begin_batch() -> void:
	is_batching = true


## Ends the manual batch scope and executes a single global query rescan
func end_batch() -> void:
	is_batching = false
	_pending_single_updates.clear()
	_remap_all_system_queries()


## Optional wrapper to automatically execute logic inside a batch scope
func batch_mutate(action: Callable) -> void:
	begin_batch()
	action.call()
	end_batch()


## Connects a system node layout cleanly into our central management hub
func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance
	if system_instance.has_method("_update_query_filter"):
		system_instance._update_query_filter()


## Safely disconnects a system node from active registry loops
func unregister_system(system_name: String) -> void:
	_systems.erase(system_name)


## Explicit look up retrieval tool
func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)


## Collapses multiple requests into EXACTLY ONE update loop pass at frame end
func force_update_system_queries() -> void:
	if not _query_dirty:
		_query_dirty = true
		_deferred_query_remap.call_deferred()


## Triggered safely by Godot's execution thread at the very end of the frame cycle
func _deferred_query_remap() -> void:
	_query_dirty = false

	if _pending_single_updates.is_empty():
		return

	# Fallback: If single update queue spikes past threshold, do 1 linear pass instead
	if _pending_single_updates.size() >= MASS_UPDATE_THRESHOLD:
		_pending_single_updates.clear()
		_remap_all_system_queries()
		return

	var updates = _pending_single_updates.duplicate()
	_pending_single_updates.clear()
	for entity in updates:
		if is_instance_valid(entity):
			for system_name in _systems:
				var system = _systems[system_name]
				if system.has_method("_evaluate_single_entity"):
					system._evaluate_single_entity(entity)


## Executes a single, unified full world filter sweep across all active tracking nodes
func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method("_update_query_filter"):
			system._update_query_filter()
