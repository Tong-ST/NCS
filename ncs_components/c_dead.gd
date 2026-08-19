class_name C_Dead
extends NCSComponentBase

# This method will run when new component add to entity.
func _on_add_comp() -> void:
	print(owner_node.name, " is dead")

	# Example on how to remove it at runtime inside component.
	config.remove_comp(C_Health)
	config.remove_data(D_Health)
