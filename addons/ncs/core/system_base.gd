## Base class for all NCS systems. Extend this, override setup_query() to declare filters,
## then override ncs_process / ncs_physics_process to run per-frame logic on matched entities.

# Quick Example:
#   func setup_query() -> void:
#       with_all([CompMovement]).with_not([CompDead])
#       iterate_data([DataMovement])
#
#   func ncs_physics_process(entities, delta):
#       var move_pool = data_pools[0] as Array[DataMovement]
#       for i in entities.size():
#           var move = move_pool[i]
#           entities[i].velocity = move.direction * move.speed
#           entities[i].move_and_slide()
@icon("res://addons/ncs/icons/gears-solid-full.svg")
class_name SystemBase
extends NCSBase

## Array of EntityConfig nodes aligned with entities in this system.
var configs: Array[EntityConfig] = []
var entity_pools: Array[Node] = []
var data_pools: Array[Array] = []
var node_pools: Array[Array] = []

## Compiled list of all scripts (components & data) this system queries.
var interest_scripts: Array[Script] = []

# Internal query filter definitions
var _all_filters: Array[Script] = []
var _any_filters: Array[Script] = []
var _not_filters: Array[Script] = []
var _data_targets: Array[Script] = []
var _node_targets: Array = []
var _required_types: Array[Script] = []

# First query initialized
var _is_query_init: bool = false


# ==============================================================================
# BUILT-IN VIRTUAL METHODS
# ==============================================================================

func _enter_tree() -> void:
	var sys_script = get_script()
	if not sys_script:
		return
	name = sys_script.get_global_name()
	if NCS.has_system(sys_script):
		push_warning("NCS: Duplicate node '%s' detected. Freeing." % name)
		queue_free()
		return

	NCS.register_system(self)
	print("NCS: System Registered -> ", name)


func _exit_tree() -> void:
	NCS.unregister_system(self)
	print("NCS: Unregistered system -> ", name)


func _process(delta: float) -> void:
	if not entity_pools.is_empty():
		NCS.set_updating_state(true)
		ncs_process(entity_pools, delta)
		NCS.set_updating_state(false)


func _physics_process(delta: float) -> void:
	if not entity_pools.is_empty():
		NCS.set_updating_state(true)
		ncs_physics_process(entity_pools, delta)
		NCS.set_updating_state(false)


# ==============================================================================
# VIRTUAL SYSTEM AUTHOR OVERRIDES
# ==============================================================================

## Override for render-tick logic (visuals, UI, camera sync).
func ncs_process(entities: Array[Node], delta: float) -> void:
	pass


## Override for physics-tick logic (movement, collision, velocity).
## Runs at the fixed physics rate, not the render rate.
func ncs_physics_process(entities: Array[Node], delta: float) -> void:
	pass


## Override to declare query filters and data pre-fetch targets. Called once on _ready.
func setup_query() -> void:
	pass


# ==============================================================================
# PUBLIC QUERY BUILDER API (CHAINABLE)
# ==============================================================================

## Entity must have ALL listed component types to match this system.
## Returns self for chaining: with_all([CompMove]).with_not([CompDead])
func with_all(type_scripts: Array[Script]) -> SystemBase:
	_all_filters = type_scripts
	return self


## Entity must have AT LEAST ONE of the listed component types to match this system.
## Returns self for chaining: with_any([CompPoison, CompFreeze]).with_not([CompDead])
func with_any(type_scripts: Array[Script]) -> SystemBase:
	_any_filters = type_scripts
	return self


## Entity must have NONE of the listed component types to match.
func with_not(type_scripts: Array[Script]) -> SystemBase:
	_not_filters = type_scripts
	return self


## Pre-fetches data into data_pools and requires entity to possess all listed data types.
## Usage: iterate_data([DataMovement, DataHealth]) -> data_pools[0] = DataMovement, [1] = DataHealth
func iterate_data(data_classes: Array[Script]) -> SystemBase:
	_data_targets = data_classes
	return self


## Pre-fetches child Nodes (e.g. Sprite2D, AnimationPlayer) into node_pools.
## Usage: fetch_nodes([Sprite2D, AnimationPlayer])
func fetch_nodes(node_classes: Array) -> SystemBase:
	_node_targets = node_classes
	return self


# ==============================================================================
# PRIVATE QUERY EVALUATION & ARRAY SYNCHRONIZATION
# ==============================================================================

## Returns true if the entity passes all filters and has all iterated data blocks.
func _matches_query(config_node: Object) -> bool:
	if not is_instance_valid(config_node) or not (config_node is EntityConfig):
		return false

	var cfg = config_node as EntityConfig
	if not cfg.is_inside_tree():
		return false

	var parent_body = cfg.entity_node
	if not is_instance_valid(parent_body):
		return false

	var types: Dictionary = cfg._type_set

	for not_script in _not_filters:
		if types.has(not_script):
			return false

	for req_script in _required_types:
		if not types.has(req_script):
			return false

	if not _any_filters.is_empty():
		var has_any_match: bool = false
		for any_script in _any_filters:
			if types.has(any_script):
				has_any_match = true
				break
		if not has_any_match:
			return false

	return true


