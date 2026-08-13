class_name S_Input
extends NCSSystemBase

## Step 1: Explicitly configure entity query template on initialization
func setup_query() -> void:
	# Name of Components Matter!, Make sure they are the same in your scene node
	with_all([C_Input]).with_not([C_Dead])
	iterate_data([D_Input])

## Step 2: Run your logic loop.
func _process(_delta: float) -> void:
	# Check hardware input ONCE per frame, instead of inside the loop for optimization
	var deal_damage = Input.is_action_just_pressed("ui_accept")
	var input_pool = get_data_pool(0)

	# Iterate through all filtered entities.
	for i in entities.size():
		# Pull essential body/data for this system
		var ent = entities[i]
		var body = ent.get_parent() as CharacterBody2D

		# Get data required data according with iterate_data() abrove.
		var input_data = input_pool[i] as D_Input

		# Always safety check for those fetched data
		if not is_instance_valid(body) or not input_data: 
			continue

		#  Send_signal to call function inside comp which only have script attached
		if deal_damage:
			send_signal(ent, C_Health, "take_damage", [20])
		
		# Logic below only for player. Basic movement control logic
		if not body is Player:
			continue

		var raw_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		input_data.movement_vector = raw_dir

		# I know player example here should not be in main system that shared
		# it also can be place in C_Input script that use only with player
		# but just want to show how we can wired thing together quickly.
