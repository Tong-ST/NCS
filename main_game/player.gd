class_name Player
extends CharacterBody2D

# Example on how to get all of your entities data to use outside of CustomSystem
@onready var entity_config: EntityConfig = $EntityConfig


func _ready() -> void:
	# Get data by using get ref. by entity_config.get_data("DataClassName")
	var input_data = entity_config.get_data("D_Input") as D_Input
	var movement_data = entity_config.get_data("D_Movement") as D_Movement

	print("Player input_vector: ", input_data.movement_vector)
	print("Player speed: ", movement_data.max_speed)
