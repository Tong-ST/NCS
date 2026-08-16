class_name NCSEntityDataSet
extends Resource

@export var data_sets: Array[NCSDataBase] = []


## Fast runtime duplication of data sets (avoids slow C++ recursive deep duplication)
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


## Finds a specific data sub-block matching the given class name automatically
func find_data_by_class(target_class: Script) -> NCSDataBase:
	for data in data_sets:
		if is_instance_valid(data) and data.get_class_identifier() == target_class.to_string():
			return data
	return null
