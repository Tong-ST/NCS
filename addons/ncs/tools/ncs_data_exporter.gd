@tool
class_name NCSDataExporter
extends RefCounted


## Runs the export process. Now accepts a target_class.
func run_export(
		scan_dir: String,
		output_dir: String,
		target_class: String = "NCSEntityDataSet"
) -> void:
	print("### Starting CSV Export for: ", target_class, " ###")

	var dataset_paths: Array[String] = []
	_scan_directory_recursive(scan_dir, dataset_paths, target_class)

	if dataset_paths.is_empty():
		push_warning("NCS Exporter: No resources of type '", target_class, "' found in: ", scan_dir)
		return

	var data_class_map: Dictionary = {}

	for path in dataset_paths:
		var res = load(path)
		if not res: continue

		if target_class == "NCSEntityDataSet":
			if "data_sets" in res and res.data_sets != null:
				for data_block in res.data_sets:
					_process_resource_to_map(data_block, path, data_class_map)
		else:
			_process_resource_to_map(res, path, data_class_map)

	_write_csv_files(data_class_map, output_dir)
	print("###############################")
	print("### CSV Export Complete ###")
	print("###############################")


func _process_resource_to_map(res: Resource, path: String, data_class_map: Dictionary) -> void:
	if not is_instance_valid(res): return

	var class_name_str = _get_resource_class_name(res)
	if class_name_str.is_empty():
		class_name_str = res.resource_path.get_file().get_basename()

	if not data_class_map.has(class_name_str):
		data_class_map[class_name_str] = {
			"props": _get_exported_properties(res),
			"rows": []
		}

	var row: Dictionary = { "dataset_path": path }
	var props: Array = data_class_map[class_name_str]["props"]
	for prop_name in props:
		row[prop_name] = res.get(prop_name)

	data_class_map[class_name_str]["rows"].append(row)


func _scan_directory_recursive(
		dir_path: String,
		out_paths: Array[String],
		target_class: String
) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir: return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_directory_recursive(dir_path.path_join(file_name), out_paths, target_class)
		else:
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var res = load(dir_path.path_join(file_name))
				if res:
					var res_class = _get_resource_class_name(res)
					if res_class == target_class:
						out_paths.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _get_resource_class_name(res: Resource) -> String:
	if not res: return ""
	var script = res.get_script() as Script
	if script and not script.get_global_name().is_empty():
		return script.get_global_name()
	return res.get_class()


func _get_exported_properties(data_block: Resource) -> Array[String]:
	var exported_props: Array[String] = []
	var ignore_props = ["script", "resource_name", "resource_local_to_scene", "resource_path"]

	for prop in data_block.get_property_list():
		var usage = prop["usage"]
		var name = prop["name"]
		if (usage & PROPERTY_USAGE_EDITOR) and (usage & PROPERTY_USAGE_STORAGE):
			if not name.begins_with("_") and not name.begins_with("metadata/") and not name in ignore_props:
				exported_props.append(name)
	return exported_props


func _write_csv_files(data_class_map: Dictionary, output_dir: String) -> void:
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	var gdignore_path = output_dir.path_join(".gdignore")
	if not FileAccess.file_exists(gdignore_path):
		var ignore_file = FileAccess.open(gdignore_path, FileAccess.WRITE)
		ignore_file.store_string("Ignore CSVs.")
		ignore_file.close()

	for class_name_str in data_class_map:
		var info = data_class_map[class_name_str]
		var props: Array = info["props"]
		var rows: Array = info["rows"]

		if props.is_empty(): continue

		var csv_path = output_dir.path_join(class_name_str + ".csv")
		var file = FileAccess.open(csv_path, FileAccess.WRITE)
		if not file: continue

		var header: PackedStringArray = ["dataset_name"]
		for p in props: header.append(str(p))
		header.append("dataset_path")
		file.store_csv_line(header)

		for row in rows:
			var path_str: String = row["dataset_path"]
			var d_name: String = path_str.get_file().get_basename()
			var line: PackedStringArray = [d_name]
			for p in props: line.append(str(row.get(p)))
			line.append(path_str)
			file.store_csv_line(line)

		file.close()
		print("Exported: ", csv_path, " (%d row(s))" % rows.size())
