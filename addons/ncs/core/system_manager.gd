extends Node

# Dictionary tracking all active systems. Key: System Class Name, Value: System Instance
var _systems: Dictionary = {}

# THE CENTRAL ENTITY REGISTRY: Tracks every entity alive in the game world
var active_entities: Array[EntityConfig] = []

# High-speed tracking flag used to collapse multiple refresh signals into a single frame pass
var _query_dirty: bool = false

## Registration hook triggered automatically when an entity mounts into the world tree
func register_entity(entity: EntityConfig) -> void:
	if not active_entities.has(entity):
		active_entities.append(entity)
		
		for system_name in _systems:
			var system = _systems[system_name]
			if system.has_method("_handle_incremental_arrival"):
				system.call("_handle_incremental_arrival", entity)


## Unregistration hook triggered automatically when an entity leaves play or is deleted
func unregister_entity(entity: EntityConfig) -> void:
	active_entities.erase(entity)
	
	# O(1) High-Speed Single Subtraction: Notify systems immediately
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method("_handle_incremental_departure"):
			system.call("_handle_incremental_departure", entity)


## Connects a system node layout cleanly into our central management hub
func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance
	if system_instance.has_method("_update_query_filter"):
		system_instance.call("_update_query_filter")


## Safely disconnects a system node from active registry loops
func unregister_system(system_name: String) -> void:
	_systems.erase(system_name)


## Explicit look up retrieval tool
func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)


## this function collapses multiple requests into EXACTLY ONE update loop pass.
func force_update_system_queries() -> void:
	if not _query_dirty:
		_query_dirty = true
		_deferred_query_remap.call_deferred()


## Triggered safely by Godot's execution thread at the very end of the frame cycle
func _deferred_query_remap() -> void:
	_query_dirty = false
	_remap_all_system_queries()


## Executes a single, unified full world filter sweep across all active tracking nodes
func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method("_update_query_filter"):
			system.call("_update_query_filter")
