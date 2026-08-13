class_name Player
extends CharacterBody2D

# Example on how to get all of your entities data to use outside of CustomSystem
@onready var ent: EntityConfig = $NCSEntityConfig


func _ready() -> void:
	pass
	# Get data by using entity_config.get_data("D_DataName")
	#var input_data = ent.get_data("D_Input") as D_Input
	#var movement_data = ent.get_data("D_Movement") as D_Movement

	#print("Player input_vector: ", input_data.movement_vector)
	#print("Player speed: ", movement_data.max_speed)
