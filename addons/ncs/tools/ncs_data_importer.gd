@tool
class_name NCSDataImporter
extends RefCounted


## Runs the import process. Now accepts a target_class.
func run_import(csv_dir: String, target_class: String = "NCSEntityDataSet") -> void:
	print("### Starting CSV Import for: ", target_class, " ###")

	var dir = DirAccess.open(csv_dir)
	if not dir:
		push_error("Import Ignored: CSV directory does not exist: ", csv_dir)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var modified_files_count: int = 0

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".csv"):
			var csv_path = csv_dir.path_join(file_name)
			var target_class_name = file_name.get_basename()
			modified_files_count += _import_csv(csv_path, target_class_name, target_class)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("### CSV Import Complete! Modified %d dataset row(s) ###" % modified_files_count)


func _import_csv(csv_path: String, target_class_name: String, target_root_class: String) -> int:
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file: return 0

	var header = file.get_csv_line()
	var path_col_idx: int = -1
	for i in range(header.size()):
		if header[i] == "dataset_path":
			path_col_idx = i
			break

	if path_col_idx == -1:
		file.close()
		return 0

	var prop_indices: Dictionary = {}
	for col_idx in range(header.size()):
		var col_name = header[col_idx]
		if col_name not in ["dataset_name", "dataset_path"]:
			prop_indices[col_name] = col_idx

	var safe_types = [
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_BOOL,
		TYPE_STRING,
		TYPE_STRING_NAME,
		TYPE_VECTOR2,
		TYPE_VECTOR2I,
		TYPE_VECTOR3,
		TYPE_VECTOR3I,
		TYPE_VECTOR4,
		TYPE_VECTOR4I,
		TYPE_RECT2,
		TYPE_RECT2I,
		TYPE_COLOR,
		TYPE_ARRAY,
		TYPE_DICTIONARY
	]

	var updated_rows_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < header.size(): continue

		var dataset_path = line[path_col_idx].strip_edges()
		if dataset_path.is_empty() or not ResourceLoader.exists(dataset_path):
			push_warning("Import Ignored: Skipped import %s, Path invalid: %s" % [target_class_name, line])
			continue

		var dataset = load(dataset_path)
		if not dataset: continue

		var target_block: Resource = null

		if target_root_class == "NCSEntityDataSet":
			if "data_sets" in dataset and dataset.data_sets != null:
				for block in dataset.data_sets:
					if not is_instance_valid(block): continue
					var class_name_str = _get_resource_class_name(block)
					if class_name_str.is_empty():
						class_name_str = block.resource_path.get_file().get_basename()

					if class_name_str == target_class_name:
						target_block = block
						break
		else:
			var class_name_str = _get_resource_class_name(dataset)
			if class_name_str.is_empty():
				class_name_str = dataset_path.get_file().get_basename()

			if class_name_str == target_class_name:
				target_block = dataset

		if not target_block: continue

		var prop_types: Dictionary = {}
		var prop_hints: Dictionary = {}
		for p in target_block.get_property_list():
			prop_types[p["name"]] = p["type"]
			prop_hints[p["name"]] = p["hint_string"]

		var changed = false
		for prop_name in prop_indices:
			var col_idx = prop_indices[prop_name]
			var raw_str = line[col_idx].strip_edges()
			if raw_str.is_empty():
				continue

			if prop_types.has(prop_name):
				var target_type_id = prop_types[prop_name]

				if not (target_type_id in safe_types):
					continue

				if target_type_id == TYPE_DICTIONARY:
					var hint = prop_hints.get(prop_name, "")
					if !hint.is_empty() and ";" in hint:
						var dict_metadata = hint.get_slice(";", 0)
						if ":" in dict_metadata:
							var key_id = dict_metadata.get_slice(":", 0).to_int()
							var val_id = dict_metadata.get_slice(":", 1).to_int()
							if key_id == TYPE_OBJECT or val_id == TYPE_OBJECT:
								continue

				var casted_value = _cast_string_to_type(raw_str, target_type_id)
				var casted_type_id = typeof(casted_value)

				if casted_type_id != target_type_id:
					var is_string_match = (
						(target_type_id in [TYPE_STRING, TYPE_STRING_NAME])
						and (casted_type_id in [TYPE_STRING, TYPE_STRING_NAME])
					)
					var is_array_match = (target_type_id == TYPE_ARRAY and casted_type_id == TYPE_ARRAY)
					if not (is_string_match or is_array_match):
						push_error("Import Ignored: Type mismatch on property '"
								+ prop_name + "'. Expected type " + str(target_type_id) +
								", parsed type " + str(casted_type_id)
						)
						continue

				if target_type_id == TYPE_ARRAY:
					var clean_arr: Array = []
					for item in casted_value:
						var item_type = typeof(item)
						if (
								item_type in safe_types
								and item_type != TYPE_OBJECT
								and item_type != TYPE_ARRAY
								and item_type != TYPE_DICTIONARY
							):
							clean_arr.append(item)
					casted_value = clean_arr
				elif target_type_id == TYPE_DICTIONARY:
					var clean_dict: Dictionary = {}
					for key in casted_value:
						var key_type = typeof(key)
						var val_type = typeof(casted_value[key])
						if (
								key_type in safe_types
								and val_type in safe_types
								and key_type != TYPE_OBJECT
								and val_type != TYPE_OBJECT
							):
							clean_dict[key] = casted_value[key]
					casted_value = clean_dict

				target_block.set(prop_name, casted_value)
				changed = true

		if changed:
			ResourceSaver.save(dataset, dataset_path)
			updated_rows_count += 1

	file.close()
	print("Imported: ", csv_path.get_file(), " -> Updated %d resource(s)" % updated_rows_count)
	return updated_rows_count


