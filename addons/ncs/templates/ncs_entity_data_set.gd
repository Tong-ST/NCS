## Blueprint resource container that holds all data blocks for one entity archetype.
## Assign this as the base_config on an EntityConfig node in the inspector.
##
## At runtime, each spawned entity receives its own deep-duplicated instance so
## data changes on one entity never affect others sharing the same base blueprint.
@icon("res://addons/ncs/icons/cubes-solid-full.svg")
class_name NCSEntityDataSet
extends Resource

@export var data_sets: Array[NCSDataBase] = []


## Finds the first data block matching the given Script type inside data_sets.
func find_data_by_class(target_class: Script) -> NCSDataBase:
	if not target_class:
		return null
	var target_name = target_class.get_global_name()
	for data in data_sets:
		if is_instance_valid(data) and data.get_class_identifier() == target_name:
			return data
	return null
