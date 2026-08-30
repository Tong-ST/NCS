class_name SysHealth
extends SystemBase


func setup_query() -> void:
	with_all([DataHealth]) # Can also filter by just Data or mix and match with Comp.
	iterate_data([DataHealth])  # caching data & filter all ent. must have these data.


func ncs_physics_process(entities: Array[Node], _delta: float) -> void:
	var health_pool = data_pools[0] as Array[DataHealth] # allocate data for current frame use

	# Iterate and prepare data for each entity.
	for i in entities.size():
		var ent = entities[i]
		if not is_instance_valid(ent): continue

		var health_data = health_pool[i]

		if health_data.current_health <= 0:
			# Change data and send signal to watch_data() in CompHealth.
			configs[i].change_data(DataHealth, &"state", "DEAD")
