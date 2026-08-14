class_name Player
extends CharacterBody2D

# Example on how to get all of your entities data to use outside of CustomSystem
@onready var entity_config: EntityConfig = $EntityConfig
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var c_health: C_Health = $NCSComponentsHub/C_Health


func _ready() -> void:
	c_health.on_damaged.connect(_on_damaged)
	# Example on how to get data from entity_config
#	var input_data = entity_config.get_data(D_Input) as D_Input
#	var movement_data = entity_config.get_data(D_Movement) as D_Movement
#
#	print("Player input_vector: ", input_data.movement_vector)
#	print("Player speed: ", movement_data.max_speed)


func _on_damaged() -> void:
	if not is_instance_valid(sprite_2d):
		return
		
	var tween = create_tween()
	sprite_2d.modulate = Color.RED
	tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.05).set_delay(0.1)
