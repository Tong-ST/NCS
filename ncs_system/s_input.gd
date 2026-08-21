class_name S_Input
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Input]) # filter entities by components


func ncs_process(entities: Array[Node], _data_pools: Array, _node_pools: Array, _delta: float) -> void:
	var current_entities = entities as Array[CharacterBody2D]

	var deal_damage = Input.is_action_just_pressed("ui_accept")
	var add_posion = Input.is_action_just_pressed("ui_end")

	# Iterate and prepare data for each entity.
	for i in current_entities.size():
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		var config = config_pool[i]

		# Call a method inside component
		if deal_damage:
			config.call_method(C_Health, &"take_damage", [20])
			# More command e.g. add_comp, remove_comp, add_data, remove_data, etc.

		# Add data at runtime
		if add_posion:
			config.add_data(D_PoisonStatus)
