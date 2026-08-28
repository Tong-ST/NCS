## Base class for all NCS data resources (Data* naming convention).
## Extend this to define per-entity runtime data (e.g. DataHealth, DataMovement).
## Instances live inside NCSEntityDataSet.data_sets and are duplicated per-entity at spawn.
class_name NCSDataBase
extends Resource


## Returns the script class name of this data block (e.g. "DataHealth").
## Used internally for editor validation and debug logging.
func get_class_identifier() -> String:
	var script = get_script()
	if script:
		return script.get_global_name()
	return ""
