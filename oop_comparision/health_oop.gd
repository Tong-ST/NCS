class_name HealthOOP
extends Node

@export var actor: Node
@export var max_health: float = 100.0

@onready var current_health: float = max_health

func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	if current_health <= 0.0:
		actor.queue_free()
