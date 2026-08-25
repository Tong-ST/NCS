## Base class for all NCS component scripts.
## Attach subclasses (e.g. CompHealth, CompMovement) as child nodes inside an ComponentsHub.
##
## Components can be pure tag-nodes with no script logic (filters) or contain local entity logic.
@icon("res://addons/ncs/icons/cube-solid-full.svg")
class_name ComponentBase
extends NCSBase

## Set true if this component expects a matching Data* resource in the EntityConfig.
## The editor hub validator will warn you if the resource is missing from the data_sets array.
@export var require_data: bool = false

## Points to the parent entity body (e.g. CharacterBody2D). Auto-wired by ComponentsHub.
var entity_node: Node

## Points to the sibling EntityConfig node. Auto-wired by ComponentsHub.
var config: EntityConfig


# ==============================================================================
# VIRTUAL COMPONENT LIFECYCLE HOOKS
# ==============================================================================

## Called when the entity enters the scene tree and references are wired.
## Override in subclasses to initialize component state or register data watchers.
func _on_init_comp() -> void:
	pass


## Called when this component is dynamically added to an entity at runtime (via add_comp).
func _on_add_comp() -> void:
	pass


## Called when this component is dynamically removed from an entity at runtime (via remove_comp).
func _on_remove_comp() -> void:
	pass
