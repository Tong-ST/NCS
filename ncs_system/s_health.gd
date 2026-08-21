class_name S_Health
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Health]) # filter entities by components
	iterate_data([D_Health])  # caching data & filter all ent. must have these data.


func ncs_process(entities: Array[Node], data_pools: Array, _node_pools: Array, _delta: float) -> void:
	var current_entities = entities as Array[CharacterBody2D]
	var health_pool = data_pools[0] as Array[D_Health] # allocate data for current frame use

	# Example on batching comp mutation.
	#var _pending_remove_comp: Array[EntityConfig] = []

	# Iterate and prepare data for each entity.
	for i in current_entities.size():
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		var health_data = health_pool[i]
		var config = config_pool[i]

		if health_data.current_health <= 0:
			# Change data and send signal to watch_data() in C_Health.
			config.change_data(D_Health, &"status", "DEAD")

			#_pending_remove_comp.append(config)

	# Example of doing batch update.
	# If this system may have multiple ent. That may died update at one frame.
	# e.g. 500+ at once, Otherwise don't do batching it may slower and prone to bugs
	# This batching is unnecessary for most use-cases, This just for demonstrate.
#	if not _pending_remove_comp.is_empty():
#		NCS.begin_batch()
#
#		for config in _pending_remove_comp:
#			config.remove_comp(C_Movement)
#
#		NCS.end_batch()
