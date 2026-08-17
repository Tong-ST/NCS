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

# Set automatically by NCSComponentsHub._ready() — points to the parent body (e.g. CharacterBody2D).
var owner_node: Node
# Set automatically by NCSComponentsHub._ready() — points to the sibling EntityConfig node.
var config: EntityConfig


## Optional lifecycle hook called by EntityConfig.reset_entity() on pool recycle.
## Override in subclasses to re-initialize component state back to defaults.
## This will run one and before S_System.
func _init_comp() -> void:
	pass
