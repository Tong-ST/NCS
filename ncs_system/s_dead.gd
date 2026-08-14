class_name S_Dead
extends NCSSystemBase


func setup_query() -> void:
	with_all([C_Dead]) # filter entites with components


func ncs_process(entites: Array[Node], _data_pools: Array, _delta: float) -> void:
	# Iterate through all filtered entities.
	for i in entites.size():
		var ent = entites[i] as CharacterBody2D
		if not is_instance_valid(ent): continue

		# In fact this queue_free() should deal on e.g. player.gd or C_Dead instead of here
		# for better control on animation, timer, etc., So this just for example.
		ent.queue_free()
