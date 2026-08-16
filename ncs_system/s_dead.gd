class_name S_Dead
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Dead]) # filter entites with components


func ncs_process(entites: Array[Node], _data_pools: Array, _delta: float) -> void:
	# Iterate in reverse when despawning/destroying entities
	for i in range(entites.size() - 1, -1, -1):
		var ent = entites[i] as CharacterBody2D
		if not is_instance_valid(ent): continue

		var config = config_pool[i] as EntityConfig
		if is_instance_valid(config):
			config.despawn()
		else:
			ent.queue_free()
