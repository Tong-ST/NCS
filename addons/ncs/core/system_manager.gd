## Global singleton (autoload as "NCS").
## Manages the active entity registry, system queries, and frame flush pipeline.
@icon("res://addons/ncs/icons/gear-solid-full.svg")
extends Node

## Auto-detection threshold: if queued changes in a frame >= this threshold, batch re-query is used.
## Otherwise, incremental single-entity evaluation is used.
const MASS_UPDATE_THRESHOLD: int = 50

## Master list of every active EntityConfig in the world.
var active_config: Array[EntityConfig] = []

# Internal system registries
var _systems: Dictionary = {}
var _systems_list: Array[SystemBase] = []
var _active_config_map: Dictionary = {}
var _script_to_systems: Dictionary = {}

# Internal command buffer & flush queues
var _command_queue: Array[Callable] = []
var _dirty_entities: Dictionary = {}
var _pending_registrations: Array[EntityConfig] = []
var _pending_registrations_set: Dictionary = {}
var _pending_unregistrations: Array[Variant] = []
var _pending_unregistrations_set: Dictionary = {}

# Typed spawn/despawn queue
var _spawn_queue: Array[Dictionary] = []
var _despawn_queue: Array[Node] = []
var _despawn_set: Dictionary = {}

# Typed callable queue
var _deferred_callables: Array[Callable] = []
var _deferred_args: Array[Variant] = []

# Engine synchronization flags
var _is_updating: bool = false
var _flush_scheduled: bool = false


# ==============================================================================
# BUILT-IN PROCESS RELAYS
# ==============================================================================

func _process(_delta: float) -> void:
	if _flush_scheduled:
		flush()


func _physics_process(_delta: float) -> void:
	if _flush_scheduled:
		flush()


# ==============================================================================
# PUBLIC SPAWN & DESPAWN API
# ==============================================================================

## Safely instantiates and adds a 2D/3D entity to the scene tree via zero-allocation typed queue.
## Usage: NCS.spawn(enemy_scene, self, player.global_position)
func spawn(
		scene: PackedScene,
		parent: Node,
		position_or_transform: Variant = null,
		setup_callback: Callable = Callable()
) -> void:
	if not scene or not is_instance_valid(parent):
		return

	_spawn_queue.append({
		"scene": scene,
		"parent": parent,
		"position": position_or_transform,
		"callback": setup_callback
	})
	_schedule_flush()


## Queues an entity or node for despawn at next flush.
func despawn(node_or_config: Variant) -> void:
	if not is_instance_valid(node_or_config):
		return

	var config: EntityConfig = _extract_config(node_or_config)
	if is_instance_valid(config):
		config._is_registered = false

	if node_or_config is Node:
		if not _despawn_set.has(node_or_config):
			_despawn_set[node_or_config] = true
			_despawn_queue.append(node_or_config as Node)
			_schedule_flush()


# ==============================================================================
# PUBLIC COMMAND & METHOD QUEUEING API
# ==============================================================================

## Enqueues a structural command to execute safely during flush.
func push_command(command: Callable) -> void:
	if not command.is_valid():
		return
	_command_queue.append(command)
	_schedule_flush()


## Enqueues a pre-bound Callable for deferred execution without allocating closures.
func push_callable(callable: Callable, arg_or_args: Variant = null) -> void:
	if not callable.is_valid():
		return
	_deferred_callables.append(callable)
	_deferred_args.append(arg_or_args)
	_schedule_flush()


## Enqueues a component method call without allocating closures.
func push_method_call(config: Variant, comp_script: Script, method_name: StringName, args: Variant = null) -> void:
	if not is_instance_valid(config) or not (config is EntityConfig):
		return
	var callable = (config as EntityConfig).get_callable(comp_script, method_name)
	if callable.is_valid():
		push_callable(callable, args)


## Marks an entity as dirty for re-evaluation during flush.
func mark_dirty(entity: Variant, changed_script: Script = null) -> void:
	if not is_instance_valid(entity):
		return
	if not _dirty_entities.has(entity):
		_dirty_entities[entity] = []
	if changed_script and not _dirty_entities[entity].has(changed_script):
		_dirty_entities[entity].append(changed_script)
	_schedule_flush()


# ==============================================================================
# PUBLIC ENTITY & SYSTEM REGISTRATION API
# ==============================================================================

## Registers an entity for evaluation during flush.
func register_entity(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig):
		return
	if not _pending_registrations_set.has(entity):
		_pending_registrations_set[entity] = true
		_pending_registrations.append(entity as EntityConfig)
		_schedule_flush()


## Unregisters an entity during flush.
func unregister_entity(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig):
		return
	var cfg = entity as EntityConfig
	if not cfg._is_registered:
		return
	if not _pending_unregistrations_set.has(cfg):
		_pending_unregistrations_set[cfg] = true
		_pending_unregistrations.append(cfg)
		_schedule_flush()


