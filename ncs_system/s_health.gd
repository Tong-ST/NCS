class_name S_Health
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Health]).with_not([C_Dead]) # filter entities by components
	iterate_data([D_Health]) # caching data


func ncs_process(entities: Array[Node], data_pools: Array, _delta: float) -> void:
	if entities.is_empty(): return
	var current_entities = entities as Array[CharacterBody2D]
	var health_pool = data_pools[0] as Array[D_Health] # allocate data for current frame use
	if not health_pool: return

	var _pending_add_dead: Array[EntityConfig] = []

	# Iterate and fetching data process.
	for i in current_entities.size():
		var ent = current_entities[i]
		var health_data = health_pool[i]
		var config = config_pool[i]

		# Always safely check for data that you query, use "continue" to skip loop.
		if not is_instance_valid(ent) or not config or not health_data:
			continue

		if health_data.current_health <= 0:
			health_data.current_health = 0
			_pending_add_dead.append(config)

	# Example of doing batch update. 
	# If this system may have multiple ent. That may died update at one frame.
	# e.g. 500+ at once, Otherwise don't do batching it may slower and prone to bugs
	if not _pending_add_dead.is_empty():
		NCS.begin_batch()

		for config in _pending_add_dead:
			config.add_comp(C_Dead)
			config.remove_comp(C_Movement)

		NCS.end_batch() 
