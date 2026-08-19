## Base class for all NCS systems. Extend this, override setup_query() to declare filters,
## then override ncs_process / ncs_physics_process to run per-frame logic on matched entities.
# Quick setup:
#   func setup_query() -> void:
#       with_all([C_Movement]).with_not([C_Dead])
#       iterate_data([D_Movement])
#
#   func ncs_physics_process(entities, data_pools, delta):
#       for i in entities.size():
#           var move: D_Movement = data_pools[0][i]
#           entities[i].velocity = move.direction * move.speed
#           entities[i].move_and_slide()
class_name NCSSystemBase
extends NCSBase

var _entities: Array[Node] = []
var config_pool: Array[EntityConfig] = []
var _flat_data_pools: Array[Array] = []

var _all_filters: Array[Script] = []
var _not_filters: Array[Script] = []
var _data_targets: Array[Script] = []


func _ready() -> void:
	setup_query()
	_update_query_filter()


## Override to declare query filters and data pre-fetch targets. Called once on _ready.
func setup_query() -> void:
	pass


## Entity must have ALL listed component types to match this system.
## Returns self for chaining: with_all([C_Move]).with_not([C_Dead])
func with_all(comp_names: Array[Script]) -> NCSSystemBase:
	_all_filters = comp_names
	return self


## Entity must have NONE of the listed component types to match.
func with_not(comp_names: Array[Script]) -> NCSSystemBase:
	_not_filters = comp_names
	return self


## Declares data types to pre-fetch into data_pools. Order determines index in ncs_process.
## Usage: iterate_data([D_Movement, D_Health]) -> data_pools[0] = D_Movement, [1] = D_Health
func iterate_data(data_classes: Array[Script]) -> NCSSystemBase:
	_data_targets = data_classes
	return self


func _process(delta: float) -> void:
	if not _entities.is_empty():
		ncs_process(_entities, _flat_data_pools, delta)


func _physics_process(delta: float) -> void:
	if not _entities.is_empty():
		ncs_physics_process(_entities, _flat_data_pools, delta)


## Override for render-tick logic (visuals, UI, camera sync).
## entities[i] and data_pools[n][i] are always index-aligned.
func ncs_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	pass


## Override for physics-tick logic (movement, collision, velocity).
## Runs at the fixed physics rate, not the render rate.
func ncs_physics_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	pass


## Returns true if the entity passes all filters and is active in the scene tree.
func _matches_query(config_node: Object) -> bool:
	if not is_instance_valid(config_node) or not (config_node is EntityConfig):
		return false

	var cfg = config_node as EntityConfig
	if not cfg.is_inside_tree():
		return false

	var parent_body = cfg.get_parent()
	if not is_instance_valid(parent_body) or parent_body.process_mode == Node.PROCESS_MODE_DISABLED:
		return false

	for req_script in _all_filters:
		if not cfg.has_comp(req_script):
			return false

	for not_script in _not_filters:
		if cfg.has_comp(not_script):
			return false

	return true


## Re-evaluates one entity after its components or data changed. Called by NCS deferred remap.
## Handles: newly matches (append), already matched (refresh data), no longer matches (remove).
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
			parent_body.set(&"config", config_node)
			_entities.append(parent_body)
			config_pool.append(config_node as EntityConfig)
			for pool_idx in _data_targets.size():
				_flat_data_pools[pool_idx].append((config_node as EntityConfig).get_data(_data_targets[pool_idx]))
		else:
			for pool_idx in _data_targets.size():
				_flat_data_pools[pool_idx][idx] = (config_node as EntityConfig).get_data(_data_targets[pool_idx])
	else:
		if idx != -1:
			_entities.remove_at(idx)
			config_pool.remove_at(idx)
			for pool_idx in _flat_data_pools.size():
				_flat_data_pools[pool_idx].remove_at(idx)


## Append for a freshly spawned entity. Called by NCS.register_entity().
func _handle_incremental_arrival(config_node: Object) -> void:
	if not is_instance_valid(config_node) or not (config_node is EntityConfig):
		return

	var parent_body = config_node.get_parent()
	if not is_instance_valid(parent_body):
		return

	if _matches_query(config_node):
		if config_pool.find(config_node as EntityConfig) == -1:
			parent_body.set(&"config", config_node)
			_entities.append(parent_body)
			config_pool.append(config_node as EntityConfig)

			for pool_idx in _data_targets.size():
				_flat_data_pools[pool_idx].append((config_node as EntityConfig).get_data(_data_targets[pool_idx]))


## Removal for a departing entity. Called by NCS.unregister_entity().
func _handle_incremental_departure(config_node: Object) -> void:
	var idx = config_pool.find(config_node)
	if idx != -1:
		_entities.remove_at(idx)
		config_pool.remove_at(idx)

		for pool_idx in _flat_data_pools.size():
			_flat_data_pools[pool_idx].remove_at(idx)


## Full re-query sweep — rebuilds all parallel arrays from NCS.active_entities.
## Called on system registration and after batch operations.
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
				new_flat_pools[pool_idx].append(config_node.get_data(_data_targets[pool_idx]))

	_entities = matching_bodies
	config_pool = matching_configs
	_flat_data_pools = new_flat_pools


## Triggers a single-entity re-evaluation when internal system state changes.
func signal_query_changed() -> void:
	NCS.update_single_entity(
		NCS.active_entities[0] if not NCS.active_entities.is_empty() else null
	)


## One-off data fetch outside the main loop. Prefer data_pools[n][i] inside ncs_process.
func _find_data_by_script(ent: EntityConfig, target_script: Script) -> NCSDataBase:
	return ent.get_data(target_script)
