class_name MovementOOP
extends Node

@export var actor: EnemyOOP
@export var input_comp: InputOOP


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(input_comp):
		return

	if not actor.is_aggressive:
		actor.current_velocity = Vector2.ZERO
		return

	var current_input = input_comp.movement_vector

	if current_input != Vector2.ZERO:
		actor.current_velocity = actor.current_velocity.move_toward(
			current_input * actor.max_speed,
			actor.acceleration * delta
		)
	else:
		actor.current_velocity = actor.current_velocity.move_toward(
			Vector2.ZERO,
			actor.acceleration * delta
		)

	# Seed position on first frame using bool flag, not zero check
	if not actor.is_pos_initialized:
		actor.next_global_pos = actor.global_position
		actor.is_pos_initialized = true

	# Simulate movement purely in data (VisualOOP handles scene-tree sync)
	actor.next_global_pos += actor.current_velocity * delta
