class_name EnemyOOP
extends CharacterBody2D

@export var max_speed: float = 150.0
@export var acceleration: float = 600.0
@export var is_aggressive: bool = true

var current_velocity: Vector2 = Vector2.ZERO
