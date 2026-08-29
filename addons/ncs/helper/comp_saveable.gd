## Attach to any entity that needs saving.
class_name CompSaveable
extends ComponentBase

## Emitted when the serializer is building the save file.
## Other scripts can connect to this to inject their custom data into the dictionary.
signal save_data_requested(extra_data_dict: Dictionary)

## Emitted when the serializer is restoring the entity.
## Other scripts can connect to this to pull their custom data back out.
signal load_data_requested(extra_data_dict: Dictionary)

## Unique identifier for this entity,
## left empty if entity is spawned at runtime
## or set manually if entity is pre-placed in scene.
@export var save_id: String = ""

var ent_scene_path: String = ""


func _on_init_comp() -> void:
	if save_id.is_empty():
		save_id = NCSSerializer.generate_uuid()
	ent_scene_path = entity_node.scene_file_path


## Called by NCSSerializer. Gathers non-NCS data via signals.
func get_extra_data() -> Dictionary:
	var extra: Dictionary = {}
	save_data_requested.emit(extra)
	return extra


## Called by NCSSerializer. Restores non-NCS data via signals.
func apply_extra_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	load_data_requested.emit(data)
