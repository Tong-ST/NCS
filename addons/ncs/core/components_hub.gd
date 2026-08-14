@tool
class_name NCSComponentsHub
extends NCSBase

## The physical body this entire folder of components controls.
## Defaults to the scene owner (e.g. CharacterBody2D) if left blank.
@export var owner_node: Node

## Reference to the local configuration data resource node.
var config_node: EntityConfig


func _ready() -> void:
	if Engine.is_editor_hint(): 
		return
		
	if not owner_node:
		owner_node = owner
		
	config_node = _find_config_node(get_parent())
	
	# Pass the owner_node and config_node references down to all children automatically
	for child in get_children():
		if child is NCSComponentBase:
			child.owner_node = owner_node
			child.config = config_node

	if config_node:
		NCS.register_entity(config_node)


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
			
	# Your normal game runtime logic continues safely down here
	if not Engine.is_editor_hint():
		if config_node:
			NCS.unregister_entity(config_node)


func _on_property_edited(what: String) -> void:
	update_configuration_warnings()


func _on_editor_context_changed() -> void:
	update_configuration_warnings()


## Instantly catch structural node changes like drag-and-drops
func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		update_configuration_warnings()


## Native editor validation loop that runs on our slow 0.5-second clock pulse
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if not Engine.is_editor_hint(): 
		return warnings

	var editor_config = _find_config_node(get_parent())
	if not editor_config:
		return warnings

	# Build a fast lookup map of active resource classes currently in the array
	var available_data_classes: Array[String] = []
	if editor_config.base_config:
		var raw_data_sets = editor_config.base_config.get("data_sets")
		if raw_data_sets is Array:
			var global_classes = ProjectSettings.get_global_class_list()
			for res in raw_data_sets:
				if is_instance_valid(res) and res.get_script():
					var res_script_path = res.get_script().resource_path
					for class_info in global_classes:
						if class_info.path == res_script_path:
							available_data_classes.append(class_info.class)
							break

	# Loop through children and validate component scripts
	for child in get_children():
		# Direct Inspector property verification
		if "require_data" in child and child.get("require_data") == true:
			var script = child.get_script()
			
			if not script:
				warnings.append("NCS Layout Error: Node [" + child.name + "] has 'Require Data' enabled but does not have a script attached! All components require a type class script.")
				continue
				
			# Converts component "C_Movement" -> expects resource "D_Movement" or "MovementData"
			var script_class_name = script.get_global_name()
			if not script_class_name.is_empty():
				var base_identity = script_class_name.replace("Component", "")
				var expected_data_class_1 = base_identity.replace("C_", "D_")

				if not available_data_classes.has(expected_data_class_1):
					warnings.append("NCS Configuration Error: Component class [" + script_class_name + "] explicitly requires a Data Resource named [" + expected_data_class_1 + "], but it's missing from your EntityConfig array!")

	return warnings


func _find_config_node(start_node: Node) -> EntityConfig:
	if start_node == null: return null
	if start_node is EntityConfig: return start_node
	for child in start_node.get_children():
		if child is EntityConfig: return child
	return _find_config_node(start_node.get_parent())
