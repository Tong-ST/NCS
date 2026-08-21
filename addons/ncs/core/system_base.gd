## Base class for all NCS systems. Extend this, override setup_query() to declare filters,
## then override ncs_process / ncs_physics_process to run per-frame logic on matched entities.
# Quick setup:
#   func setup_query() -> void:
#       with_all([CompMovement]).with_not([CompDead])
#       iterate_data([DataMovement])
#
#   func ncs_physics_process(entities, data_pools, delta):
#       for i in entities.size():
#           var move = data_pools[0][i] as DataMovement
#           entities[i].velocity = move.direction * move.speed
#           entities[i].move_and_slide()
class_name NCSSystemBase
extends NCSBase

var config_pool: Array[EntityConfig] = []
var interest_scripts: Array[Script] = []

var _entities: Array[Node] = []
var _flat_data_pools: Array[Array] = []
var _node_targets: Array = []
var _flat_node_pools: Array[Array] = []

var _all_filters: Array[Script] = []
var _any_filters: Array[Script] = []
var _not_filters: Array[Script] = []
var _data_targets: Array[Script] = []


func _ready() -> void:
	setup_query()
	_compile_interest_scripts()
	_update_query_filter.call_deferred()


func _process(delta: float) -> void:
	if not _entities.is_empty():
		ncs_process(_entities, _flat_data_pools, _flat_node_pools, delta)


func _physics_process(delta: float) -> void:
	if not _entities.is_empty():
		ncs_physics_process(_entities, _flat_data_pools, _flat_node_pools, delta)


## Override for render-tick logic (visuals, UI, camera sync).
## entities[i] and data_pools[n][i] are always index-aligned.
func ncs_process(entities: Array[Node], data_pools: Array, node_pools: Array, delta: float) -> void:
	pass


## Override for physics-tick logic (movement, collision, velocity).
## Runs at the fixed physics rate, not the render rate.
func ncs_physics_process(entities: Array[Node], data_pools: Array, node_pools: Array, delta: float) -> void:
	pass


## Override to declare query filters and data pre-fetch targets. Called once on _ready.
func setup_query() -> void:
	pass


## Entity must have ALL listed component types to match this system.
## Returns self for chaining: with_all([CompMove]).with_not([CompDead])
func with_all(type_scripts: Array[Script]) -> NCSSystemBase:
	_all_filters = type_scripts
	return self


## Entity must have any listed component types to match this system.
## Returns self for chaining: with_any([CompPoison, CompFreeze]).with_not([CompDead])
func with_any(type_scripts: Array[Script]) -> NCSSystemBase:
	_any_filters = type_scripts
	return self


## Entity must have NONE of the listed component types to match.
func with_not(type_scripts: Array[Script]) -> NCSSystemBase:
	_not_filters = type_scripts
	return self


## Pre-fetch data into data_pools. Entity must have all data required to exist in system.
## Usage: iterate_data([DataMovement, DataHealth]) -> data_pools[0] = DataMovement, [1] = DataHealth
func iterate_data(data_classes: Array[Script]) -> NCSSystemBase:
	_data_targets = data_classes
	return self


## Pre-fetch Nodes (e.g., Sprite2D, AnimationPlayer) into node_pools.
## Usage: fetch_nodes([Sprite2D, AnimationPlayer])
func fetch_nodes(node_classes: Array) -> NCSSystemBase:
	_node_targets = node_classes
	return self


## Returns true if the entity passes all filters and has all iterated data blocks.
func _matches_query(config_node: Object) -> bool:
	if not is_instance_valid(config_node) or not (config_node is EntityConfig):
		return false

	var cfg = config_node as EntityConfig
	if not cfg.is_inside_tree():
		return false

	var parent_body = cfg.get_parent()
	if not is_instance_valid(parent_body):
		return false

	# 1. NOT Filter (Must not have component OR data)
	for not_script in _not_filters:
		if _entity_has_type(cfg, not_script):
			return false

	# 2. ALL Filter (Must have component OR data)
	for req_script in _all_filters:
		if not _entity_has_type(cfg, req_script):
			return false

	if not _any_filters.is_empty():
		var has_any_match: bool = false
		for any_script in _any_filters:
			if _entity_has_type(cfg, any_script):
				has_any_match = true
				break
		if not has_any_match:
			return false

	for data_script in _data_targets:
		if not _entity_has_type(cfg, data_script):
			return false

	return true


## Helper: Checks if entity possesses either a Component Node or a Data Resource.
func _entity_has_type(cfg: EntityConfig, type_script: Script) -> bool:
	if not type_script: return false
	return cfg.has_comp(type_script) or cfg.has_data(type_script)


