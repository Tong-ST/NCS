extends Node

# Dictionary tracking all active systems. Key: System Class Name, Value: System Instance
var _systems: Dictionary = {}

# THE CENTRAL ENTITY REGISTRY: Tracks every entity alive in the game world
var active_entities: Array[EntityConfig] = []

func register_entity(entity: EntityConfig) -> void:
	if not active_entities.has(entity):
		active_entities.append(entity)
		# Notify all active systems that a new entity arrived so they can re-query
		_remap_all_system_queries()

func unregister_entity(entity: EntityConfig) -> void:
	active_entities.erase(entity)
	_remap_all_system_queries()

func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance
	# Run an initial query map when a new system is registered
	if system_instance.has_method("_update_query_filter"):
		system_instance.call("_update_query_filter")

func unregister_system(system_name: String) -> void:
	_systems.erase(system_name)

func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)

func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method("_update_query_filter"):
			system.call("_update_query_filter")
