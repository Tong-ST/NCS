## Global singleton (autoload as "NCS").
## Manages the active entity registry, system queries, and frame flush pipeline.
extends Node

## Auto-detection threshold: if queued changes in a frame >= this threshold, batch re-query is used.
## Otherwise, incremental single-entity evaluation is used.
const MASS_UPDATE_THRESHOLD: int = 50

var active_entities: Array[EntityConfig] = []

var _systems: Dictionary = {}
var _systems_list: Array[NCSSystemBase] = []
var _active_entities_map: Dictionary = {}
var _script_to_systems: Dictionary = {}

# Command buffer & flush queues
var _command_queue: Array[Callable] = []
var _dirty_entities: Dictionary = {}
var _pending_registrations: Array[EntityConfig] = []
var _pending_unregistrations: Array[Variant] = []
var _despawn_queue: Array[Node] = []

# Typed method call queue (zero closure allocations)
var _method_call_configs: Array[EntityConfig] = []
var _method_call_scripts: Array[Script] = []
var _method_call_names: Array[StringName] = []
var _method_call_args: Array[Array] = []

var _is_updating: bool = false
var _flush_scheduled: bool = false


func _process(_delta: float) -> void:
	if _flush_scheduled:
		flush()


func _physics_process(_delta: float) -> void:
	if _flush_scheduled:
		flush()


# ==============================================================================
# COMMAND BUFFER, METHOD CALLS & DIRTY MARKING
# ==============================================================================

## Enqueues a structural command to execute safely during flush.
func push_command(command: Callable) -> void:
	if not command.is_valid():
		return
	_command_queue.append(command)
	_schedule_flush()


## Enqueues a component method call without allocating closures.
func push_method_call(config: EntityConfig, comp_script: Script, method_name: StringName, args: Array = []) -> void:
	if not is_instance_valid(config):
		return
	_method_call_configs.append(config)
	_method_call_scripts.append(comp_script)
	_method_call_names.append(method_name)
	_method_call_args.append(args)
	_schedule_flush()


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
# FLUSH PIPELINE (AUTO-DETECT BATCH VS INCREMENTAL)
# ==============================================================================

func set_updating_state(state: bool) -> void:
	_is_updating = state


func _schedule_flush() -> void:
	if not _flush_scheduled:
		_flush_scheduled = true


## Flushes queued operations. Auto-detects whether to run Batch Re-query (>= threshold)
## or Incremental Single-Entity evaluations (< threshold).
func flush() -> void:
	_flush_scheduled = false

	# 1. Process typed method calls
	if not _method_call_configs.is_empty():
		var configs = _method_call_configs
		var scripts = _method_call_scripts
		var names = _method_call_names
		var args_list = _method_call_args
		_method_call_configs = []
		_method_call_scripts = []
		_method_call_names = []
		_method_call_args = []
		for i in configs.size():
			var cfg = configs[i]
			if is_instance_valid(cfg):
				cfg.call_method(scripts[i], names[i], args_list[i])

	# 2. Process structural commands (e.g. spawn lambdas)
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
	if is_batch:
		print("[NCS SystemManager] Auto-detected MASS update (%d changes) -> Executing BATCH re-query" % total_changes)
	else:
		print("[NCS SystemManager] Auto-detected INCREMENTAL update (%d changes) -> Executing single evaluations" % total_changes)

	# Process despawn queue
	if not _despawn_queue.is_empty():
		var despawns = _despawn_queue
		_despawn_queue = []
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
	if not _pending_unregistrations.is_empty():
		var unregs = _pending_unregistrations
		_pending_unregistrations = []
		for entity in unregs:
			if is_instance_valid(entity):
				if is_batch:
					_unregister_from_active(entity)
				else:
					_apply_entity_unregistration(entity)

	# Process registrations
	if not _pending_registrations.is_empty():
		var regs = _pending_registrations
		_pending_registrations = []
		for entity in regs:
			if is_instance_valid(entity):
				if is_batch:
					_register_to_active(entity)
				else:
					_apply_entity_registration(entity)

	# Finalize Batch vs Incremental updates
	if is_batch:
		_dirty_entities.clear()
		_remap_all_system_queries()
	elif not _dirty_entities.is_empty():
		var dirty_snapshot = _dirty_entities
		_dirty_entities = {}
		for entity in dirty_snapshot.keys():
			if is_instance_valid(entity):
				var changed_scripts: Array = dirty_snapshot[entity]
				var candidates = _get_candidate_systems_for(entity, changed_scripts)
				for system in candidates:
					if system.has_method(&"_evaluate_single_entity"):
						system._evaluate_single_entity(entity)


