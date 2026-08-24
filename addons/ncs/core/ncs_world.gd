## Add an NCSWorld node into any scene to automatically discover and register
## all SystemBase children as active systems on enter_tree.
## Supports visual grouping folders (NCSSystemsFolder or Node) at any nesting depth.
@icon("res://addons/ncs/icons/globe-solid-full.svg")
class_name NCSWorld
extends NCSBase


# ==============================================================================
# BUILT-IN VIRTUAL METHODS
# ==============================================================================

func _enter_tree() -> void:
	_register_systems_in_hierarchy(self)


func _exit_tree() -> void:
	_unregister_systems_in_hierarchy(self)


# ==============================================================================
# INTERNAL HIERARCHY TRAVERSAL
# ==============================================================================

## Recursively walks the child hierarchy and registers every SystemBase it finds.
func _register_systems_in_hierarchy(current_node: Node) -> void:
	for child in current_node.get_children():
		if child is SystemBase:
			var system_name = child.get_script().get_global_name()
			if system_name.is_empty():
				system_name = child.name
			NCS.register_system(system_name, child)
			print("NCS World: System Registered -> ", system_name)

		if child.get_child_count() > 0:
			_register_systems_in_hierarchy(child)


## Recursively walks and unregisters every SystemBase found in the hierarchy.
func _unregister_systems_in_hierarchy(current_node: Node) -> void:
	for child in current_node.get_children():
		if child is SystemBase:
			var system_name = child.get_script().get_global_name()
			if system_name.is_empty():
				system_name = child.name
			NCS.unregister_system(system_name)

		if child.get_child_count() > 0:
			_unregister_systems_in_hierarchy(child)