## Compiles all scripts this system cares about.
func _compile_interest_scripts() -> void:
	var unique_set: Dictionary = {}
	for list in [_all_filters, _any_filters, _not_filters, _data_targets]:
		for script in list:
			if script: unique_set[script] = true

	interest_scripts.clear()
	interest_scripts.assign(unique_set.keys())


## Re-evaluates one entity after its components or data changed. Called by NCS deferred remap.
## Handles: newly matches (append), already matched (refresh data), no longer matches (remove).
func _evaluate_single_entity(config_node: Object, changed_script: Script = null) -> void:
	if not is_instance_valid(config_node) or not (config_node is EntityConfig):
		return

	if changed_script and not interest_scripts.has(changed_script):
		return

	var parent_body = config_node.get_parent()
	if not is_instance_valid(parent_body):
		return

	var idx = config_pool.find(config_node)
	var is_match = _matches_query(config_node)
	if is_match:
		if idx == -1:
			parent_body.set(&"config", config_node)
			_entities.append(parent_body)
			config_pool.append(config_node as EntityConfig)
			for pool_idx in _data_targets.size():
				_flat_data_pools[pool_idx].append(
						(config_node as EntityConfig)
						.get_data(_data_targets[pool_idx])
				)
			for pool_idx in _node_targets.size():
				_flat_node_pools[pool_idx].append(
						_find_node_in_entity(parent_body, _node_targets[pool_idx])
				)
		else:
			for pool_idx in _data_targets.size():
				_flat_data_pools[pool_idx][idx] = (
						(config_node as EntityConfig)
						.get_data(_data_targets[pool_idx])
				)
			for pool_idx in _node_targets.size():
				_flat_node_pools[pool_idx][idx] = (
						_find_node_in_entity(parent_body, _node_targets[pool_idx])
				)
	else:
		if idx != -1:
			_entities.remove_at(idx)
			config_pool.remove_at(idx)
			for pool_idx in _flat_data_pools.size():
				_flat_data_pools[pool_idx].remove_at(idx)
			for pool_idx in _flat_node_pools.size():
				_flat_node_pools[pool_idx].remove_at(idx)


## Removal for a departing entity. Called by NCS.unregister_entity().
func _handle_incremental_departure(config_node: Object) -> void:
	var idx = config_pool.find(config_node)
	if idx != -1:
		_entities.remove_at(idx)
		config_pool.remove_at(idx)
		for pool_idx in _flat_data_pools.size():
			_flat_data_pools[pool_idx].remove_at(idx)
		for pool_idx in _flat_node_pools.size():
			_flat_node_pools[pool_idx].remove_at(idx)


## Full re-query sweep — rebuilds all parallel arrays from NCS.active_entities.
## Called on system registration and after batch operations.
func _update_query_filter() -> void:
	setup_query()
	_compile_interest_scripts()

	var matching_bodies: Array[Node] = []
	var matching_configs: Array[EntityConfig] = []
	var new_flat_pools: Array[Array] = []
	var new_node_pools: Array[Array] = []

	for t in _data_targets.size():
		new_flat_pools.append([])
	for t in _node_targets.size():
		new_node_pools.append([])

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
				new_flat_pools[pool_idx].append(config_node.get_data(_data_targets[pool_idx]))

			for pool_idx in _node_targets.size():
				new_node_pools[pool_idx].append(_find_node_in_entity(parent_body, _node_targets[pool_idx]))

	_entities = matching_bodies
	config_pool = matching_configs
	_flat_data_pools = new_flat_pools
	_flat_node_pools = new_node_pools


## Triggers a single-entity re-evaluation when internal system state changes.
func signal_query_changed() -> void:
	NCS.update_single_entity(
		NCS.active_entities[0] if not NCS.active_entities.is_empty() else null
	)


## One-off data fetch outside the main loop.
## Prefer data fetching inside ncs_process e.g. var health_pool = data_pools[0] as Array[DataHealth]
func _find_data_by_script(ent: EntityConfig, target_script: Script) -> NCSDataBase:
	return ent.get_data(target_script)


## Helper: Locates node instance on parent_body (first direct child match, then recursive)
func _find_node_in_entity(parent_body: Node, target_type: Variant) -> Node:
	if not is_instance_valid(parent_body):
		return null

	for child in parent_body.get_children():
		if is_instance_of(child, target_type):
			return child

	for child in parent_body.find_children("*", "", true, false):
		if is_instance_of(child, target_type):
			return child

	return null
