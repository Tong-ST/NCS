## Central folder hub node for grouping ComponentBase children on an entity.
## Add this as a child of your entity root (e.g. CharacterBody2D), then place
## component nodes inside it. The hub auto-wires entity and config references
## to all child components on _ready.
##
## Editor validation: checks if a component declares require_data=true
## and validates that the matching Data* resource is present in EntityConfig.
@tool
@icon("res://addons/ncs/icons/diagram-project-solid-full.svg")
class_name ComponentsHub
extends NCSBase

## The physical body this hub's components operate on.
## Auto-resolved to the scene owner if left blank in the inspector.
@export var entity_node: Node

# Cached reference to the sibling EntityConfig node found at runtime.
var config_node: EntityConfig


# ==============================================================================
# RUNTIME INITIALIZATION
# ==============================================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Resolve entity from scene owner when not explicitly set in the inspector.
	if not entity_node:
		entity_node = owner

	config_node = _find_config_node(entity_node)

	# Push entity and config references down to every child component automatically.
	for child in get_children():
		if child is ComponentBase:
			child.entity_node = entity_node
			child.config = config_node
			if child.has_method(&"_on_init_comp"):
				child._on_init_comp()


# ==============================================================================
# EDITOR VALIDATION & WARNINGS
# ==============================================================================

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		var inspector = EditorInterface.get_inspector()
		if not inspector.property_edited.is_connected(_on_property_edited):
			inspector.property_edited.connect(_on_property_edited)
		if not inspector.edited_object_changed.is_connected(_on_editor_context_changed):
			inspector.edited_object_changed.connect(_on_editor_context_changed)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		var inspector = EditorInterface.get_inspector()
		if inspector.property_edited.is_connected(_on_property_edited):
			inspector.property_edited.disconnect(_on_property_edited)
		if inspector.edited_object_changed.is_connected(_on_editor_context_changed):
			inspector.edited_object_changed.disconnect(_on_editor_context_changed)


func _on_property_edited(_what: String) -> void:
	update_configuration_warnings()


func _on_editor_context_changed() -> void:
	update_configuration_warnings()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return

	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		update_configuration_warnings()


## Editor validation: checks that every component with require_data=true has a matching
## Data* resource in the sibling EntityConfig's data_sets array.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if not Engine.is_editor_hint():
		return warnings

	var editor_config = _find_config_node(entity_node)
	if not editor_config:
		return warnings

	# Fast lookup list of data class names currently in the config array.
	var available_data_classes: Array[String] = []
	if editor_config.base_config:
		var raw_data_sets = editor_config.base_config.get(&"data_sets")
		if raw_data_sets is Array:
			var global_classes = ProjectSettings.get_global_class_list()
			for res in raw_data_sets:
				if is_instance_valid(res) and res.get_script():
					var res_script_path = res.get_script().resource_path
					for class_info in global_classes:
						if class_info.path == res_script_path:
							available_data_classes.append(class_info.class)
							break

	# Validate: CompMovement -> expects DataMovement in data_sets.
	for child in get_children():
		if "require_data" in child and child.get(&"require_data") == true:
			var script = child.get_script()
			if not script:
				warnings.append("NCS Layout Error: Node [%s] has 'Require Data' enabled but does not have a script attached! All components require a type class script." % child.name)
				continue

			var script_class_name = script.get_global_name()
			if not script_class_name.is_empty():
				var base_identity = script_class_name.replace("Component", "")
				var expected_data_class = base_identity.replace("Comp", "Data")
				if not available_data_classes.has(expected_data_class):
					warnings.append("NCS Configuration Error: Component class [%s] explicitly requires a Data Resource named [%s], but it's missing from your EntityConfig array!" % [script_class_name, expected_data_class])

	return warnings


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

## Searches the immediate parent and its direct children for a sibling EntityConfig node.
func _find_config_node(start_node: Node) -> EntityConfig:
	if start_node == null:
		return null

	if start_node is EntityConfig:
		return start_node as EntityConfig

	for child in start_node.get_children():
		if child is EntityConfig:
			return child as EntityConfig
	return null
