class_name EnemyOOP
extends CharacterBody2D

@export var max_speed: float = 150.0
@export var acceleration: float = 600.0
@export var is_aggressive: bool = true

var current_wander_direction: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var choose_time_target: float = 0.0
var is_idling: bool = false


func _physics_process(delta: float) -> void:
	if not is_aggressive:
		velocity = Vector2.ZERO
		return

	state_timer += delta

	if state_timer >= choose_time_target:
		state_timer = 0.0
		choose_time_target = randf_range(1.5, 3.5)
		
		if randf() > 0.5:
			is_idling = true
			current_wander_direction = Vector2.ZERO
		else:
			is_idling = false
			var random_angle = randf_range(0.0, TAU)
			current_wander_direction = Vector2(cos(random_angle), sin(random_angle))

	var target_velocity = current_wander_direction * max_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	global_position += velocity * delta
