## Global singleton (autoload as "NCS").
## Manages the active entity registry, system queries, and frame flush pipeline.
@icon("res://addons/ncs/icons/gear-solid-full.svg")
extends Node

## Auto-detection threshold: if queued changes in a frame >= this threshold, batch re-query is used.
## Otherwise, incremental single-entity evaluation is used.
const MASS_UPDATE_THRESHOLD: int = 50

## Main world reference automatically tracked by active NCSWorld nodes
var current_world: Node = null

## Master list of every active EntityConfig in the world.
var active_config: Array[EntityConfig] = []

# Internal system registries
var _systems: Dictionary = {}
var _systems_list: Array[SystemBase] = []
var _active_config_map: Dictionary = {}
var _script_to_systems: Dictionary = {}
var _systems_by_script: Dictionary = {}

# Internal command buffer & flush queues
var _command_queue: Array[Callable] = []
var _dirty_entities: Dictionary = {}
var _pending_registrations: Array[EntityConfig] = []
var _pending_registrations_set: Dictionary = {}
var _pending_unregistrations: Array[EntityConfig] = []
var _pending_unregistrations_set: Dictionary = {}

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
## Usage: NCS.spawn(enemy_scene, self, player.global_position, func(enemy):...)
func spawn(
		scene: PackedScene,
		parent: Node,
		position_or_transform: Variant = null,
		setup_callback: Callable = Callable()
) -> void:
	if not scene or not is_instance_valid(parent):
		push_warning("NCS warning: Tried to spawn an invalid scene or parent.")
		return

	push_command(func():
		if not is_instance_valid(parent):
			push_warning("NCS warning: Parent node is no longer valid during spawn command.")
			return

		var instance = scene.instantiate()

		if position_or_transform != null:
			if instance is Node2D:
				if position_or_transform is Vector2: instance.global_position = position_or_transform
				elif position_or_transform is Transform2D: instance.global_transform = position_or_transform
			elif instance is Node3D:
				if position_or_transform is Vector3: instance.global_position = position_or_transform
				elif position_or_transform is Transform3D: instance.global_transform = position_or_transform

		parent.add_child(instance)

		if setup_callback.is_valid():
			setup_callback.call(instance)
	)


## Queues an entity or node for safe despawn via the command buffer.
func despawn(node_or_config: Variant) -> void:
	if not is_instance_valid(node_or_config):
		push_warning("NCS warning: Tried to despawn an invalid node or config.")
		return

	var config: EntityConfig = extract_config(node_or_config)
	var free_target: Node = extract_free_target(node_or_config)

	if is_instance_valid(config):
		config._is_registered = false
		push_command(func():
			unregister_entity(config)
			if is_instance_valid(free_target) and not free_target.is_queued_for_deletion():
				free_target.queue_free()
		)


# ==============================================================================
# PUBLIC COMMAND & METHOD QUEUEING API
# ==============================================================================

## Enqueues a structural command to execute safely during flush.
func push_command(command: Callable) -> void:
	if not command.is_valid():
		push_warning("NCS warning: Tried to push an invalid command to the queue.")
		return
	_command_queue.append(command)
	_schedule_flush()


## Enqueues a pre-bound Callable for deferred execution without allocating closures.
func push_callable(callable: Callable, arg_or_args: Variant = null) -> void:
	if not callable.is_valid():
		push_warning("NCS warning: Tried to push an invalid callable to the queue.")
		return
	_deferred_callables.append(callable)
	_deferred_args.append(arg_or_args)
	_schedule_flush()


## Enqueues a component method call without allocating closures.
func push_method_call(config: Variant,
		comp_script: Script,
		method_name: StringName,
		args: Variant = null
) -> void:
	if not is_instance_valid(config) or not (config is EntityConfig):
		push_warning("NCS warning: Invalid config provided to push_method_call.")
		return
	var callable = (config as EntityConfig).get_callable(comp_script, method_name)
	if callable.is_valid():
		push_callable(callable, args)


## Marks an entity as dirty for re-evaluation during flush.
func mark_dirty(config: EntityConfig, changed_script: Script = null) -> void:
	if not is_instance_valid(config):
		push_warning("NCS warning: Tried to mark an invalid config as dirty.")
		return
	if not _dirty_entities.has(config):
		_dirty_entities[config] = []
	if changed_script and not _dirty_entities[config].has(changed_script):
		_dirty_entities[config].append(changed_script)
	_schedule_flush()


# ==============================================================================
# PUBLIC ENTITY & SYSTEM REGISTRATION API
# ==============================================================================

