class_name Player
extends CharacterBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var entity_config: EntityConfig = $EntityConfig
@onready var c_player: C_Player = $NCSComponentsHub/C_Player
@onready var c_health: C_Health = $NCSComponentsHub/C_Health


func _ready() -> void:
	c_health.on_damaged.connect(_on_damaged)
	
	# Example on how to get data from entity_config
	var movement_data = entity_config.get_data(D_Movement) as D_Movement
	print("Current Speed: ", movement_data.max_speed)


func _physics_process(_delta: float) -> void:
	c_player.get_player_input()


func _on_damaged() -> void:
	if not is_instance_valid(sprite_2d):
		return
		
	var tween = create_tween()
	sprite_2d.modulate = Color.RED
	tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.05).set_delay(0.1)
