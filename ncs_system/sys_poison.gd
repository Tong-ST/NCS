class_name SysPoison
extends SystemBase


func setup_query() -> void:
	# You can also query by just Data no node component need for this system.
	# iterate_data also act like with_all() filter,
	# all data must exist in ent. Otherwise will not get filter.
	iterate_data([DataPoisonStatus, DataHealth]) # e.g. must have DataPoisonStatus and DataHealth.


func ncs_process(entities: Array[Node], data_pools: Array, _node_pools: Array, delta: float) -> void:
	var poison_pool = data_pools[0] as Array[DataPoisonStatus]
	var health_pool = data_pools[1] as Array[DataHealth]

	# Iterate backwards so removing data doesn't disrupt index positioning
	for i in range(entities.size() - 1, -1, -1):
		var ent = entities[i]
		if not is_instance_valid(ent): continue

		var poison = poison_pool[i]
		var health = health_pool[i]

		poison.duration -= delta
		poison.tick_timer += delta

		if poison.tick_timer >= poison.tick_interval:
			poison.tick_timer -= poison.tick_interval
			var new_hp = health.current_health - poison.damage_per_sec
			config[i].change_data(DataHealth, &"current_health", new_hp)

		if poison.duration <= 0.0:
			config[i].remove_data(DataPoisonStatus)
