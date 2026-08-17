# Copyright (c) 2026 GoodyWolf / Tong-ST.
# Distributed under the terms of the MIT License.
# See LICENSE for more information.

## Drop an NCSWorld node into any scene to automatically discover and register
## all NCSSystemBase children as active systems on enter_tree.
## Supports nested Node folders for grouping systems visually in the scene tree.
class_name NCSWorld
extends NCSBase


func _enter_tree() -> void:
	_register_systems_in_hierarchy(self)


func _exit_tree() -> void:
	_unregister_systems_in_hierarchy(self)


## Recursively walks the child hierarchy and registers every NCSSystemBase it finds.
## Regular Node children are treated as visual grouping folders and are also traversed.
func _register_systems_in_hierarchy(current_node: Node) -> void:
	for child in current_node.get_children():
		if child is NCSSystemBase:
			var system_name = child.get_script().get_global_name()

			if system_name.is_empty():
				system_name = child.name
			NCS.register_system(system_name, child)
			print("NCS World: System Registered -> ", system_name)

		if child.get_child_count() > 0:
			_register_systems_in_hierarchy(child)


## Recursively walks and unregisters every NCSSystemBase found in the hierarchy.
func _unregister_systems_in_hierarchy(current_node: Node) -> void:
	for child in current_node.get_children():
		if child is NCSSystemBase:
			var system_name = child.get_script().get_global_name()
			if system_name.is_empty():
				system_name = child.name
			NCS.unregister_system(system_name)

		if child.get_child_count() > 0:
			_unregister_systems_in_hierarchy(child)
