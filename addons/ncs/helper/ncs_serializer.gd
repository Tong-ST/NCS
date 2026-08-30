## Serializer for EntityConfigs, capturing their component and data blocks.
class_name NCSSerializer
extends RefCounted


## Extracts a formatted array of save records from a pool of entities.
## Automatically injects CompSaveable tracking data. Pairs with `sync_pool_with_save_data`.
static func extract_save_records_from_pool(
		entity_pools: Array,
		configs: Array,
		include_transform: bool = true
) -> Array[Dictionary]:
	var save_records: Array[Dictionary] = []

	for i in entity_pools.size():
		var ent = entity_pools[i]
		var config = configs[i]
		if not is_instance_valid(ent): continue

		var save_comp = config.get_comp(CompSaveable) as CompSaveable
		if not save_comp: continue

		var record: Dictionary = serialize_entity(config, include_transform)
		record["save_id"] = save_comp.save_id
		record["ent_scene_path"] = save_comp.ent_scene_path
		record["extra_data"] = save_comp.get_extra_data()

		save_records.append(record)

	return save_records


## Synchronizes an active pool of entities with an array of save records.
## - Despawns entities not present in the save data (Orphan Cleanup).
## - Restores data blocks to existing entities.
## - Spawns missing entities and applies their data instantly.
static func sync_pool_with_save_data(
		entity_pools: Array,
		configs: Array,
		save_records: Array,
		restore_callback: Callable = Callable()
) -> void:
	var saved_ids: Array[String] = []
	for record in save_records:
		saved_ids.append(record.get("save_id", ""))

	for i in range(entity_pools.size() - 1, -1, -1):
		var ent = entity_pools[i]
		var config = configs[i]
		if not is_instance_valid(ent): continue

		var save_comp = config.get_comp(CompSaveable) as CompSaveable
		if save_comp and not saved_ids.has(save_comp.save_id):
			NCS.despawn(ent)

	var live_entities = {}
	for i in range(entity_pools.size()):
		var ent = entity_pools[i]
		var config = configs[i]
		if is_instance_valid(ent):
			var save_comp = config.get_comp(CompSaveable)
			if save_comp:
				live_entities[save_comp.save_id] = { "ent": ent, "config": config }

	var scene_tree = Engine.get_main_loop() as SceneTree
	var default_parent = scene_tree.current_scene

	for record in save_records:
		var target_id: String = record.get("save_id", "")

		if live_entities.has(target_id):
			# RESTORE EXISTING
			var data = live_entities[target_id]
			deserialize_entity(data["config"], record)

			var save_comp = data["config"].get_comp(CompSaveable)
			if save_comp and record.has("extra_data"):
				save_comp.call_deferred("apply_extra_data", record["extra_data"])

			if restore_callback.is_valid():
				restore_callback.call(data["ent"], data["config"], record)
		else:
			# SPAWN MISSING
			var ent_scene_path: String = record.get("ent_scene_path", "")
			var transform_raw = record.get("global_transform", "")
			var new_transform = str_to_var(transform_raw) if transform_raw else Transform2D()

			if not ResourceLoader.exists(ent_scene_path):
				push_error("NCSSerializer: Cannot spawn missing entity, path invalid: ", ent_scene_path)
				continue

			var packed_scene = load(ent_scene_path) as PackedScene
			NCS.spawn(packed_scene, default_parent, new_transform, func(new_ent: Node):
				var new_cfg = NCS.extract_config(new_ent) as EntityConfig
				if new_cfg:
					var save_comp = new_cfg.get_comp(CompSaveable)
					if save_comp:
						save_comp.save_id = target_id
					deserialize_entity(new_cfg, record)

					if save_comp and record.has("extra_data"):
						save_comp.call_deferred("apply_extra_data", record["extra_data"])

				if restore_callback.is_valid():
					restore_callback.call(new_ent, new_cfg, record)
			)


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
				dict["data_blocks"].append(serialize_data_block(data_block))

	return dict


static func serialize_data_block(data_block: NCSDataBase) -> Dictionary:
	var script = data_block.get_script() as Script
	var props: Dictionary = {}

	for prop in data_block.get_property_list():
		var usage = prop["usage"]
		var name = prop["name"]

		if (usage & PROPERTY_USAGE_STORAGE) and not name.begins_with("_"):
			if name in ["script", "Built-in Script"]:
				continue

			var raw_value = data_block.get(name)
			props[name] = var_to_str(raw_value)

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
			var raw_value = props[prop_name]
			var value

			if typeof(raw_value) == TYPE_STRING:
				value = str_to_var(raw_value)
			else:
				value = raw_value

			config.change_data(data_script, StringName(prop_name), value)

	NCS.mark_dirty(config)


## Helper to generate a unique identifier for saveable entities
## Combining a timestamp and random value
static func generate_uuid() -> String:
	var time_tick = Time.get_ticks_usec()
	var random_val = randi() % 1000000
	return "ent_%d_%d" % [time_tick, random_val]
