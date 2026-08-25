class_name HealthOOP
extends Node

signal on_damaged

@export var actor: Node
@export var max_health: float = 100.0

@onready var current_health: float = max_health


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	# Print health status after damage (mirrors CompHealth)
	var actor_name = "EnemyOOP"
	if is_instance_valid(actor) and actor.get_script():
		actor_name = actor.get_script().get_global_name()
	print(actor_name, " HP:", int(current_health), "/", int(max_health))
	on_damaged.emit()
	if current_health <= 0.0:
		actor.queue_free()
