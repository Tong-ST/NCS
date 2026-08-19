class_name Enemy
extends CharacterBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var entity_config: EntityConfig = $EntityConfig
@onready var c_health: C_Health = $NCSComponentsHub/C_Health


func _ready() -> void:
	c_health.on_damaged.connect(_on_damaged)


func _on_damaged() -> void:
	if not is_instance_valid(sprite_2d): 
		return

	var tween = create_tween()
	sprite_2d.modulate = Color.RED
	tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.05).set_delay(0.1)
