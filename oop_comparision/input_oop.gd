class_name InputOOP
extends Node

@export var health_comp: HealthOOP
@export var status_effect_comp: StatusEffectOOP

var movement_vector: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if is_instance_valid(health_comp):
			health_comp.take_damage(20)
	elif event.is_action_pressed("ui_end"):
		if is_instance_valid(status_effect_comp):
			status_effect_comp.apply_poison()
