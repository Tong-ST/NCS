class_name SysTest
extends SystemBase


func setup_query() -> void:
	with_all([CompTest])

# To test add system at runtime 
# press "+" to this SysTest to NCS world at runtime. "-" to remove.
# press "PageUP" to add_comp(CompTest) to all ent.
# press "PageDown" to remove CompTest.
# see add_system code at main.tscn
func ncs_physics_process(entities: Array[Node], _data_pools: Array, _node_pools: Array, _delta: float) -> void:
	print('SysTest running')
	for i in entities.size():
		var ent = entities[i]
		if not is_instance_valid(ent): continue
