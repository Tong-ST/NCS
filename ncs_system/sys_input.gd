class_name SysInput
extends SystemBase


func setup_query() -> void:
	with_all([DataInput]) # filter with just data.


func ncs_process(entities: Array[Node], _data_pools: Array, _node_pools: Array, _delta: float) -> void:
	var current_entities = entities as Array[CharacterBody2D]

	var deal_damage = Input.is_action_just_pressed("ui_accept")
	var add_posion = Input.is_action_just_pressed("ui_end")
	var add_test = Input.is_action_just_pressed("ui_page_up")
	var remove_test = Input.is_action_just_pressed("ui_page_down")

	# Iterate and prepare data for each entity.
	for i in current_entities.size():
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		# Call a method inside component
		if deal_damage:
			# Recommend to use call_method_deferred for safely defer action to end of frame.
			# More command e.g. add_comp, remove_comp, add_data, remove_data, etc.
			# If want to pass multiple args use Array[args] e.g. [20, status, ...]
			config[i].call_method_deferred(CompHealth, &"take_damage", 20)

		# Add data at runtime
		if add_posion:
			config[i].add_data(DataPoisonStatus)

		if add_test:
			config[i].add_comp(CompTest)

		if remove_test:
			config[i].remove_comp(CompTest)
