class_name C_Dead
extends NCSComponentBase

# This method will run first at new component attached to character.
func _init_comp() -> void:
	print(owner_node.name, " is dead")

	# We clearly don't have to manual remove_comp, data since it's dead script.
	# But just for example on how to remove it at runtime. In-case you need one.
	ent.remove_comp("C_Health")
	ent.remove_data("D_Health")
