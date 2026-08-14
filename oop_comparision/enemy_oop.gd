class_name EnemyOOP
extends CharacterBody2D

@export var max_speed: float = 150.0
@export var acceleration: float = 600.0
@export var is_aggressive: bool = true

var current_velocity: Vector2 = Vector2.ZERO

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_oop: HealthOOP = $Components/HealthOOP


func _ready() -> void:
	health_oop.on_damaged.connect(_on_damaged)


func _on_damaged() -> void:
	if not is_instance_valid(sprite_2d): 
		return

	var original_color = sprite_2d.modulate
	var tween = create_tween()
	sprite_2d.modulate = Color.RED
	tween.tween_property(sprite_2d, "modulate", original_color, 0.05).set_delay(0.1)
