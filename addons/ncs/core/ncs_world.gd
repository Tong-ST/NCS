class_name NCSWorld
extends NCSBase


func _enter_tree() -> void:
	_register_systems_in_hierarchy(self)

func _exit_tree() -> void:
	_unregister_systems_in_hierarchy(self)

## Helper function to recursively find and register systems, ignoring folder spacers
func _register_systems_in_hierarchy(current_node: Node) -> void:
	for child in current_node.get_children():
		# If the child node extends our core system base class
		if child is NCSSystemBase:
			var system_name = child.get_script().get_global_name()
			
			# Fallback if the custom script doesn't have an explicit global class_name
			if system_name.is_empty():
				system_name = child.name
				
			NCS.register_system(system_name, child)
			print("NCS World: Visual System Registered -> ", system_name)
			
		# Keep digging deeper so developers can use standard Node folders to group things!
		if child.get_child_count() > 0:
			_register_systems_in_hierarchy(child)


func _unregister_systems_in_hierarchy(current_node: Node) -> void:
	for child in current_node.get_children():
		if child is NCSSystemBase:
			var system_name = child.get_script().get_global_name()
			if system_name.is_empty():
				system_name = child.name
			NCS.unregister_system(system_name)
			
		if child.get_child_count() > 0:
			_unregister_systems_in_hierarchy(child)
