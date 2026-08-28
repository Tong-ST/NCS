## Example Component to manage save/load pair with NCSSerializer helper
## files related: sys_savemanager.gd, comp_saveable.gd, ncs_serializer.gd
class_name CompSaveable
extends ComponentBase

@export var save_id: String = ""
var scene_path_to_spawn: String = ""


func _ready() -> void:
	if save_id.is_empty():
		save_id = _generate_uuid()
	call_deferred("_capture_scene_path")


## Collects non-NCS data living in entity (e.g. player.gd)
func get_extra_data() -> Dictionary:
	var extra: Dictionary = {}

	# Check if parent script has non-NCS variables to save
	if "score" in entity_node:
		extra["score"] = entity_node.score

	return extra


## Restores non-NCS data back in entity.
func apply_extra_data(data: Dictionary) -> void:
	if "score" in entity_node and data.has("score"):
		entity_node.score = data["score"]


func _capture_scene_path() -> void:
	if is_instance_valid(config) and is_instance_valid(config.entity_node):
		scene_path_to_spawn = entity_node.scene_file_path


func _generate_uuid() -> String:
	var time_tick = Time.get_ticks_usec()
	var random_val = randi() % 1000000
	return "ent_%d_%d" % [time_tick, random_val]
