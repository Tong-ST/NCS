class_name SysTest
extends SystemBase


func setup_query() -> void:
	with_all([CompTest])


func ncs_process(entities: Array[Node], _data_pools: Array, _node_pools: Array, _delta: float) -> void:
	for i in entities.size():
		var ent = entities[i]
		if not is_instance_valid(ent): continue
