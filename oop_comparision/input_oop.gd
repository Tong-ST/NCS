class_name InputOOP
extends Node

@export var health_comp: HealthOOP

var movement_vector: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		health_comp.take_damage(20)
