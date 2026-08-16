extends Node

## Centralized, modular Object Pool Manager for NCS Entities and Godot Nodes.
## Completely optional and decoupled: works seamlessly with EntityConfig or any standard Node.

# Pools tracking inactive instances. Key: PackedScene -> Array[Node]
var _pools: Dictionary = {}

# Active pooled entities tracking. Key: Node -> PackedScene
var _active_pooled_entities: Dictionary = {}

# Container node to hold hidden inactive pooled entities
var _pool_container: Node


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_pool_container = Node.new()
	_pool_container.name = "__NCSEntityPoolContainer__"
	add_child(_pool_container)


## Spawns a pooled entity. Reuses an inactive instance if available, or instantiates a new one.
func spawn(scene: PackedScene, global_pos: Vector2 = Vector2.ZERO, parent: Node = null) -> Node:
	if not is_instance_valid(scene):
		push_error("NCSEntityPool Error: Cannot spawn invalid PackedScene!")
		return null

	var entity: Node = null
	if not _pools.has(scene):
		_pools[scene] = []

	var pool_array: Array = _pools[scene]

	# Re-use inactive instance from pool if available
	while not pool_array.is_empty():
		var candidate = pool_array.pop_back()
		if is_instance_valid(candidate):
			entity = candidate
			break

	var target_parent = parent if is_instance_valid(parent) else get_tree().current_scene

	if is_instance_valid(entity):
		var config = _find_entity_config(entity)
		if is_instance_valid(config):
			config.is_active = true
			config.pooled_scene_key = scene

		# Reparent to level target parent if needed
		if entity.get_parent() != target_parent:
			if entity.get_parent():
				entity.get_parent().remove_child(entity)
			target_parent.add_child(entity)

		# Position entity if Node2D or Node3D
		_set_entity_position(entity, global_pos)

		# Re-enable process & visibility
		entity.process_mode = PROCESS_MODE_INHERIT
		if entity is CanvasItem or entity is Node3D:
			entity.show()

		# Reset data to baseline and register into active system arrays
		if is_instance_valid(config):
			config.reset_data()
			NCS.register_entity(config)
	else:
		# Instantiate new instance
		entity = scene.instantiate()
		var config = _find_entity_config(entity)
		if is_instance_valid(config):
			config.is_active = true
			config.pooled_scene_key = scene

		_set_entity_position(entity, global_pos)
		target_parent.add_child(entity)

	_active_pooled_entities[entity] = scene
	return entity


## Despawns a pooled entity. Deactivates processing and unregisters from active system arrays.
func despawn(entity_node: Node) -> void:
	if not is_instance_valid(entity_node):
		return

	var config = _find_entity_config(entity_node)
	if is_instance_valid(config):
		config.is_active = false
		NCS.unregister_entity(config)

	# Disable process & visibility
	entity_node.process_mode = PROCESS_MODE_DISABLED
	if entity_node is CanvasItem or entity_node is Node3D:
		entity_node.hide()

	# Retrieve scene key from config or active dictionary lookup
	var scene: PackedScene = null
	if is_instance_valid(config) and is_instance_valid(config.pooled_scene_key):
		scene = config.pooled_scene_key
	else:
		scene = _active_pooled_entities.get(entity_node, null) as PackedScene

	_active_pooled_entities.erase(entity_node)

	if is_instance_valid(scene):
		if not _pools.has(scene):
			_pools[scene] = []

		# Move to pool container to keep level tree clean
		if is_instance_valid(_pool_container) and entity_node.get_parent() != _pool_container:
			if entity_node.get_parent():
				entity_node.get_parent().remove_child(entity_node)
			_pool_container.add_child(entity_node)

		_pools[scene].append(entity_node)
	else:
		# Fallback if entity was not spawned via pool: queue_free safely
		entity_node.queue_free()


## Pre-warms the pool by instantiating instances ahead of time during loading
func prewarm(scene: PackedScene, count: int, parent: Node = null) -> void:
	if not is_instance_valid(scene) or count <= 0:
		return

	var target_parent = _pool_container if is_instance_valid(_pool_container) else parent
	if not _pools.has(scene):
		_pools[scene] = []

	for i in count:
		var inst = scene.instantiate()
		var config = _find_entity_config(inst)
		if is_instance_valid(config):
			config.is_active = false
			config.pooled_scene_key = scene

		inst.process_mode = PROCESS_MODE_DISABLED
		if inst is CanvasItem or inst is Node3D:
			inst.hide()

		target_parent.add_child(inst)
		_pools[scene].append(inst)


## Clears all inactive instances across all pools
func clear_all_pools() -> void:
	for scene in _pools:
		var pool_array: Array = _pools[scene]
		for inst in pool_array:
			if is_instance_valid(inst):
				inst.queue_free()
	_pools.clear()
	_active_pooled_entities.clear()


## Helper to set 2D or 3D global position
func _set_entity_position(entity: Node, global_pos: Vector2) -> void:
	if entity is Node2D:
		entity.global_position = global_pos
	elif entity is Node3D:
		entity.global_position = Vector3(global_pos.x, global_pos.y, 0.0)


## Helper to locate EntityConfig on an entity node
func _find_entity_config(entity: Node) -> EntityConfig:
	if entity is EntityConfig:
		return entity as EntityConfig
	if "config" in entity and entity.config is EntityConfig:
		return entity.config as EntityConfig
	for child in entity.get_children():
		if child is EntityConfig:
			return child as EntityConfig
	return null
