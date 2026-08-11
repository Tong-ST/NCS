extends NCSBase

# Dictionary tracking all active systems. Key: Script Class Name, Value: System Instance
var _systems: Dictionary = {}
# Global registry of active entities
var active_entities: Array[EntityConfig] = []


func register_entity(entity: EntityConfig) -> void:
	if not active_entities.has(entity):
		active_entities.append(entity)

func unregister_entity(entity: EntityConfig) -> void:
	active_entities.erase(entity)

## Systems call this to announce themselves to the framework
func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance

## Systems call this to clean up when a level ends
func unregister_system(system_name: String) -> void:
	_systems.erase(system_name)

## Components look up their processing systems safely via String IDs
func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)
