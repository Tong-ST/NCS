class_name SysPoison
extends SystemBase


func setup_query() -> void:
	with_all([CompHealth])
	# iterate_data also act like with_all() filter,
	# all data must exist in ent. Otherwise will not get filter.
	iterate_data([DataPoisonStatus, DataHealth]) # must have DataPoisonStatus, DataHealth.


func ncs_physics_process(entities: Array[Node], delta: float) -> void:
	var poison_pool = data_pools[0] as Array[DataPoisonStatus]

	# Iterate backwards so removing data doesn't disrupt index positioning
	for i in range(entities.size() - 1, -1, -1):
		var ent = entities[i]
		if not is_instance_valid(ent): continue

		var poison = poison_pool[i]

		poison.duration -= delta
		poison.tick_timer += delta
		if poison.tick_timer >= poison.tick_interval:
			poison.tick_timer -= poison.tick_interval
			configs[i].call_method_deferred(CompHealth, &"take_damage", poison.damage_per_sec)

		if poison.duration <= 0.0:
			configs[i].remove_data(DataPoisonStatus)
