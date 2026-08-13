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
			child.ent = config_node

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

	var active_resource_classes: Array[String] = []
	if editor_config.base_config:
		var raw_data_sets = editor_config.base_config.get("data_sets")
		if raw_data_sets is Array:
			# Fetch Godot's global script registry list to translate file paths to clean Class Names
			var global_classes = ProjectSettings.get_global_class_list()
			
			for res in raw_data_sets:
				if is_instance_valid(res) and res.get_script():
					var res_script_path = res.get_script().resource_path
					
					# Look up this file path inside Godot's global script database
					for class_info in global_classes:
						if class_info.path == res_script_path:
							active_resource_classes.append(class_info.class)
							break

	# Loop through all immediate children to evaluate checks
	for child in get_children():
		# Direct Inspector property checking
		if "require_data" in child and child.get("require_data") == true:
			
			# If a node is named C_EnemyAI, it explicitly demands a class_name named D_EnemyAI
			var expected_class_target = child.name.replace("C_", "D_")
			
			# Verify if targeted class_name string is currently present inside our loaded data list tracker
			if not active_resource_classes.has(expected_class_target):
				warnings.append("NCS : Component [" + child.name + "] requires a Data Resource with class_name [" + expected_class_target + "] but it's missing from EntityConfig data resource array")

	return warnings


func _find_config_node(start_node: Node) -> EntityConfig:
	if start_node == null: return null
	if start_node is EntityConfig: return start_node
	for child in start_node.get_children():
		if child is EntityConfig: return child
	return _find_config_node(start_node.get_parent())