## Registers a system instance into the world.
func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance
	_systems_list.append(system_instance)
	if system_instance.has_method(&"_update_query_filter"):
		system_instance._update_query_filter()

	var scripts_to_index: Array = []
	if "interest_scripts" in system_instance:
		scripts_to_index.append_array(system_instance.interest_scripts)

	for script in scripts_to_index:
		if not _script_to_systems.has(script):
			_script_to_systems[script] = []

		var sys_list: Array = _script_to_systems[script]
		if not sys_list.has(system_instance):
			sys_list.append(system_instance)


## Unregisters a system from the world.
func unregister_system(system_name: String) -> void:
	var system_instance = _systems.get(system_name)
	if system_instance:
		_systems_list.erase(system_instance)
		for script in _script_to_systems.keys():
			var sys_list: Array = _script_to_systems[script]
			sys_list.erase(system_instance)
			if sys_list.is_empty():
				_script_to_systems.erase(script)

	_systems.erase(system_name)


## Returns a live system instance by name, or null.
func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)


# ==============================================================================
# FLUSH PIPELINE & STATE MANAGEMENT
# ==============================================================================

func set_updating_state(state: bool) -> void:
	_is_updating = state


## Flushes queued operations. Auto-detects whether to run Batch Re-query (>= threshold)
## or Incremental Single-Entity evaluations (< threshold).
## Selectively re-evaluates ONLY systems affected by the modified scripts.
func flush() -> void:
	_flush_scheduled = false

	# Process deferred callables
	if not _deferred_callables.is_empty():
		var callables = _deferred_callables
		var args_list = _deferred_args
		_deferred_callables = []
		_deferred_args = []
		for i in callables.size():
			var callable = callables[i]
			if callable.is_valid():
				var args = args_list[i]
				if args == null:
					callable.call()
				elif args is Array:
					callable.callv(args)
				else:
					callable.call(args)

	# Process typed spawn queue
	if not _spawn_queue.is_empty():
		var current_spawns = _spawn_queue
		_spawn_queue = []
		
		for spawn_data in current_spawns:
			var parent = spawn_data["parent"]
			if not is_instance_valid(parent): 
				continue
				
			var instance = spawn_data["scene"].instantiate()
			var pos = spawn_data["position"]
			
			if pos != null:
				if instance is Node2D:
					if pos is Vector2: instance.global_position = pos
					elif pos is Transform2D: instance.global_transform = pos
				elif instance is Node3D:
					if pos is Vector3: instance.global_position = pos
					elif pos is Transform3D: instance.global_transform = pos
					
			parent.add_child(instance)
			
			var cb = spawn_data["callback"]
			if cb.is_valid():
				cb.call(instance)

	# Process generic commands
	if not _command_queue.is_empty():
		var commands = _command_queue
		_command_queue = []
		for cmd in commands:
			if cmd.is_valid():
				cmd.call()

	var total_changes: int = (
			_despawn_queue.size()
			+ _pending_unregistrations.size()
			+ _pending_registrations.size()
			+ _dirty_entities.size()
	)

	if total_changes == 0:
		return

	var is_batch: bool = total_changes >= MASS_UPDATE_THRESHOLD

	# Process despawn queue
	var despawns: Array[Node] = _despawn_queue
	_despawn_queue = []
	_despawn_set.clear()
	if not despawns.is_empty():
		for target_node in despawns:
			if not is_instance_valid(target_node):
				continue
			var config: EntityConfig = _extract_config(target_node)
			var free_target: Node = _extract_free_target(target_node)
			if is_instance_valid(config):
				if is_batch:
					_unregister_from_active(config)
				else:
					_apply_entity_unregistration(config)
			if is_instance_valid(free_target):
				free_target.queue_free()

	# Process unregistrations
	var unregs: Array[Variant] = _pending_unregistrations
	_pending_unregistrations = []
	_pending_unregistrations_set.clear()
	if not unregs.is_empty():
		for entity in unregs:
			if is_instance_valid(entity):
				if is_batch:
					_unregister_from_active(entity)
				else:
					_apply_entity_unregistration(entity)

	# Process registrations
	var regs: Array[EntityConfig] = _pending_registrations
	_pending_registrations = []
	_pending_registrations_set.clear()
	if not regs.is_empty():
		for entity in regs:
			if is_instance_valid(entity):
				if is_batch:
					_register_to_active(entity)
				else:
					_apply_entity_registration(entity)

	# Finalize Batch vs Incremental updates
	if is_batch:
		_process_batch_update(regs)
	else:
		_process_incremental_update()


# ==============================================================================
# PRIVATE REGISTRY & DISPATCH HELPERS
# ==============================================================================

