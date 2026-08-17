class_name C_Dead
extends NCSComponentBase

# This method will run first at new component attached to character.
func _init_comp() -> void:
	pass
	#print(owner_node.name, " is dead")

	# Example on how to remove it at runtime inside component.
	#config.remove_comp(C_Health)
	#config.remove_data(D_Health)
