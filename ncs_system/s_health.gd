class_name S_Health
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Health]).with_not([C_Dead]) # filter entities by components
	iterate_data([D_Health]) # caching data


func ncs_process(entities: Array[Node], data_pools: Array, _delta: float) -> void:
	var health_pool = data_pools[0] # allocate data for current frame use

	var _pending_add_dead: Array[EntityConfig] = []

	# Iterate and fetching data process.
	for i in entities.size():
		var ent = entities[i] as CharacterBody2D
		var health_data = health_pool[i] as D_Health
		var config = config_pool[i] as EntityConfig

		# Always safely check for data that you query, use "continue" to skip loop.
		if not is_instance_valid(ent) or not config or not health_data:
			continue

		if health_data.current_health <= 0:
			health_data.current_health = 0
			_pending_add_dead.append(config)

	# Example of doing batch update. 
	# If this system may have multiple ent. That may died update at one frame.
	# e.g. 200+ at once, Otherwise don't do batching it might be slower.
	if not _pending_add_dead.is_empty():
		NCS.begin_batch()

		for config in _pending_add_dead:
			config.add_comp(C_Dead)
			config.remove_comp(C_Movement)

		NCS.end_batch() 
