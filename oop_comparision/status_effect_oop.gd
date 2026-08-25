class_name StatusEffectOOP
extends Node

signal on_poison_applied
signal on_poison_removed

@export var actor: Node
@export var health_comp: HealthOOP
@export var damage_per_sec: float = 10.0
@export var duration: float = 4.0
@export var tick_interval: float = 1.0

var is_poisoned: bool = false
var current_duration: float = 0.0
var tick_timer: float = 0.0


func apply_poison() -> void:
	if not is_poisoned:
		is_poisoned = true
		current_duration = duration
		tick_timer = 0.0
		on_poison_applied.emit()
		var actor_name = actor.get_script().get_global_name() if is_instance_valid(actor) and actor.get_script() else "EnemyOOP"
		print(actor_name, " Get poison!")
	else:
		# Reset duration if already poisoned
		current_duration = duration


func remove_poison() -> void:
	if is_poisoned:
		is_poisoned = false
		on_poison_removed.emit()
		var actor_name = actor.get_script().get_global_name() if is_instance_valid(actor) and actor.get_script() else "EnemyOOP"
		await get_tree().create_timer(1).timeout
		print("Poison was removed from ", actor_name)


func _process(delta: float) -> void:
	if not is_poisoned:
		return

	current_duration -= delta
	tick_timer += delta

	if tick_timer >= tick_interval:
		tick_timer -= tick_interval
		if is_instance_valid(health_comp):
			health_comp.take_damage(damage_per_sec)

	if current_duration <= 0.0:
		remove_poison()
