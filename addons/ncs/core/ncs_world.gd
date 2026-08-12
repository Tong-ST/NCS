@tool
class_name NCSWorld
extends NCSBase

## Drag and drop your system scripts into this array inside the Inspector
## Example: [res://movement_system.gd, res://combat_system.gd]
@export var active_systems: Array[Script] = []


func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	# Loop through the user-defined array and spawn each system explicitly
	for system_script in active_systems:
		if not system_script: 
			continue
			
		var system_name = system_script.get_global_name()
		
		# If the script doesn't have a class_name, use the filename as the fallback identifier
		if system_name.is_empty():
			system_name = system_script.resource_path.get_file().get_basename().to_camel_case()
			
		var system_instance = system_script.new()
		system_instance.name = system_name
		
		# Add the system as a child of this World node so it processes natively
		add_child(system_instance)
		
		# Register it to the global manager registry so components can find it
		NCS.register_system(system_name, system_instance)
		print("NCS World: Activated system -> ", system_name)


func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	# Clean up registration when the level changes or closes
	for system_script in active_systems:
		if not system_script: 
			continue
		var system_name = system_script.get_global_name()
		if system_name.is_empty():
			system_name = system_script.resource_path.get_file().get_basename().to_camel_case()
		NCS.unregister_system(system_name)
