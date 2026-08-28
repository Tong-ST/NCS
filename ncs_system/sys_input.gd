class_name SysInput
extends SystemBase


func setup_query() -> void:
	with_all([DataInput]) # filter with just data.


func ncs_physics_process(entities: Array[Node], _delta: float) -> void:
	var deal_damage = Input.is_action_just_pressed("ui_accept")
	var add_poison = Input.is_action_just_pressed("ui_end")
	var add_test = Input.is_action_just_pressed("ui_page_up")
	var remove_test = Input.is_action_just_pressed("ui_page_down")

	if not (deal_damage or add_poison or add_test or remove_test):
			return

	# Iterate and prepare data for each entity.
	for i in entities.size():
		var ent = entities[i]
		if not is_instance_valid(ent): continue

		# Call a method inside component
		if deal_damage:
			# Recommend to use call_method_deferred for safely defer action to end of frame.
			# More command e.g. add_comp, remove_comp, add_data, remove_data, etc.
			# If want to pass multiple args use Array[args] e.g. [20, status, ...]
			config[i].call_method_deferred(CompHealth, &"take_damage", 20)

		# Add data at runtime
		if add_poison:
			config[i].add_data(DataPoisonStatus)

		if add_test:
			config[i].add_comp(CompTest)

		if remove_test:
			config[i].remove_comp(CompTest)
