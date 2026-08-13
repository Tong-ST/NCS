class_name NCSSystemBase
extends NCSBase

# ACCESS: filtered entity collection array
var entities: Array[EntityConfig] = []

# Internal query arrays tracking what this system cares about
var _all_filters: Array[String] = []
var _not_filters: Array[String] = []

func _ready() -> void:
	# Virtual setup hook where the user overrides and defines their query
	setup_query()
	_update_query_filter()

## VIRTUAL HOOK: Overridden by the user to establish filters on startup
func setup_query() -> void:
	pass

## Define components that MUST be present on the entity node tree
func with_all(comp_names: Array[String]) -> NCSSystemBase:
	_all_filters = comp_names
	return self

## Define components that MUST NOT be present
func with_not(comp_names: Array[String]) -> NCSSystemBase:
	_not_filters = comp_names
	return self

## Returns true if the action was successfully triggered, false if it's a scriptless tag.
func send_signal(entity: EntityConfig, component_name: String, method_name: String, args: Array = []) -> bool:
	var comp = entity.get_comp(component_name)
	
	# If the component doesn't exist, or is just a scriptless lazy tag.
	if not is_instance_valid(comp) or not comp.get_script():
		return false
		
	# Verify the component actually has the custom visual function written down
	if comp.has_method(method_name):
		comp.callv(method_name, args)
		return true
		
	return false

## Internal evaluation method called automatically whenever entities spawn or leave
func _update_query_filter() -> void:
	var matching_entities: Array[EntityConfig] = []
	
	for ent in NCS.active_entities:
		if not is_instance_valid(ent): 
			continue
			
		var parent_body = ent.get_parent()
		if not is_instance_valid(parent_body): 
			continue
			
		var is_match = true
		
		# 1. Verify all required component constraints exist
		for required_comp in _all_filters:
			if not _check_entity_has_component(parent_body, required_comp):
				is_match = false
				break
				
		if not is_match: 
			continue
			
		# 2. Verify no forbidden component constraints exist
		for forbidden_comp in _not_filters:
			if _check_entity_has_component(parent_body, forbidden_comp):
				is_match = false
				break
				
		if is_match:
			matching_entities.append(ent)
			
	# Assign the verified filters to your working array
	entities = matching_entities


## Comprehensive inspector that handles string names, class names, and folder hierarchies
func _check_entity_has_component(parent: Node, target_identifier: String) -> bool:
	# Check the immediate root level of the character body scene
	if parent.has_node(target_identifier):
		return true
		
	# Crawl through all direct children and sub-folders (like the Components Hub)
	for child in parent.get_children():
		# Direct structural name check
		if child.name == target_identifier:
			return true
			
		# Script Custom Class Name Check (e.g. checks if script is class_name C_Input)
		if child.get_script() and child.get_script().get_global_name() == target_identifier:
			return true
			
		# Deep search optimization for child elements nested inside your NCSComponentsHub node
		if child is NCSComponentsHub or child.name == "Components":
			for sub_child in child.get_children():
				if sub_child.name == target_identifier:
					return true
				if sub_child.get_script() and sub_child.get_script().get_global_name() == target_identifier:
					return true
					
	return false
