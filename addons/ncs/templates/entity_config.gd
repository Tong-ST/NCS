class_name NCSEntityConfig
extends Resource

# A completely generic array container
@export var data_sets: Array[NCSDataBase] = []

## Finds a specific data sub-block matching the given class name automatically
func find_data_by_class(target_class_name: String) -> NCSDataBase:
	for data in data_sets:
		if is_instance_valid(data) and data.get_class_identifier() == target_class_name:
			return data
	return null
