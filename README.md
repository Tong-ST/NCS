# NCS
### Node-based Component System for Godot

A Bridge for Data-Oriented design for Godot. This plugin Is NOT try to be Pure ECS framework, But aim to make ECS workflow in godot less friction and encourage user build with hybrid approach.

## Core Pillar
- Data: Pure variable container untilize godot Resource, without any logic.
- Entity: Visual node/Your normal godot reuseable scene e.g. Player, Enemy.
- Components: A Tag and reuseable logics focus on local scene.
- System: Isolate node that process system-wide logic that need shared logic.


## How this work
### The Ideal scene tree layout
```text
Enemy (Entity)
├── EntityConfig (Data container)
├── Sprite2D & CollisionShape2D
└── NCSComponentsHub
	├── C_Movement (Script with/without logic)
	└── C_Input (Every component need it own script with class_name C_Component)
```

### 1. Data (Resource)
Data blocks contain only raw variables. They are written as custom script classes extending `NCSDataBase`.
```gdscript
class_name D_Movement
extends NCSDataBase

@export var max_speed: float = 150.0
@export var acceleration: float = 600.0

var velocity: Vector2 = Vector2.ZERO
```

### 2. Component (Node)
Components live in the scene tree under the `NCSComponentsHub` folder. They inherit from `NCSComponentBase` and handle strictly localized, visual tasks (like playing a sound, triggering particles, or running a hit-flash color tween).

```gdscript
class_name C_Health
extends NCSComponentBase

signal health_updated(current_hp: float)

@export var sprite_2d: Sprite2D

# Can also call from systems via config.send_signal()
func flash_red() -> void:
	if is_instance_valid(sprite_2d):
		var tween = create_tween()
		sprite_2d.modulate = Color.RED
		tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.05).set_delay(0.1)

# Freely write logic that should easily share with local scene.
func update_health() -> void:
	var health_data = config.get_data(D_Health) as D_Health
	health_updated.emit(health_data.current_health)
```

### 3. System (Node)
Systems are the "process" of your game architecture, Which will filter from components, to filtered arrays of entities, That you loop through and create game logic.

```gdscript
class_name S_Movement
extends NCSSystemBase

## Step 1: Query step filters and caches from components and data
func setup_query() -> void:
	with_all([C_Movement, C_Input]).with_not([C_Dead]) # filter for entities
	iterate_data([D_Movement, D_Input]) # caching data

## Step 2: Process the linear data stream sequentially
func ncs_physics_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	var move_pool = data_pools[0] # allocated data pool.
	var input_pool = data_pools[1] # with index accordingly to iterate_data() above
	
	# Iterate through all entities
	for i in frame_entities.size():
		# allocate data for each entities
		var ent = frame_entities[i] as CharacterBody2D
		var move_data = move_pool[i] as D_Movement
		var input_data = input_pool[i] as D_Input
		var config = config_pool[i] as EntityConfig

		# Always use safety check for data
		if not is_instance_valid(ent) or not move_data or not input_data:
			continue

		# Do system-wide logic of those ent.
		var current_input = input_data.movement_vector
		if current_input != Vector2.ZERO:
			move_data.velocity = move_data.velocity.move_toward(
				current_input * move_data.max_speed, 
				move_data.acceleration * delta
			)
		else:
			move_data.velocity = move_data.velocity.move_toward(Vector2.ZERO, move_data.acceleration * delta)
		ent.global_position += move_data.velocity * delta
```

#### Runtime Component mutations via system.
```gdscript
# Example your custom s_combat.gd system loop...
if target_enemy_health <= 0:
	config.add_comp(C_Dead)
	config.remove_comp(C_Movement)
	
	# Triggers a visual method into components.
	config.send_signal(C_Health, "flash_red")
```


### The layout on your game world
To activate your systems and allow your entities to be tracked automatically, you use an NCSWorld node inside your main level scene.
```gdscript
Level_Main
├── TileMap
├── Player
├── Enemy
└── NCSWorld
	├── CoreLoops (Just a folder)
	│   ├── S_Input (Your system script)
	│   └── S_Movement (Your system script)
	└── AISystems (folder)
		└── S_EnemyAI (Your system script)
```

## Installation
- Clone this git or download.
- In addons folder copy `ncs` to your godot project addons.
- Enable plugin via Project>Plugin>NCS

## Recommendation
- After you clone this project open Godot and import this project and to see full demo on how this plugin work.


### Credit
- This project inspired by [GECS](https://github.com/csprance/gecs) awesome ECS framework for godot
- Currently develop and maintain by me (GoodyWolf), If interest to contibute contact me at goodywolf101@gmail.com
