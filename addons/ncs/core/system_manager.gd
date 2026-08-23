# NCS global singleton (autoload as "NCS"). Owns the master entity list and all system refs.
# Most calls come through EntityConfig (add_comp, remove_comp, add_data, remove_data).
extends Node

const MASS_UPDATE_THRESHOLD: int = 500

var active_entities: Array[EntityConfig] = []

var _systems: Dictionary = {}
var _active_entities_map: Dictionary = {}
var _script_to_systems: Dictionary = {}

# Command Buffer & Flush Data Structures
var _command_queue: Array[Callable] = []
var _dirty_entities: Dictionary = {} # EntityConfig -> Array[Script]
var _pending_registrations: Array[EntityConfig] = []
var _pending_unregistrations: Array[EntityConfig] = []
var _is_updating: bool = false
var _flush_scheduled: bool = false


func _process(_delta: float) -> void:
	if _flush_scheduled:
		flush()


func _physics_process(_delta: float) -> void:
	if _flush_scheduled:
		flush()

# ==============================================================================
# COMMAND BUFFER & DIRTY MARKING
# ==============================================================================

## Enqueues a structural command (e.g., node spawning, tree removal) to execute safely during flush.
func push_command(command: Callable) -> void:
	if not command.is_valid():
		return
	_command_queue.append(command)
	_schedule_flush()


## Marks an entity as dirty for re-evaluation during the post-frame flush.
func mark_dirty(entity: EntityConfig, changed_script: Script = null) -> void:
	if not is_instance_valid(entity):
		return

	if not _dirty_entities.has(entity):
		_dirty_entities[entity] = []

	if changed_script and not _dirty_entities[entity].has(changed_script):
		_dirty_entities[entity].append(changed_script)

	_schedule_flush()


## Backwards-compatible alias for mark_dirty.
func update_single_entity(entity: EntityConfig, changed_script: Script = null) -> void:
	mark_dirty(entity, changed_script)

# ==============================================================================
# POST-FRAME FLUSH PIPELINE
# ==============================================================================

## Main processing loop entry to flag mid-frame system iterations.
func set_updating_state(state: bool) -> void:
	_is_updating = state


func _schedule_flush() -> void:
	if not _flush_scheduled:
		_flush_scheduled = true


## Flushes queued commands, entity lifecycle changes, and dirty queries in guaranteed order.
func flush() -> void:
	_flush_scheduled = false

	# Step 1: Execute all queued structural commands (lambdas, spawns, despawns)
	if not _command_queue.is_empty():
		var commands = _command_queue.duplicate()
		_command_queue.clear()
		for cmd in commands:
			if cmd.is_valid():
				cmd.call()

	# Step 2: Flush pending registrations
	if not _pending_registrations.is_empty():
		var to_register = _pending_registrations.duplicate()
		_pending_registrations.clear()
		for entity in to_register:
			_apply_entity_registration(entity)

	# Step 3: Flush pending unregistrations
	if not _pending_unregistrations.is_empty():
		var to_unregister = _pending_unregistrations.duplicate()
		_pending_unregistrations.clear()
		for entity in to_unregister:
			_apply_entity_unregistration(entity)

	# Step 4: Unified Re-Query Sweep for Dirty Entities
	if _dirty_entities.is_empty():
		return

	if _dirty_entities.size() >= MASS_UPDATE_THRESHOLD:
		_dirty_entities.clear()
		_remap_all_system_queries()
		return

	var dirty_snapshot = _dirty_entities.duplicate()
	_dirty_entities.clear()

	for entity in dirty_snapshot.keys():
		if is_instance_valid(entity):
			var changed_scripts: Array = dirty_snapshot[entity]
			var candidates = _get_candidate_systems_for(entity, changed_scripts)
			for system in candidates:
				if system.has_method(&"_evaluate_single_entity"):
					system._evaluate_single_entity(entity)

# ==============================================================================
# ENTITY LIFECYCLE
# ==============================================================================

## Called by EntityConfig._enter_tree(). Do not call manually.
func register_entity(entity: EntityConfig) -> void:
	if _is_updating:
		if not _pending_registrations.has(entity):
			_pending_registrations.append(entity)
			_schedule_flush()
	else:
		_apply_entity_registration(entity)


## Called by EntityConfig._exit_tree(). Do not call manually.
func unregister_entity(entity: EntityConfig) -> void:
	if _is_updating:
		if not _pending_unregistrations.has(entity):
			_pending_unregistrations.append(entity)
			_schedule_flush()
	else:
		_apply_entity_unregistration(entity)


func _apply_entity_registration(entity: EntityConfig) -> void:
	if not is_instance_valid(entity) or _active_entities_map.has(entity):
		return

	_active_entities_map[entity] = active_entities.size()
	active_entities.append(entity)

	var candidates = _get_candidate_systems_for(entity)
	if candidates.is_empty():
		for sys in _systems.values():
			if sys.has_method(&"_evaluate_single_entity"):
				sys._evaluate_single_entity(entity)
	else:
		for system in candidates:
			if system.has_method(&"_evaluate_single_entity"):
				system._evaluate_single_entity(entity)


func _apply_entity_unregistration(entity: EntityConfig) -> void:
	if _active_entities_map.has(entity):
		var idx: int = _active_entities_map[entity]
		var last_idx: int = active_entities.size() - 1
		var last_entity: EntityConfig = active_entities[last_idx]
		active_entities[idx] = last_entity
		_active_entities_map[last_entity] = idx
		active_entities.pop_back()
		_active_entities_map.erase(entity)

	_dirty_entities.erase(entity)

	for sys in _systems.values():
		if sys.has_method(&"_handle_incremental_departure"):
			sys._handle_incremental_departure(entity)

# ==============================================================================
# SYSTEM REGISTRATION & CANDIDATE LOOKUPS
# ==============================================================================

## Registers a system into the world. Called automatically by NCSWorld.
func register_system(system_name: String, system_instance: Node) -> void:
	_systems[system_name] = system_instance
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


func unregister_system(system_name: String) -> void:
	var system_instance = _systems.get(system_name)
	if system_instance:
		for script in _script_to_systems.keys():
			var sys_list: Array = _script_to_systems[script]
			sys_list.erase(system_instance)
			if sys_list.is_empty():
				_script_to_systems.erase(script)

	_systems.erase(system_name)


## Returns systems that care about the entity's current components/data OR specific changed scripts.
func _get_candidate_systems_for(
			entity: EntityConfig,
			changed_scripts: Array = []) -> Array[NCSSystemBase]:
	if not is_instance_valid(entity):
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


## Returns a live system instance by class name, or null.
func get_system_by_name(system_name: String) -> Node:
	return _systems.get(system_name, null)


## Full world filter sweep — asks every system to re-evaluate all active entities.
func _remap_all_system_queries() -> void:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.has_method(&"_update_query_filter"):
			system._update_query_filter()
