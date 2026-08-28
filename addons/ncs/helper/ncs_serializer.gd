## Serializer for EntityConfigs, capturing their component and data blocks.
class_name NCSSerializer
extends RefCounted


## Serializes an array of EntityConfigs. Useful for passing a System's pool directly.
static func serialize_entities(
		configs: Array,
		include_transform: bool = false
) -> Array[Dictionary]:
	var serialized_array: Array[Dictionary] = []
	for config in configs:
		if is_instance_valid(config) and config is EntityConfig:
			var data = serialize_entity(config, include_transform)
			if not data.is_empty():
				serialized_array.append(data)
	return serialized_array


## Serializes a single entity, capturing its data, component topology, and optional transform.
static func serialize_entity(
		config: EntityConfig,
		include_transform: bool = false
) -> Dictionary:
	if not config or not config.runtime_config:
		return {}

	var dict: Dictionary = {
		"components": [],
		"data_blocks": []
	}

	if include_transform:
		var ent = config.entity_node
		if ent != null and "global_transform" in ent:
			dict["global_transform"] = var_to_str(ent.global_transform)

	for comp_script in config._active_component_scripts:
		dict["components"].append(comp_script.resource_path)

	var data_array = config.runtime_config.get("data_sets") as Array
	if data_array:
		for data_block in data_array:
			if is_instance_valid(data_block) and data_block is NCSDataBase:
				dict["data_blocks"].append(_serialize_data_block(data_block))

	return dict


static func _serialize_data_block(data_block: NCSDataBase) -> Dictionary:
	var script = data_block.get_script() as Script
	var props: Dictionary = {}

	for prop in data_block.get_property_list():
		var usage = prop["usage"]
		var name = prop["name"]

		# Capture only storage properties, ignore private ones
		if (usage & PROPERTY_USAGE_STORAGE) and not name.begins_with("_"):
			if name in ["script", "Built-in Script"]:
				continue
			props[name] = data_block.get(name)

	return {
		"script_path": script.resource_path,
		"properties": props
	}


## Deserializes data back into an entity, syncing topology and triggering data watchers.
static func deserialize_entity(config: EntityConfig, data: Dictionary) -> void:
	if not config or data.is_empty():
		return

	if data.has("global_transform"):
		var ent = config.entity_node
		if ent != null and "global_transform" in ent:
			var raw_transform = data["global_transform"]
			if raw_transform is String:
				ent.global_transform = str_to_var(raw_transform)
			else:
				ent.global_transform = raw_transform

	var saved_comps: Array = data.get("components", [])
	for current_comp in config._active_component_scripts.duplicate():
		if not current_comp.resource_path in saved_comps:
			config.remove_comp(current_comp)

	for comp_path in saved_comps:
		var comp_script = load(comp_path) as Script
		if comp_script and not config.has_comp(comp_script):
			config.add_comp(comp_script)

	var saved_blocks: Array = data.get("data_blocks", [])
	var saved_data_paths: Array = []
	for block in saved_blocks:
		saved_data_paths.append(block["script_path"])

	var current_data_array = config.runtime_config.get("data_sets") as Array
	for current_data in current_data_array.duplicate():
		var script = current_data.get_script()
		if not script.resource_path in saved_data_paths:
			config.remove_data(script)

	for block_dict in saved_blocks:
		var script_path: String = block_dict.get("script_path", "")
		var data_script = load(script_path) as Script
		if not data_script:
			continue

		if not config.has_data(data_script):
			config.add_data(data_script)

		var props: Dictionary = block_dict.get("properties", {})
		for prop_name in props:
			var value = props[prop_name]
			config.change_data(data_script, StringName(prop_name), value)

	NCS.mark_dirty(config)
