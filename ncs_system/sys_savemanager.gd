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
	# Helper for saving the whole entity_poosl with CompSaveable attached into save_records.
	var save_records = NCSSerializer.extract_save_records_from_pool(entity_pools, config, true)

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

	# Helper to sync the whole entity_pools with CompSaveable attached.
	NCSSerializer.sync_pool_with_save_data(
		entity_pools,
		config,
		save_records,
		_on_entity_restored # Pass our custom logic as a callback
	)
	print("SysSaveManager: Load sequence initiated.")


## Custom callback after an entity is loaded/spawned
## Use for update extra data which non NCS-Data
func _on_entity_restored(ent: Node, ent_config: EntityConfig, record: Dictionary) -> void:
	var save_comp = ent_config.get_comp(CompSaveable) as CompSaveable
	if save_comp and record.has("extra_data"):
		save_comp.apply_extra_data(record["extra_data"])

	# Custom sync for movement data
	_sync_custom_movement_data(ent, ent_config)


## Helper to sync movement data if your Movement system tied to data
func _sync_custom_movement_data(ent: Node, ent_config: EntityConfig) -> void:
	if ent_config.has_data(DataMovement):
		var move_data = ent_config.get_data(DataMovement) as DataMovement
		move_data.next_global_pos = ent.global_position
		move_data.is_pos_initialized = true
		move_data.velocity = Vector2.ZERO
