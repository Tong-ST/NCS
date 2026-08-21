## Blueprint resource container that holds all data blocks for one entity archetype.
## Assign this as the base_config on an EntityConfig node in the inspector.
##
## At runtime, each spawned entity receives its own deep-duplicated instance so
## data changes on one entity never affect others sharing the same base blueprint.
class_name NCSEntityDataSet
extends Resource

@export var data_sets: Array[NCSDataBase] = []


## Creates a shallow-per-element duplicate of data_sets.
## Each NCSDataBase element is individually duplicated so resources are not shared.
func duplicate_runtime() -> NCSEntityDataSet:
	var copy = NCSEntityDataSet.new()
	var new_sets: Array[NCSDataBase] = []
	var count = data_sets.size()
	new_sets.resize(count)
	for i in count:
		var res = data_sets[i]
		if is_instance_valid(res):
			new_sets[i] = res.duplicate() as NCSDataBase
	copy.data_sets = new_sets
	return copy


## Finds the first data block matching the given Script type inside data_sets.
func find_data_by_class(target_class: Script) -> NCSDataBase:
	for data in data_sets:
		if is_instance_valid(data) and data.get_class_identifier() == target_class.get_global_name():
			return data
	return null