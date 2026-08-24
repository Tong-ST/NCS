class_name SysHealth
extends SystemBase


func setup_query() -> void:
	with_all([DataHealth]) # Can also filter by just Data or mix and match with Comp.
	iterate_data([DataHealth])  # caching data & filter all ent. must have these data.


func ncs_process(entities: Array[Node], data_pools: Array, _node_pools: Array, _delta: float) -> void:
	var current_entities = entities as Array[CharacterBody2D]
	var health_pool = data_pools[0] as Array[DataHealth] # allocate data for current frame use

	# Iterate and prepare data for each entity.
	for i in current_entities.size():
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		var health_data = health_pool[i]

		if health_data.current_health <= 0:
			# Change data and send signal to watch_data() in CompHealth.
			config[i].change_data(DataHealth, &"state", "DEAD")
