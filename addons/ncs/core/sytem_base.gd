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

## VIRTUAL HOOK: Overridden by the user to establish filters on startup
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


# ==============================================================================
# 🗲 CRASH-PROOF DEFERRED BATCH LOOPS
# ==============================================================================

## Automated engine processing frame loop
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	# Duck-typing check: only run if the user implemented this specific function
	if has_method("ncs_process") and not _entities.is_empty():
		# Take a safe, current-frame snapshot copy to prevent mid-frame mutation crashes
		var entities = _entities.duplicate()
		# Invoke the game system execution path with direct references!
		call("ncs_process", entities, _flat_data_pools, delta)

## Automated engine physics processing frame loop
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	if has_method("ncs_physics_process") and not _entities.is_empty():
		var entities = _entities.duplicate()
		call("ncs_physics_process", entities, _flat_data_pools, delta)

func ncs_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	pass

func ncs_physics_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	pass

# ==============================================================================
# 🎯 HIGH-SPEED INCREMENTAL WORKFLOW (O(1) SPAWNING PROTECTION)
# ==============================================================================

## Evaluates exactly ONE newly spawned EntityConfig node
func _handle_incremental_arrival(config_node: EntityConfig) -> void:
	if not is_instance_valid(config_node): return
	var parent_body = config_node.get_parent()
	if not is_instance_valid(parent_body): return
	
	# Fast-extract component scripts list for just this single node branch
	var alive_components: Array[Script] = []
	for child in parent_body.get_children():
		if child.get_script(): alive_components.append(child.get_script())
		if child is NCSComponentsHub or child.name == "Components":
			for sub_child in child.get_children():
				if sub_child.get_script(): alive_components.append(sub_child.get_script())
					
	# Run query match checks
	var is_match = true
	for required_script in _all_filters:
		if not alive_components.has(required_script): is_match = false; break
	if not is_match: return
	
	for forbidden_script in _not_filters:
		if alive_components.has(forbidden_script): is_match = false; break
	if not is_match: return
	
	# 🗲 Append elements to the end of the flat pools in parallel alignment
	if not _entities.has(parent_body):
		# Setup an editor convenience shortcut handle directly onto the game object node!
		parent_body.set(&"config", config_node)
		
		_entities.append(parent_body)
		config_pool.append(config_node)
		
		for pool_idx in _data_targets.size():
			var target_script = _data_targets[pool_idx]
			var data_block = _find_data_by_script(config_node, target_script)
			_flat_data_pools[pool_idx].append(data_block)


## Drops exactly ONE despawning entity instantly out of alignment rows
func _handle_incremental_departure(config_node: EntityConfig) -> void:
	var idx = config_pool.find(config_node)
	if idx != -1:
		_entities.remove_at(idx)
		config_pool.remove_at(idx)
		for pool_idx in _flat_data_pools.size():
			_flat_data_pools[pool_idx].remove_at(idx)


# ==============================================================================
# 🛠️ FULL FACTOR OVERHAUL FLUSH
# ==============================================================================

func _update_query_filter() -> void:
	var matching_bodies: Array[Node] = []
	var matching_configs: Array[EntityConfig] = []
	
	var new_flat_pools: Array[Array] = []
	for t in _data_targets.size():
		new_flat_pools.append([])
	
	for config_node in NCS.active_entities:
		if not is_instance_valid(config_node): continue
		var parent_body = config_node.get_parent()
		if not is_instance_valid(parent_body): continue
		
		var alive_components: Array[Script] = []
		for child in parent_body.get_children():
			if child.get_script(): alive_components.append(child.get_script())
			if child is NCSComponentsHub or child.name == "Components":
				for sub_child in child.get_children():
					if sub_child.get_script(): alive_components.append(sub_child.get_script())
		
		var is_match = true
		for required_script in _all_filters:
			if not alive_components.has(required_script): is_match = false; break
		if not is_match: continue
		
		for forbidden_script in _not_filters:
			if alive_components.has(forbidden_script): is_match = false; break
		if not is_match: continue
				
		if is_match:
			# Bind the custom configuration variable property shortcut right on the node target!
			parent_body.set(&"config", config_node)
			
			matching_bodies.append(parent_body)
			matching_configs.append(config_node)
			
			for pool_idx in _data_targets.size():
				var target_script = _data_targets[pool_idx]
				var data_block = _find_data_by_script(config_node, target_script)
				new_flat_pools[pool_idx].append(data_block)
			
	_entities = matching_bodies
	config_pool = matching_configs
	_flat_data_pools = new_flat_pools


func _find_data_by_script(ent: EntityConfig, target_script: Script) -> NCSDataBase:
	if not ent.runtime_config or not target_script: return null
	var data_array = ent.runtime_config.get("data_sets")
	if data_array is Array:
		for res in data_array:
			if is_instance_valid(res) and res.get_script() == target_script:
				return res as NCSDataBase
	return null
