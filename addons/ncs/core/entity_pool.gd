# Copyright (c) 2026 GoodyWolf / Tong-ST.
# Distributed under the terms of the MIT License.
# See LICENSE for more information.

# NCS object pool singleton (autoload as "NCSEntityPool"). Works with any Godot Node.
# Completely optional — mix freely with normal instantiate/queue_free if preferred.
#
# Usage:
#   NCSEntityPool.spawn(enemy_scene, global_position, get_parent())
#   NCSEntityPool.despawn(enemy_node)
#   NCSEntityPool.prewarm(enemy_scene, 50)  # call during loading screen

extends Node

var _pools: Dictionary = {}
var _active_pooled_entities: Dictionary = {}
var _pool_container: Node


func _ready() -> void:
	_pool_container = Node.new()
	_pool_container.name = "__NCSEntityPoolContainer__"
	add_child(_pool_container)


## Spawns one entity. Reuses a pooled inactive instance if available, instantiates fresh otherwise.
## Position is set before add_child to avoid frame-zero position glitches in visual systems.
## Usage: var enemy = NCSEntityPool.spawn(enemy_scene, global_position, get_parent())
func spawn(scene: PackedScene, global_pos: Vector2 = Vector2.ZERO, parent: Node = null) -> Node:
	if not is_instance_valid(scene):
		push_error("NCSEntityPool Error: Cannot spawn invalid PackedScene!")
		return null

	var entity: Node = null
	if not _pools.has(scene):
		_pools[scene] = []
	var pool_array: Array = _pools[scene]

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

		if entity.get_parent() != target_parent:
			if entity.get_parent():
				entity.get_parent().remove_child(entity)

			target_parent.add_child(entity)

		_set_entity_position(entity, global_pos)

		entity.process_mode = PROCESS_MODE_INHERIT
		if entity is CanvasItem or entity is Node3D:
			entity.show()

		# reset_data runs AFTER position is set — systems must not read Vector2.ZERO on frame 1.
		if is_instance_valid(config):
			config.reset_data()
			NCS.register_entity(config)
	else:
		entity = scene.instantiate()
		var config = _find_entity_config(entity)
		if is_instance_valid(config):
			config.is_active = true
			config.pooled_scene_key = scene

		_set_entity_position(entity, global_pos)
		target_parent.add_child(entity)

	_active_pooled_entities[entity] = scene
	return entity


## Returns entity to the pool: disables processing, hides, unregisters from NCS.
## Falls back to queue_free if the entity was not spawned via this pool.
## Usage: NCSEntityPool.despawn(enemy_node)
func despawn(entity_node: Node) -> void:
	if not is_instance_valid(entity_node):
		return

	var config = _find_entity_config(entity_node)
	if is_instance_valid(config):
		config.is_active = false
		NCS.unregister_entity(config)

	entity_node.process_mode = PROCESS_MODE_DISABLED

	if entity_node is CanvasItem or entity_node is Node3D:
		entity_node.hide()

	var scene: PackedScene = null
	if is_instance_valid(config) and is_instance_valid(config.pooled_scene_key):
		scene = config.pooled_scene_key
	else:
		scene = _active_pooled_entities.get(entity_node, null) as PackedScene

	_active_pooled_entities.erase(entity_node)

	if is_instance_valid(scene):
		if not _pools.has(scene):
			_pools[scene] = []
		if is_instance_valid(_pool_container) and entity_node.get_parent() != _pool_container:
			if entity_node.get_parent():
				entity_node.get_parent().remove_child(entity_node)
			_pool_container.add_child(entity_node)
		_pools[scene].append(entity_node)
	else:
		entity_node.queue_free()


## Pre-fills the pool with count inactive instances. Call during loading to avoid spawn hitches.
## Usage: NCSEntityPool.prewarm(enemy_scene, 50)
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


## Frees all inactive pooled instances and clears tracking state.
## Call on scene transitions to avoid carrying stale instances across levels.
func clear_all_pools() -> void:
	for scene in _pools:
		for inst in _pools[scene]:
			if is_instance_valid(inst):
				inst.queue_free()
	_pools.clear()
	_active_pooled_entities.clear()


## Sets global position for Node2D or Node3D (maps Vector2 to XY, Z=0 for 3D).
func _set_entity_position(entity: Node, global_pos: Vector2) -> void:
	if entity is Node2D:
		entity.global_position = global_pos
	elif entity is Node3D:
		entity.global_position = Vector3(global_pos.x, global_pos.y, 0.0)


## Finds the EntityConfig child of an entity. Checks: entity itself, entity.config, children.
func _find_entity_config(entity: Node) -> EntityConfig:
	if entity is EntityConfig:
		return entity as EntityConfig

	if "config" in entity and entity.config is EntityConfig:
		return entity.config as EntityConfig

	for child in entity.get_children():
		if child is EntityConfig:
			return child as EntityConfig
	return null