## Registers an entity for evaluation during flush.
func register_entity(config: EntityConfig) -> void:
	if not is_instance_valid(config) or not (config is EntityConfig):
		push_warning("NCS warning: Tried to register an invalid config.")
		return
	if not _pending_registrations_set.has(config):
		_pending_registrations_set[config] = true
		_pending_registrations.append(config as EntityConfig)
		_schedule_flush()


## Unregisters an entity during flush.
func unregister_entity(config: EntityConfig) -> void:
	if not is_instance_valid(config) or not (config is EntityConfig):
		push_warning("NCS warning: Tried to unregister an invalid config.")
		return
	if not _pending_unregistrations_set.has(config):
		_pending_unregistrations_set[config] = true
		_pending_unregistrations.append(config)
		_schedule_flush()


## Immediately unregisters an entity from the NCS.
## Crucial for native queue_free() safety, as deferred unregistration
func unregister_entity_sync(config: EntityConfig) -> void:
	if not is_instance_valid(config):
		push_warning("NCS warning: Tried to sync-unregister an invalid config.")
		return

	if _pending_unregistrations_set.has(config):
		_pending_unregistrations_set.erase(config)
		_pending_unregistrations.erase(config)

	_apply_entity_unregistration(config)


## Adds a system class (e.g., NCS.add_system(SysMovement, $NCSWorld/SystemsFolder))
func add_system(sys_script: Script, parent: Node = null, target_index: int = -1) -> SystemBase:
	if _systems_by_script.has(sys_script):
		push_warning("NCS: System '%s' is already active." % sys_script.resource_path.get_file())
		return _systems_by_script[sys_script]

	var sys_instance: SystemBase = sys_script.new() as SystemBase
	var target_parent = (
			parent if is_instance_valid(parent)
			else (current_world if is_instance_valid(current_world) else self)
	)
	target_parent.add_child(sys_instance)

	if target_index >= 0:
		target_parent.move_child(sys_instance, target_index)

	return sys_instance


## Removes a system class e.g., NCS.remove_system(SysMovement)
func remove_system(sys_script: Script) -> void:
	if _systems_by_script.has(sys_script):
		_systems_by_script[sys_script].queue_free() # Triggers _exit_tree auto-unregistration


## Registers a system instance into the world and immediately queries matching entities.
func register_system(system: SystemBase) -> void:
	var sys_script = system.get_script()
	if _systems_by_script.has(sys_script):
		return

	_systems_by_script[sys_script] = system
	_systems_list.append(system)

	system._initialize_query_if_needed()

	for script in system.interest_scripts:
		if not _script_to_systems.has(script):
			_script_to_systems[script] = []
		_script_to_systems[script].append(system)

	system._update_query_filter()
	_invalidate_all_entity_caches()


## Unregisters a system and clears its internal object references.
func unregister_system(system: SystemBase) -> void:
	var sys_script = system.get_script()
	if not _systems_by_script.has(sys_script):
		return

	_systems_by_script.erase(sys_script)
	_systems_list.erase(system)

	for script in _script_to_systems.keys():
		_script_to_systems[script].erase(system)
		if _script_to_systems[script].is_empty():
			_script_to_systems.erase(script)

	system._clear_system_state()
	_invalidate_all_entity_caches()


## Returns true if a system instance or system class is already registered in the world.
func has_system(sys_script: Script) -> bool:
	return _systems_by_script.has(sys_script)


## Extracts EntityConfig node from any node hierarchy or property binding.
func extract_config(node_or_config: Variant) -> EntityConfig:
	if not is_instance_valid(node_or_config):
		return null
	if "entity_config" in node_or_config and node_or_config.entity_config is EntityConfig:
		return node_or_config.entity_config
	if "config" in node_or_config and node_or_config.config is EntityConfig:
		return node_or_config.config
	if node_or_config is EntityConfig:
		return node_or_config
	if node_or_config is Node:
		for child in (node_or_config as Node).get_children():
			if child is EntityConfig:
				return child
	return null


func extract_free_target(node_or_config: Variant) -> Node:
	if not is_instance_valid(node_or_config):
		return null
	if node_or_config is Node:
		return node_or_config
	if node_or_config is EntityConfig:
		return node_or_config.entity_node if node_or_config.entity_node else node_or_config
	return node_or_config


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

	# Process generic commands
	if not _command_queue.is_empty():
		var commands = _command_queue
		_command_queue = []
		for cmd in commands:
			if cmd.is_valid():
				cmd.call()

	var total_changes: int = (
			+ _pending_unregistrations.size()
			+ _pending_registrations.size()
			+ _dirty_entities.size()
	)
	if total_changes == 0:
		return
	var is_batch: bool = total_changes >= MASS_UPDATE_THRESHOLD

	# Process unregistrations
	var unregs: Array[EntityConfig] = _pending_unregistrations
	_pending_unregistrations = []
	_pending_unregistrations_set.clear()
	if not unregs.is_empty():
		for config in unregs:
			if is_batch:
				_unregister_from_active(config)
			else:
				_apply_entity_unregistration(config)

	# Process registrations
	var regs: Array[EntityConfig] = _pending_registrations
	_pending_registrations = []
	_pending_registrations_set.clear()
	if not regs.is_empty():
		for config in regs:
			if is_instance_valid(config):
				if is_batch:
					_register_to_active(config)
				else:
					_apply_entity_registration(config)

	# Finalize Batch/Incremental updates
	if is_batch:
		_process_batch_update(regs, unregs)
	else:
		_process_incremental_update()


