class_name NCSSystemBase
extends NCSBase

# ACCESS: filtered entity collection array
var entities: Array[EntityConfig] = []

# 🎯 THE FLATTENED MEMORY MATRIX:
# An array of clean, pre-sorted flat arrays matching your iterate targets.
# _flat_data_pools[0] = Array of ALL D_Movement resources (ordered perfectly)
# _flat_data_pools[1] = Array of ALL D_Input resources (ordered perfectly)
var _flat_data_pools: Array[Array] = []
var _body_pool: Array[Node] = []

# Internal query arrays tracking what this system cares about
var _all_filters: Array[Script] = []
var _not_filters: Array[Script] = []
var _data_targets: Array[Script] = []

func _ready() -> void:
	setup_query()
	_update_query_filter()

func setup_query() -> void:
	pass

func with_all(comp_names: Array[Script]) -> NCSSystemBase:
	_all_filters = comp_names
	return self

func with_not(comp_names: Array[Script]) -> NCSSystemBase:
	_not_filters = comp_names
	return self

func iterate_data(data_classes: Array[Script]) -> NCSSystemBase:
	_data_targets = data_classes
	return self

# 🎯 HIGH-SPEED FLAT GETTER:
# Pulls a pre-sorted flat array pool directly. No internal index parsing or offsets!
func get_data_pool(pool_index: int) -> Array:
	return _flat_data_pools[pool_index]

func get_body_pool() -> Array[Node]:
	return _body_pool

func send_signal(entity: EntityConfig, component_name: Script, method_name: String, args: Array = []) -> bool:
	var comp = entity.get_comp(component_name)
	if not is_instance_valid(comp) or not comp.get_script():
		return false
	if comp.has_method(method_name):
		comp.callv(method_name, args)
		return true
	return false

## Internal evaluation method - ONLY runs when entities spawn or change state!
func _update_query_filter() -> void:
	var matching_entities: Array[EntityConfig] = []
	var new_body_pool: Array[Node] = []
	
	var new_flat_pools: Array[Array] = []
	for t in _data_targets.size():
		new_flat_pools.append([])
	
	for ent in NCS.active_entities:
		if not is_instance_valid(ent): continue
		var parent_body = ent.get_parent() as Node
		if not is_instance_valid(parent_body): continue
		
		# Cache component scripts to bypass nested lookups
		var alive_components: Array[Script] = []
		for child in parent_body.get_children():
			if child.get_script():
				alive_components.append(child.get_script())
			if child is NCSComponentsHub or child.name == "Components":
				for sub_child in child.get_children():
					if sub_child.get_script():
						alive_components.append(sub_child.get_script())
		
		var is_match = true
		for required_script in _all_filters:
			if not alive_components.has(required_script):
				is_match = false
				break
		if not is_match: continue
		
		for forbidden_script in _not_filters:
			if alive_components.has(forbidden_script):
				is_match = false
				break
				
		if is_match:
			matching_entities.append(ent)
			new_body_pool.append(parent_body) # 🎯 GLUE THE BODY POINTER HERE
			
			# Pre-sort into flat data channels on spawn
			for pool_idx in _data_targets.size():
				var target_script = _data_targets[pool_idx]
				var data_block = _find_data_by_script(ent, target_script)
				new_flat_pools[pool_idx].append(data_block)
			
	entities = matching_entities
	_body_pool = new_body_pool
	_flat_data_pools = new_flat_pools


func _find_data_by_script(ent: EntityConfig, target_script: Script) -> NCSDataBase:
	if not ent.runtime_config or not target_script: return null
	var data_array = ent.runtime_config.get("data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script() == target_script:
				return res as NCSDataBase
	return null
