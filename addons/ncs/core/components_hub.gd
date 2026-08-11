class_name NCSComponentsHub
extends NCSBase

## The physical body this entire folder of components controls.
## Defaults to the scene owner (e.g. CharacterBody2D) if left blank.
@export var owner_node: Node

## Reference to the local configuration data resource node.
var config_node: EntityConfig

func _ready() -> void:
	if not owner_node:
		owner_node = owner
		
	# Find the config node once for all children to share
	config_node = _find_config_node(get_parent())
	
	# Pass the owner_node and config_node references down to all children automatically
	for child in get_children():
		if child is NCSComponentBase:
			child.owner_node = owner_node
			child.config_node = config_node
			# Manually trigger their setup now that they have their references
			child.initialize_component()

func _find_config_node(start_node: Node) -> EntityConfig:
	if start_node == null: return null
	if start_node is EntityConfig: return start_node
	for child in start_node.get_children():
		if child is EntityConfig: return child
	return _find_config_node(start_node.get_parent())
