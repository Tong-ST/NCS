class_name S_Dead
extends NCSSystemBase

## Step 1: Explicitly configure entity query template on initialization
func setup_query() -> void:
	# Name of Components Matter!, Make sure they are the same in your scene node
	with_all([C_Dead])

## Step 2: Run your logic loop.
func _process(_delta: float) -> void:
	# Iterate through all filtered entities.
	for i in entities.size():
		# Pull essential body/data for this system
		var ent = entities[i]
		var body = ent.get_parent() as CharacterBody2D
		if not is_instance_valid(body): continue

		# In fact this queue_free() should deal on e.g. player.gd or C_Dead instead of here
		# for better control on animation, timer, etc., So this just for example.
		body.queue_free()