# ==============================================================================
# PRIVATE REGISTRY & DISPATCH HELPERS
# ==============================================================================

## Handles mass entity mutations cleanly by identifying affected system candidates.
func _process_batch_update(
		new_registrations: Array[EntityConfig],
		unregistrations: Array[EntityConfig] = []
) -> void:
	var candidate_systems: Dictionary = {}
	var has_specific_candidates: bool = false

	for config in _dirty_entities.keys():
		var changed_scripts: Array = _dirty_entities[config]
		for script in changed_scripts:
			if script and _script_to_systems.has(script):
				has_specific_candidates = true
				for sys in _script_to_systems[script]:
					candidate_systems[sys] = true

	for config in new_registrations:
		if is_instance_valid(config):
			var sys_list = _get_candidate_systems_for(config)
			if not sys_list.is_empty():
				has_specific_candidates = true
				for sys in sys_list:
					candidate_systems[sys] = true

	for config in unregistrations:
		if is_instance_valid(config):
			var sys_list = _get_candidate_systems_for(config)
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

	for config in dirty_snapshot.keys():
		if is_instance_valid(config):
			var changed_scripts: Array = dirty_snapshot[config]
			var candidates = _get_candidate_systems_for(config, changed_scripts)

			for system in candidates:
				if system.has_method(&"_evaluate_single_entity"):
					system._evaluate_single_entity(config)


## Adds entity to active_config.
func _register_to_active(config: EntityConfig) -> void:
	if not is_instance_valid(config) or not (config is EntityConfig) or _active_config_map.has(config):
		return
	var cfg = config as EntityConfig
	cfg._is_registered = true
	_active_config_map[cfg] = active_config.size()
	active_config.append(cfg)


func _apply_entity_registration(config: EntityConfig) -> void:
	if not is_instance_valid(config) or not (config is EntityConfig) or _active_config_map.has(config):
		return

	_register_to_active(config)

	var candidates = _get_candidate_systems_for(config)
	if candidates.is_empty():
		for sys in _systems.values():
			if sys.has_method(&"_evaluate_single_entity"):
				sys._evaluate_single_entity(config)
	else:
		for system in candidates:
			if system.has_method(&"_evaluate_single_entity"):
				system._evaluate_single_entity(config)


## Removes entity from active_config
func _unregister_from_active(config: EntityConfig) -> void:
	if not _active_config_map.has(config):
		return

	if is_instance_valid(config) and config is EntityConfig:
		(config as EntityConfig)._is_registered = false

	var idx: int = _active_config_map[config]
	var last_idx: int = active_config.size() - 1
	var last_entity: EntityConfig = active_config[last_idx]

	active_config[idx] = last_entity
	_active_config_map[last_entity] = idx
	active_config.pop_back()

	_active_config_map.erase(config)
	_dirty_entities.erase(config)


func _apply_entity_unregistration(config: EntityConfig) -> void:
	if not _active_config_map.has(config):
		return
	_unregister_from_active(config)
	for sys in _systems_list:
		sys._handle_incremental_departure(config)


## Returns systems interested in the entity's components/data or changed scripts.
## When changed_scripts is provided, ONLY returns systems interested in those specific changes.
func _get_candidate_systems_for(
		config: EntityConfig,
		changed_scripts: Array = []
) -> Array[SystemBase]:
	if not is_instance_valid(config) or not (config is EntityConfig):
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
	if config.has_method(&"get_component_scripts"):
		all_scripts.append_array(config.get_component_scripts())
	if config.has_method(&"get_data_scripts"):
		all_scripts.append_array(config.get_data_scripts())

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


## Invalidates candidate system caches on all active EntityConfigs when system list changes
func _invalidate_all_entity_caches() -> void:
	for config in active_config:
		if is_instance_valid(config) and "is_system_cache_dirty" in config:
			config.is_system_cache_dirty = true


func _schedule_flush() -> void:
	if not _flush_scheduled:
		_flush_scheduled = true
