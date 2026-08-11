class_name NCSDataBase
extends Resource

## Automatically returns the class name of the script (e.g., "HealthData")
func get_class_identifier() -> String:
	var script = get_script()
	if script:
		return script.get_global_name()
	return ""
