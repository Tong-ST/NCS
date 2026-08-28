class_name CompTest
extends ComponentBase


# This will NOT work for dynamically add.
func _on_init_comp() -> void:
	# This only work when placed manually at scene-tree.
	print('CompTest init')


# Use _on_add_comp() if this comp trigger via config.add_comp()
func _on_add_comp() -> void:
	print('CompTest added')


func _on_remove_comp() -> void:
	print('CompTest removed')
