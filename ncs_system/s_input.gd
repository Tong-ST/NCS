class_name S_Input
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Input]).with_not([C_Dead]) # filter entities by components
	iterate_data([D_Input]) # caching data


func ncs_process(entities: Array[Node], data_pools: Array, _delta: float) -> void:
	var input_pool = data_pools[0] as Array[D_Input] # allocate data for current frame use

	var deal_damage = Input.is_action_just_pressed("ui_accept")

	# Iterate and fetching data process.
	for i in entities.size():
		var ent = entities[i] as CharacterBody2D
		var input_data = input_pool[i]
		var config = config_pool[i]

		# Always safely check for data that you query, use "continue" to skip loop.
		if not is_instance_valid(ent) or not input_data or not config:
			continue

		#  send_signal to call function inside component
		if deal_damage:
			config.send_signal(C_Health, &"take_damage", [20])
			# More command e.g. add_comp, remove_comp, add_data, remove_data, etc.
			# using via config.xxx()
