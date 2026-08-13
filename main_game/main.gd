extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		for i in range(100):
			var enemy = preload("uid://cvael67uegn6h").instantiate() as Enemy
			add_child(enemy)