func _get_resource_class_name(res: Resource) -> String:
	if not res: return ""
	var script = res.get_script() as Script
	if script and not script.get_global_name().is_empty():
		return script.get_global_name()
	return res.get_class()


func _cast_string_to_type(raw_str: String, type_id: int) -> Variant:
	raw_str = raw_str.strip_edges()
	match type_id:
		TYPE_BOOL:
			return raw_str.to_lower() == "true" or raw_str == "1"
		TYPE_INT:
			return raw_str.to_int()
		TYPE_FLOAT:
			return raw_str.to_float()
		TYPE_STRING, TYPE_STRING_NAME:
			return raw_str
		TYPE_ARRAY, TYPE_DICTIONARY:
			if raw_str.begins_with("[") or raw_str.begins_with("{"):
				var json = JSON.new()
				if json.parse(raw_str) == OK:
					if type_id == TYPE_ARRAY:
						return Array(json.data)
					return json.data

			var var_val = str_to_var(raw_str)
			if var_val != null:
				return var_val
			return [] if type_id == TYPE_ARRAY else {}
		TYPE_VECTOR2, TYPE_VECTOR2I:
			var var_val = str_to_var(raw_str)
			return (var_val
					if var_val != null
					else (Vector2.ZERO
					if type_id == TYPE_VECTOR2
					else Vector2i.ZERO)
			)
		TYPE_VECTOR3, TYPE_VECTOR3I:
			var var_val = str_to_var(raw_str)
			return (var_val
					if var_val != null
					else (Vector3.ZERO
					if type_id == TYPE_VECTOR3
					else Vector3i.ZERO)
			)
		TYPE_VECTOR4, TYPE_VECTOR4I:
			var var_val = str_to_var(raw_str)
			return (var_val
					if var_val != null
					else (Vector4.ZERO
					if type_id == TYPE_VECTOR4
					else Vector4i.ZERO)
			)
		TYPE_RECT2, TYPE_RECT2I:
			var var_val = str_to_var(raw_str)
			return (var_val
					if var_val != null
					else (Rect2()
					if type_id == TYPE_RECT2
					else Rect2i())
			)
		TYPE_COLOR:
			var var_val = str_to_var(raw_str)
			return (var_val
					if var_val != null
					else Color.WHITE
			)
		_:
			var var_val = str_to_var(raw_str)
			if var_val != null:
				return var_val
			return raw_str
