## Example System to manage save/load pair with NCSSerializer helper
## Files related: sys_savemanager.gd, comp_saveable.gd, ncs_serializer.gd
class_name SysSaveManager
extends SystemBase

const SAVE_PATH := "user://save_data.json"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save"):
		save_game()
	if event.is_action_pressed("load"):
		load_game()


func setup_query() -> void:
	# Filter only entities that have CompSaveable attached
	with_all([CompSaveable])


## Example of custom save method with NCSSerializer helper.
func save_game() -> void:
	var save_records: Array[Dictionary] = []
	# Use entity_pools direct access to filtered entity.
	for i in entity_pools.size():
		var ent = entity_pools[i]
		if not is_instance_valid(ent): continue

		var save_comp = config[i].get_comp(CompSaveable) as CompSaveable
		if not save_comp: continue

		# Using NCSSerializer helper to extract EntityConfig for save_records
		var record: Dictionary = NCSSerializer.serialize_entity(config[i], true)
		record["save_id"] = save_comp.save_id
		record["scene_path"] = save_comp.scene_path_to_spawn
		record["extra_data"] = save_comp.get_extra_data()

		save_records.append(record)

	# Write to file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_records, "\t"))
		file.close()
		print("SysSaveManager: Saved %d entities." % save_records.size())


## Example of custom load method with NCSSerializer helper.
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var raw_text = file.get_as_text()
	file.close()

	var save_records: Array = JSON.parse_string(raw_text)

	for record in save_records:
		var target_id: String = record.get("save_id", "")
		var scene_path: String = record.get("scene_path", "")

		var ent = _find_entity_by_save_id(target_id)
		if not ent and not scene_file_path.is_empty():
			ent = _spawn_missing_entity(scene_path)
		if not ent:
			continue

		# Restore NCS DataBlocks, Comp, etc. global_transform if on save track global transform
		var ent_config = ent.get_node_or_null("EntityConfig") as EntityConfig
		if ent_config:
			var save_comp = ent_config.get_comp(CompSaveable) as CompSaveable
			if save_comp:
				save_comp.save_id = target_id
				# Restore Non-NCS Data
				if record.has("extra_data"):
					save_comp.apply_extra_data(record["extra_data"])

			NCSSerializer.deserialize_entity(ent_config, record)

			# Custom sync for movement data
			_sync_custom_movement_data(ent, ent_config)

	print("SysSaveManager: Load complete.")


## Helper to match saved ID with live entities in query
func _find_entity_by_save_id(target_id: String) -> Node:
	for i in entity_pools.size():
		var ent = entity_pools[i]
		if not is_instance_valid(ent):
			continue
		var save_comp = config[i].get_comp(CompSaveable) as CompSaveable
		if save_comp and save_comp.save_id == target_id:
			return ent
	return null


## Helper to instantiate entities that are missing from the scene
func _spawn_missing_entity(scene_path: String) -> Node:
	if not ResourceLoader.exists(scene_path):
		push_error("Cannot spawn missing entity, path invalid: ", scene_path)
		return null

	var packed_scene = load(scene_path) as PackedScene
	var new_ent = packed_scene.instantiate()

	get_tree().current_scene.add_child(new_ent)
	return new_ent


func _sync_custom_movement_data(ent: Node, ent_config: EntityConfig) -> void:
	if ent_config.has_data(DataMovement):
		var move_data = ent_config.get_data(DataMovement) as DataMovement
		move_data.next_global_pos = ent.global_position
		move_data.is_pos_initialized = true
		move_data.velocity = Vector2.ZERO
