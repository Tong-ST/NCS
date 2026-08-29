class_name Player
extends CharacterBody2D

# Non-NCS variable for save/load example with NCS
var score: int = 0

var _timer: float = 0.0

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var entity_config: EntityConfig = $EntityConfig
@onready var comp_player: CompPlayer = $ComponentsHub/CompPlayer
@onready var comp_health: CompHealth = $ComponentsHub/CompHealth
@onready var comp_saveable: CompSaveable = $ComponentsHub/CompSaveable


func _ready() -> void:
	comp_health.on_damaged.connect(_on_damaged)
	# Example on connect non-NCS Data use with NCS save/load helper
	comp_saveable.save_data_requested.connect(_on_saved)
	comp_saveable.load_data_requested.connect(_on_loaded)

	# Example on how to get data from entity_config
	var movement_data = entity_config.get_data(DataMovement) as DataMovement
	print("Current Speed: ", movement_data.max_speed)


func _physics_process(delta: float) -> void:
	comp_player.get_player_input()

	_timer += delta
	if _timer >= 5.0:
		_timer = 0
		score += 100
		print("Player score: ", score)

func _on_damaged() -> void:
	if not is_instance_valid(sprite_2d):
		return

	var tween = create_tween()
	sprite_2d.modulate = Color.RED
	tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.05).set_delay(0.1)


## Example on store extra non NCS-Data on saved.
func _on_saved(extra_data: Dictionary) -> void:
	extra_data["score"] = score


## Example on custom method to apply data back once loaded.
func _on_loaded(extra_data: Dictionary) -> void:
	if extra_data.has("score"):
		score = extra_data["score"]
		print("Player score: ", score)
