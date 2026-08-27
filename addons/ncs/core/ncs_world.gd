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
	NCS.current_world = self


func _exit_tree() -> void:
	if NCS.current_world == self:
		NCS.current_world = null
