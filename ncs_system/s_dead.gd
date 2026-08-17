class_name S_Dead
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Dead]) # filter entities with C_Dead tag


func ncs_process(entities: Array[Node], _data_pools: Array, _delta: float) -> void:
	if entities.is_empty():
		return

	var _pending_despawn: Array[EntityConfig] = []

	# Iterate in reverse for safer despawning/destroying entities
	for i in range(entities.size() - 1, -1, -1):
		var ent = entities[i] as CharacterBody2D
		if not is_instance_valid(ent): 
			continue

		var config = config_pool[i] as EntityConfig
		if is_instance_valid(config):
			_pending_despawn.append(config)
		else:
			ent.queue_free()

	# Example for doing batch update. Recommend for system may have multiple entity
	# Update they components, spawn, despawn at one frame. Otherwise it slower that normal
	# Another word, It will wait for finish this loop before it re-query system, 
	# So you may Experience unexpected behavior.
	if not _pending_despawn.is_empty():
		NCS.begin_batch()

		for config in _pending_despawn:
			config.despawn()

		NCS.end_batch() 
