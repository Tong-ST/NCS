extends Node

# Dictionary tracking all active systems. Key: System Class Name, Value: System Instance
var _systems: Dictionary = {}

# THE CENTRAL ENTITY REGISTRY: Tracks every entity alive in the game world
var active_entities: Array[EntityConfig] = []

# A flag tracking variable to make sure we only queue one refresh per frame pass
var _query_dirty: bool = false

func register_entity(entity: EntityConfig) -> void:
	if not active_entities.has(entity):
		active_entities.append(entity)
		# 🎯 THE PERFORMANCE SAVER:
		# Instead of updating instantly, queue a single combined pass at the end of the frame!
		_queue_query_update()

func unregister_entity(entity: EntityConfig) -> void:
	active_entities.erase(entity)
	_queue_query_update()

func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance
	if system_instance.has_method("_update_query_filter"):
		system_instance.call("_update_query_filter")

func unregister_system(system_name: String) -> void:
	_systems.erase(system_name)

func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)

func force_update_system_queries() -> void:
	_queue_query_update()

## 🎯 THE BATCH MANAGER:
## Ensures that no matter how many entities join or mutate on a single frame, 
## the heavy query loops run EXACTLY ONCE at the end of the frame!
func _queue_query_update() -> void:
	if not _query_dirty:
		_query_dirty = true
		_deferred_remap.call_deferred()

func _deferred_remap() -> void:
	_query_dirty = false
	_remap_all_system_queries()

func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method("_update_query_filter"):
			system.call("_update_query_filter")