## Handles mass entity mutations cleanly by identifying affected system candidates.
func _process_batch_update(new_registrations: Array[EntityConfig]) -> void:
	var candidate_systems: Dictionary = {}
	var has_specific_candidates: bool = false

	for entity in _dirty_entities.keys():
		var changed_scripts: Array = _dirty_entities[entity]
		
		for script in changed_scripts:
			if script and _script_to_systems.has(script):
				has_specific_candidates = true
				for sys in _script_to_systems[script]:
					candidate_systems[sys] = true

	for entity in new_registrations:
		if is_instance_valid(entity):
			var sys_list = _get_candidate_systems_for(entity)
			if not sys_list.is_empty():
				has_specific_candidates = true
				for sys in sys_list:
					candidate_systems[sys] = true

	_dirty_entities.clear()

	if has_specific_candidates and not candidate_systems.is_empty():
		for sys in candidate_systems.keys():
			if is_instance_valid(sys) and sys.has_method(&"_update_query_filter"):
				sys._update_query_filter()
	else:
		_remap_all_system_queries()


## Handles small-scale entity modifications.
func _process_incremental_update() -> void:
	var dirty_snapshot = _dirty_entities
	_dirty_entities = {}
	
	for entity in dirty_snapshot.keys():
		if is_instance_valid(entity):
			var changed_scripts: Array = dirty_snapshot[entity]
			var candidates = _get_candidate_systems_for(entity, changed_scripts)
			
			for system in candidates:
				if system.has_method(&"_evaluate_single_entity"):
					system._evaluate_single_entity(entity)


## Adds entity to active_config.
func _register_to_active(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig) or _active_config_map.has(entity):
		return
	var cfg = entity as EntityConfig
	cfg._is_registered = true
	_active_config_map[cfg] = active_config.size()
	active_config.append(cfg)


## Removes entity from active_config
func _unregister_from_active(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig) or not _active_config_map.has(entity):
		return
	var cfg = entity as EntityConfig
	cfg._is_registered = false
	var idx: int = _active_config_map[cfg]
	var last_idx: int = active_config.size() - 1
	var last_entity: EntityConfig = active_config[last_idx]
	active_config[idx] = last_entity
	_active_config_map[last_entity] = idx
	active_config.pop_back()
	_active_config_map.erase(cfg)
	_dirty_entities.erase(cfg)


func _apply_entity_registration(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig) or _active_config_map.has(entity):
		return

	_register_to_active(entity)

	var candidates = _get_candidate_systems_for(entity)
	if candidates.is_empty():
		for sys in _systems.values():
			if sys.has_method(&"_evaluate_single_entity"):
				sys._evaluate_single_entity(entity)
	else:
		for system in candidates:
			if system.has_method(&"_evaluate_single_entity"):
				system._evaluate_single_entity(entity)


func _apply_entity_unregistration(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig):
		return
	_unregister_from_active(entity)
	for sys in _systems_list:
		sys._handle_incremental_departure(entity)


## Extracts EntityConfig node from any node hierarchy or property binding.
func _extract_config(node_or_config: Variant) -> EntityConfig:
	if not is_instance_valid(node_or_config):
		return null
	if node_or_config is EntityConfig:
		return node_or_config as EntityConfig
	if "entity_config" in node_or_config and node_or_config.entity_config is EntityConfig:
		return node_or_config.entity_config as EntityConfig
	if "config" in node_or_config and node_or_config.config is EntityConfig:
		return node_or_config.config as EntityConfig
	if node_or_config is Node:
		for child in (node_or_config as Node).get_children():
			if child is EntityConfig:
				return child as EntityConfig
	return null


func _extract_free_target(node_or_config: Variant) -> Node:
	if not is_instance_valid(node_or_config):
		return null
	if node_or_config is EntityConfig:
		return node_or_config.entity_node if node_or_config.entity_node else node_or_config
	return node_or_config as Node


## Returns systems interested in the entity's components/data or changed scripts.
## When changed_scripts is provided, ONLY returns systems interested in those specific changes.
func _get_candidate_systems_for(
		entity: Variant,
		changed_scripts: Array = []
) -> Array[SystemBase]:
	if not is_instance_valid(entity) or not (entity is EntityConfig):
		return []

	var candidates: Dictionary = {}

	if not changed_scripts.is_empty():
		for script in changed_scripts:
			if script and _script_to_systems.has(script):
				for sys in _script_to_systems[script]:
					candidates[sys] = true

		var result: Array[SystemBase] = []
		result.assign(candidates.keys())
		return result

	var all_scripts: Array[Script] = []
	if entity.has_method(&"get_component_scripts"):
		all_scripts.append_array(entity.get_component_scripts())
	if entity.has_method(&"get_data_scripts"):
		all_scripts.append_array(entity.get_data_scripts())

	for script in all_scripts:
		if _script_to_systems.has(script):
			for sys in _script_to_systems[script]:
				candidates[sys] = true

	var result: Array[SystemBase] = []
	result.assign(candidates.keys())
	return result


## Full world filter sweep — asks every system to re-evaluate all active entities in one batch.
func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method(&"_update_query_filter"):
			system._update_query_filter()


func _schedule_flush() -> void:
	if not _flush_scheduled:
		_flush_scheduled = true
