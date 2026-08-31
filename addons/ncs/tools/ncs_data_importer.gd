@tool
class_name NCSDataImporter
extends RefCounted


## Runs the import process. Now accepts a target_class.
func run_import(csv_dir: String, target_class: String = "NCSEntityDataSet") -> void:
	print("### Starting CSV Import for: ", target_class, " ###")

	var dir = DirAccess.open(csv_dir)
	if not dir:
		push_error("NCS Importer: CSV directory does not exist: ", csv_dir)
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

	var updated_rows_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < header.size(): continue

		var dataset_path = line[path_col_idx].strip_edges()
		if dataset_path.is_empty() or not ResourceLoader.exists(dataset_path):
			push_warning("NCS Importer: Skipped import %s, Path invalid: %s" % [target_class_name, line])
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
		for p in target_block.get_property_list(): prop_types[p["name"]] = p["type"]

		var changed = false
		for prop_name in prop_indices:
			var col_idx = prop_indices[prop_name]
			var raw_str = line[col_idx]
			if prop_types.has(prop_name):
				target_block.set(prop_name, _cast_string_to_type(raw_str, prop_types[prop_name]))
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
	match type_id:
		TYPE_BOOL: return raw_str.to_lower() == "true" or raw_str == "1"
		TYPE_INT: return raw_str.to_int()
		TYPE_FLOAT: return raw_str.to_float()
		TYPE_STRING, TYPE_STRING_NAME: return raw_str
		_:
			var var_val = str_to_var(raw_str)
			if var_val != null: return var_val
			return raw_str