## Compiles all unique scripts this system cares about.
func _compile_interest_scripts() -> void:
	var req_set: Dictionary = {}
	for script in _all_filters:
		if script:
			req_set[script] = true
	for script in _data_targets:
		if script:
			req_set[script] = true
	_required_types.clear()
	_required_types.assign(req_set.keys())

	var unique_set: Dictionary = {}
	for list in [_all_filters, _any_filters, _not_filters, _data_targets]:
		for script in list:
			if script:
				unique_set[script] = true

	interest_scripts.clear()
	interest_scripts.assign(unique_set.keys())


## Guarantees sub-array pools match declared target counts even when empty.
func _ensure_pools_initialized() -> void:
	if data_pools.size() != _data_targets.size():
		data_pools.clear()
		for i in _data_targets.size():
			data_pools.append([])

	if node_pools.size() != _node_targets.size():
		node_pools.clear()
		for i in _node_targets.size():
			node_pools.append([])


## Re-evaluates one entity after its components or data changed. Called by NCS deferred remap.
func _evaluate_single_entity(config_node: EntityConfig, changed_script: Script = null) -> void:
	if not is_instance_valid(config_node) or not (config_node is EntityConfig):
		return

	if changed_script and not interest_scripts.has(changed_script):
		return

	var parent_body = config_node.entity_node
	if not is_instance_valid(parent_body):
		return

	_ensure_pools_initialized()

	var idx = configs.find(config_node)
	var is_match = _matches_query(config_node)

	if is_match:
		if idx == -1:
			entity_pools.append(parent_body)
			configs.append(config_node as EntityConfig)
			for pool_idx in _data_targets.size():
				data_pools[pool_idx].append(
						config_node._data_map.get(_data_targets[pool_idx])
				)
			for pool_idx in _node_targets.size():
				node_pools[pool_idx].append(
						_find_node_in_entity(parent_body, _node_targets[pool_idx])
				)
		else:
			for pool_idx in _data_targets.size():
				data_pools[pool_idx][idx] = (
						config_node._data_map.get(_data_targets[pool_idx])
				)
			for pool_idx in _node_targets.size():
				node_pools[pool_idx][idx] = (
						_find_node_in_entity(parent_body, _node_targets[pool_idx])
				)
	else:
		if idx != -1:
			_remove_entity_at_index(idx)


## Removal for a departing entity. Called by NCS.unregister_entity().
func _handle_incremental_departure(config_node: EntityConfig) -> void:
	var idx = configs.find(config_node)
	if idx != -1:
		_remove_entity_at_index(idx)


func _remove_entity_at_index(idx: int) -> void:
	entity_pools.remove_at(idx)
	configs.remove_at(idx)
	for pool in data_pools:
		pool.remove_at(idx)
	for pool in node_pools:
		pool.remove_at(idx)


## Full re-query sweep — rebuilds all parallel arrays from NCS.active_config.
## Called on system registration and after batch operations.
func _update_query_filter() -> void:
	var start = Time.get_ticks_msec()
	if not _is_query_init:
		setup_query()
		_compile_interest_scripts()
		_is_query_init = true

	var matching_configs: Array[EntityConfig] = []
	var matching_bodies: Array[Node] = []
	var new_data_pools: Array[Array] = []
	var new_node_pools: Array[Array] = []

	for t in _data_targets.size():
		new_data_pools.append([])
	for t in _node_targets.size():
		new_node_pools.append([])

	for config_node in NCS.active_config:
		if not is_instance_valid(config_node):
			continue

		var parent_body = config_node.entity_node
		if not is_instance_valid(parent_body):
			continue

		if _matches_query(config_node):
			matching_bodies.append(parent_body)
			matching_configs.append(config_node)

			for pool_idx in _data_targets.size():
				new_data_pools[pool_idx].append(
						config_node._data_map.get(_data_targets[pool_idx])
				)

			for pool_idx in _node_targets.size():
				new_node_pools[pool_idx].append(
						_find_node_in_entity(parent_body, _node_targets[pool_idx])
				)

	configs = matching_configs
	entity_pools = matching_bodies
	data_pools = new_data_pools
	node_pools = new_node_pools


## Helper: Locates node instance on parent_body
## (first direct child match, then recursive).
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


## Ensures queries are compiled on registration
func _initialize_query_if_needed() -> void:
	if not _is_query_init:
		setup_query()
		_compile_interest_scripts()
		_is_query_init = true


## Resets entity and data pools when unregistered to prevent memory leaks.
func _clear_system_state() -> void:
	entity_pools.clear()
	configs.clear()
	for pool in data_pools:
		pool.clear()
	for pool in node_pools:
		pool.clear()
