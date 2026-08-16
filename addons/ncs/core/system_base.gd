class_name NCSSystemBase
extends NCSBase

var _entities: Array[Node] = []

# Mirror matrix tracking configuration pointers side-by-side
var config_pool: Array[EntityConfig] = []

# A clean, pre-sorted multi-channel data pool container
var _flat_data_pools: Array[Array] = []

# Internal query structures tracking what this system cares about
var _all_filters: Array[Script] = []
var _not_filters: Array[Script] = []
var _data_targets: Array[Script] = []


func _ready() -> void:
	# Setup virtual query template constraints on initialization
	setup_query()
	_update_query_filter()


## Overridden by the user to establish filters on startup
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


## Automated engine processing frame loop (zero allocations per frame)
func _process(delta: float) -> void:
	if not _entities.is_empty():
		var entities = _entities.duplicate()
		ncs_process(entities, _flat_data_pools, delta)


## Automated engine physics processing frame loop (zero allocations per frame)
func _physics_process(delta: float) -> void:
	if not _entities.is_empty():
		var entities = _entities.duplicate()
		ncs_physics_process(entities, _flat_data_pools, delta)


func ncs_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	pass


func ncs_physics_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	pass


## Fast O(1) evaluation if an EntityConfig matches this system's query filters
func _matches_query(config_node: Object) -> bool:
	if not is_instance_valid(config_node) or not (config_node is EntityConfig):
		return false
		
	for req_script in _all_filters:
		if not config_node.has_comp(req_script):
			return false

	for not_script in _not_filters:
		if config_node.has_comp(not_script):
			return false

	return true


## Evaluates single entity state mutation or arrival
func _evaluate_single_entity(config_node: Object) -> void:
	if not is_instance_valid(config_node) or not (config_node is EntityConfig):
		return
	var parent_body = config_node.get_parent()
	if not is_instance_valid(parent_body):
		return

	var idx = config_pool.find(config_node)
	var is_match = _matches_query(config_node)

	if is_match:
		if idx == -1:
			# New match to add
			parent_body.set(&"config", config_node)
			_entities.append(parent_body)
			config_pool.append(config_node as EntityConfig)
			for pool_idx in _data_targets.size():
				var target_script = _data_targets[pool_idx]
				var data_block = (config_node as EntityConfig).get_data(target_script)
				_flat_data_pools[pool_idx].append(data_block)
		else:
			# Existing match, update data pool entries
			for pool_idx in _data_targets.size():
				var target_script = _data_targets[pool_idx]
				var data_block = (config_node as EntityConfig).get_data(target_script)
				_flat_data_pools[pool_idx][idx] = data_block
	else:
		if idx != -1:
			# No longer matches, remove
			_entities.remove_at(idx)
			config_pool.remove_at(idx)
			for pool_idx in _flat_data_pools.size():
				_flat_data_pools[pool_idx].remove_at(idx)


## Evaluates exactly ONE newly spawned EntityConfig node
func _handle_incremental_arrival(config_node: Object) -> void:
	_evaluate_single_entity(config_node)


## Drops exactly ONE despawning entity instantly out of alignment rows
func _handle_incremental_departure(config_node: Object) -> void:
	var idx = config_pool.find(config_node)
	if idx != -1:
		_entities.remove_at(idx)
		config_pool.remove_at(idx)
		for pool_idx in _flat_data_pools.size():
			_flat_data_pools[pool_idx].remove_at(idx)



func _update_query_filter() -> void:
	var matching_bodies: Array[Node] = []
	var matching_configs: Array[EntityConfig] = []
	
	var new_flat_pools: Array[Array] = []
	for t in _data_targets.size():
		new_flat_pools.append([])
	
	for config_node in NCS.active_entities:
		if not is_instance_valid(config_node):
			continue
		var parent_body = config_node.get_parent()
		if not is_instance_valid(parent_body):
			continue
			
		if _matches_query(config_node):
			parent_body.set(&"config", config_node)
			matching_bodies.append(parent_body)
			matching_configs.append(config_node)
			
			for pool_idx in _data_targets.size():
				var target_script = _data_targets[pool_idx]
				var data_block = config_node.get_data(target_script)
				new_flat_pools[pool_idx].append(data_block)
			
	_entities = matching_bodies
	config_pool = matching_configs
	_flat_data_pools = new_flat_pools


func _find_data_by_script(ent: EntityConfig, target_script: Script) -> NCSDataBase:
	return ent.get_data(target_script)
