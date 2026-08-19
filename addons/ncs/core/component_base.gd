## Base class for all NCS component scripts.
## Attach subclasses (e.g. C_Health, C_Movement) as child nodes inside a NCSComponentsHub.
##
## Naming convention matters: use C_ prefix for component nodes (C_Health, C_Input, C_Dead).
## Components can be pure tag-nodes with no script logic — used only as query filters.
class_name NCSComponentBase
extends NCSBase

## require_data: set true if this component expects a matching D_* resource in the EntityConfig.
## The editor hub validator will warn you if the resource is missing from the data_sets array.
@export var require_data: bool = false

## Points to the parent body (e.g. CharacterBody2D).
var owner_node: Node
## Points to the sibling EntityConfig node.
var config: EntityConfig


## Execute at start when entity enter to scene-tree, with owner_node and config references.
func _on_init_comp() -> void:
	pass


## Execute when new component add to entity, owner_node and config will base on current entity.
func _on_add_comp() -> void:
	pass


## Execute when component was remove from entity, owner_node and config will base on last entity.
func _on_remove_comp() -> void:
	pass
