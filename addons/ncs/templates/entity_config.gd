class_name NCSEntityDataSet
extends Resource

@export var data_sets: Array[NCSDataBase] = []


## Finds a specific data sub-block matching the given class name automatically
func find_data_by_class(target_class: Script) -> NCSDataBase:
	for data in data_sets:
		if is_instance_valid(data) and data.get_class_identifier() == target_class.to_string():
			return data
	return null
