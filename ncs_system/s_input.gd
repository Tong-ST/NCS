class_name S_Input
extends NCSSystemBase

## Step 1: Explicitly configure entity query template on initialization
func setup_query() -> void:
	# Name of Components Matter!, Make sure they are the same in your scene node
	with_all(["C_Input", "C_Health"]).with_not(["C_Dead"])

## Step 2: Run your logic loop.
func _process(_delta: float) -> void:
	# Check hardware input ONCE per frame, instead of inside the loop for optimization
	var deal_damage = Input.is_action_just_pressed("ui_accept")

	# Iterate through all filtered entities.
	for ent in entities:
		# Pull essential body/data for this system
		var body = ent.get_parent() as CharacterBody2D
		var input_data = ent.get_data("D_Input") as D_Input
		
		# Always safety check for those fetched data
		if not is_instance_valid(body) or not input_data: 
			continue

		# Logic input logic for all ent.
		# Example on how to get component from system and call some unique logic.
#		var health_comp = ent.get_comp("C_Health") as C_Health
#		if deal_damage and health_comp and health_comp.get_script() and health_comp is C_Health:
#			health_comp.take_damage(20)
#
		# Just use send_signal to call function inside comp which only have script attached
		if deal_damage:
			send_signal(ent, "C_Health", "take_damage", [20])
		
		# Logic below only for player. Basic movement control logic
		if not body is Player:
			continue

		var raw_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		input_data.movement_vector = raw_dir

		# I know player example here should not be in main system that shared
		# it also can be place in C_Input script that use only with player
		# but just want to show how we can wired thing together quickly.