## Adds entity to active_entities in O(1).
func _register_to_active(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig) or _active_entities_map.has(entity):
		return
	var cfg = entity as EntityConfig
	cfg._is_registered = true
	_active_entities_map[cfg] = active_entities.size()
	active_entities.append(cfg)


## Removes entity from active_entities via O(1) swap-and-pop.
func _unregister_from_active(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig) or not _active_entities_map.has(entity):
		return
	var cfg = entity as EntityConfig
	cfg._is_registered = false
	var idx: int = _active_entities_map[cfg]
	var last_idx: int = active_entities.size() - 1
	var last_entity: EntityConfig = active_entities[last_idx]
	active_entities[idx] = last_entity
	_active_entities_map[last_entity] = idx
	active_entities.pop_back()
	_active_entities_map.erase(cfg)
	_dirty_entities.erase(cfg)


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
		return node_or_config.get_parent() if node_or_config.get_parent() else node_or_config
	return node_or_config as Node


# ==============================================================================
# ENTITY LIFECYCLE
# ==============================================================================

## Registers an entity for evaluation during flush.
func register_entity(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig):
		return
	if not _pending_registrations.has(entity):
		_pending_registrations.append(entity as EntityConfig)
		_schedule_flush()


## Unregisters an entity during flush.
func unregister_entity(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig):
		return
	var cfg = entity as EntityConfig
	if not cfg._is_registered:
		return
	if not _pending_unregistrations.has(cfg):
		_pending_unregistrations.append(cfg)
		_schedule_flush()


func _apply_entity_registration(entity: Variant) -> void:
	if not is_instance_valid(entity) or not (entity is EntityConfig) or _active_entities_map.has(entity):
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


# ==============================================================================
# SPAWN & DESPAWN
# ==============================================================================

## Queues an entity or node for despawn at next flush.
func despawn(node_or_config: Variant) -> void:
	if not is_instance_valid(node_or_config):
		return

	var config: EntityConfig = _extract_config(node_or_config)
	if is_instance_valid(config):
		config._is_registered = false

	if node_or_config is Node:
		_despawn_queue.append(node_or_config as Node)
		_schedule_flush()


## Safely instantiates and adds a 2D/3D entity to the scene tree.
func spawn(
		scene: PackedScene,
		parent: Node,
		position_or_transform: Variant = null,
		setup_callback: Callable = Callable()
) -> void:
	if not scene or not is_instance_valid(parent):
		return

	push_command(func():
		if not is_instance_valid(parent):
			return

		var instance = scene.instantiate()

		if position_or_transform != null:
			if instance is Node3D:
				if position_or_transform is Vector3:
					instance.global_position = position_or_transform
				elif position_or_transform is Transform3D:
					instance.global_transform = position_or_transform
			elif instance is Node2D:
				if position_or_transform is Vector2:
					instance.global_position = position_or_transform
				elif position_or_transform is Transform2D:
					instance.global_transform = position_or_transform

		parent.add_child(instance)

		if setup_callback.is_valid():
			setup_callback.call(instance)
	)


# ==============================================================================
# SYSTEM REGISTRATION & CANDIDATE LOOKUPS
# ==============================================================================

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


## Returns systems interested in the entity's components/data or changed scripts.
func _get_candidate_systems_for(
		entity: Variant,
		changed_scripts: Array = []
) -> Array[NCSSystemBase]:
	if not is_instance_valid(entity) or not (entity is EntityConfig):
		return []

	var candidates: Dictionary = {}
	var all_scripts: Array[Script] = []

	if entity.has_method(&"get_component_scripts"):
		all_scripts.append_array(entity.get_component_scripts())
	if entity.has_method(&"get_data_scripts"):
		all_scripts.append_array(entity.get_data_scripts())

	for script in changed_scripts:
		if script and not all_scripts.has(script):
			all_scripts.append(script)

	for script in all_scripts:
		if _script_to_systems.has(script):
			for sys in _script_to_systems[script]:
				candidates[sys] = true

	var result: Array[NCSSystemBase] = []
	result.assign(candidates.keys())
	return result


## Returns a live system instance by name, or null.
func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)


## Full world filter sweep — asks every system to re-evaluate all active entities in one batch.
func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method(&"_update_query_filter"):
			system._update_query_filter()
