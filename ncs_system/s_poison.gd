class_name S_Poison
extends NCSSystemBase


func setup_query() -> void:
	# You can also query by just D_Data no node component need for this system.
	# using iterate_data mean all ent. must have these data.
	# with_any([D_PoisonStatus, D_BurnStatus]) also work for query data.
	iterate_data([D_PoisonStatus, D_Health])


func ncs_process(entities: Array[Node], data_pools: Array, _node_pools: Array, delta: float) -> void:
	var poison_pool = data_pools[0] as Array[D_PoisonStatus]
	var health_pool = data_pools[1] as Array[D_Health]

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
			config_pool[i].change_data(D_Health, &"current_health", new_hp)

		if poison.duration <= 0.0:
			config_pool[i].remove_data(D_PoisonStatus)
