## Central folder hub node for grouping NCSComponentBase children on an entity.
## Add this as a child of your entity root (e.g. CharacterBody2D), then place
## component nodes inside it. The hub auto-wires owner_node and config references
## to all child components on _ready.
##
## Editor validation: the hub runs configuration warnings if a component declares
## require_data=true but the matching D_* resource is absent from the EntityConfig data_sets.
@tool
class_name NCSComponentsHub
extends NCSBase

## The physical body this hub's components operate on.
## Auto-resolved to the scene owner if left blank in the inspector.
@export var owner_node: Node

# Cached reference to the sibling EntityConfig node found at runtime.
var config_node: EntityConfig


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Resolve owner_node from scene owner when not explicitly set in the inspector.
	if not owner_node:
		owner_node = owner

	config_node = _find_config_node(get_parent())

	# Push owner_node and config references down to every child component automatically.
	for child in get_children():
		if child is NCSComponentBase:
			child.owner_node = owner_node
			child.config = config_node
			if child.has_method(&"_on_init_comp"):
				child._on_init_comp()


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


## Fires on child drag-and-drop or reorder so the warning panel stays up to date.
func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return

	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		update_configuration_warnings()


## Editor validation: checks that every component with require_data=true has a matching
## D_* resource in the sibling EntityConfig's data_sets array.
## Runs on the editor's 0.5-second heartbeat tick and on property edits.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if not Engine.is_editor_hint():
		return warnings

	var editor_config = _find_config_node(get_parent())
	if not editor_config:
		return warnings

	# Build a fast lookup list of data class names currently in the config array.
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

	# Validate: C_Movement -> expects D_Movement in data_sets.
	for child in get_children():
		if "require_data" in child and child.get(&"require_data") == true:
			var script = child.get_script()
			if not script:
				warnings.append(
						"NCS Layout Error: Node [" + child.name + "]
						has 'Require Data' enabled but does not have a script attached! 
						All components require a type class script."
				)
				continue

			# Derive expected resource name: C_Movement -> D_Movement.
			var script_class_name = script.get_global_name()
			if not script_class_name.is_empty():
				var base_identity = script_class_name.replace("Component", "")
				var expected_data_class_1 = base_identity.replace("C_", "D_")
				if not available_data_classes.has(expected_data_class_1):
					warnings.append(
							"NCS Configuration Error: Component class [" + script_class_name + "]
							explicitly requires a Data Resource named [" + expected_data_class_1 + "],
							but it's missing from your EntityConfig array!"
					)

	return warnings


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
