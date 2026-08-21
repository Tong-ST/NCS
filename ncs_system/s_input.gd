class_name S_Input
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Input]).with_not([C_Dead]) # filter entities by components


func ncs_process(entities: Array[Node], _data_pools: Array, _node_pools: Array, _delta: float) -> void:
	if entities.is_empty(): return
	var current_entities = entities as Array[CharacterBody2D]

	var deal_damage = Input.is_action_just_pressed("ui_accept")
	var add_move = Input.is_action_just_pressed("ui_end")
	var remove_move = Input.is_action_just_pressed("ui_cancel")

	# Iterate and prepare data for each entity.
	for i in current_entities.size():
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		var config = config_pool[i]
		# Always safely check for data that you query, use "continue" to skip loop.
		if not config: continue

		#  send_signal to call function inside component
		if deal_damage:
			config.send_signal(C_Health, &"take_damage", [20])
			# More command e.g. add_comp, remove_comp, add_data, remove_data, etc.
		if add_move:
			config.add_comp(C_Movement)
		if remove_move:
			config.remove_comp(C_Movement)
