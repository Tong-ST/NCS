class_name S_Dead
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Dead]) # filter entities with C_Dead tag


func ncs_process(entities: Array[Node], _data_pools: Array, _delta: float) -> void:
	if entities.is_empty(): return

	# Iterate in reverse for safer despawning/destroying entities
	for i in range(entities.size() - 1, -1, -1):
		var ent = entities[i]
		if not is_instance_valid(ent): continue
		
		ent.queue_free()
