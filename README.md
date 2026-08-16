# NCS
### Node-based Component System for Godot

Data-Oriented design bridge for Godot. This plugin are NOT try to be Pure ECS framework, But aim to make ECS workflow in godot with less friction and encourage user to build good architect with hybrid approach.

## Core
- Entity: Normal godot reuseable scene e.g. Player, Enemy, etc.
- Data: Pure variable container untilize godot Resource, without any logic.
- Components: A Tag for query by system and reuseable logics focus on local scene.
- System: Isolate node that process system-wide logic which need to share across the your game world.


## How this work
### The Ideal scene tree layout
```text
Enemy (Entity can be Char2d, Node, etc.)
|-- EntityConfig (Data container)
|-- Sprite2D, etc.
|-- NCSComponentsHub (Hub for all comp.)
	|-- C_Movement (Every comp need a script with/without logic)
	|-- C_Input
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
- Naming convention for ease of use and remember `D_Data` for class_name, d_data.gd for template.

### 2. Component (Node)
Components live in the scene tree under the `NCSComponentsHub` folder. They inherit from `NCSComponentBase` and handle localized, visual tasks (like playing a sound, triggering particles, or running a hit-flash color tween).

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

# Freely to write logic that should easily share with local scene.
func update_health() -> void:
	var health_data = config.get_data(D_Health) as D_Health
	health_updated.emit(health_data.current_health)
```
- Naming convention for ease of use and remember `C_Component` for class_name, c_component.gd for scripts.

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
	for i in entities.size():
		# allocate data for each entities
		var ent = entities[i] as CharacterBody2D
		var move_data = move_pool[i] as D_Movement
		var input_data = input_pool[i] as D_Input

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
var config = config_pool[i] as EntityConfig # Get a config of each entity.

if target_enemy_health <= 0:
	config.add_comp(C_Dead)
	config.remove_comp(C_Movement)
	
	# Triggers a visual method in your local components.
	config.send_signal(C_Health, "flash_red")
```
- Naming convention for ease of use and remember `S_System` for class_name, s_system.gd for scripts.

### The layout on your game world
To activate your systems and allow your entities to be tracked automatically, you use an NCSWorld node inside your main level scene.
```text
Level_Main
|-- TileMap
|-- Player
|-- Enemy
|-- NCSWorld
	|-- CoreLoops (Just a folder)
	|   |-- S_Input (Your system script)
	|   |-- S_Movement (Your system script)
	|-- AISystems (folder)
		|-- S_EnemyAI (Your system script)
```

## Extra Tool: Object Pooling (`NCSEntityPool`)
NCS includes built-in Object Pool system to help with frame stutter during mass spawning or bullet hell / wave games.

It's **optional and decoupled**: you can freely choose to use normal Godot `instantiate()` + `add_child()`, or use `NCSEntityPool` whenever you want pooling system.

### 1. Pre-warm entities (Optional)
Instantiate entities ahead of time during loading to avoid runtime instantiation lag:
```gdscript
# In your level _ready() or loading screen:
var enemy_scene = preload("res://enemy.tscn")
NCSEntityPool.prewarm(enemy_scene, 500, parent_node)
```

### 2. Spawning from Pool
Spawn a pre-warmed entity (or instantiates a new one automatically if the pool is empty):
```gdscript
# Spawns entity, sets position, resets data, and registers with NCS systems
var enemy = NCSEntityPool.spawn(enemy_scene, spawn_position, self)
```

### 3. Despawning / Returning to Pool
When an entity dies or despawns:
```gdscript
# In your entity, component, or system (e.g. S_Dead):
config.despawn() # Automatically returns to pool if pooled, or queue_free() fallback
```
Or despawn directly via the pool manager:
```gdscript
NCSEntityPool.despawn(enemy_node)
```

### Object pooling is Optional:
- **Fallback Safe**: If you spawn an entity normally with `instantiate()` and call `config.despawn()`, it safely falls back to standard `queue_free()`.
- **Only use with Entity** Don't use object pooling system for your normal scene that doesn't register to NCSEntity (Use only scene with EntityConfig, And NCSComponentsHub)


## Installation
- Clone this git or download zip.
- In addons folder copy `ncs` to your godot project addons.
- Enable plugin via Project>Plugin>NCS
- Make sure `NCS` and `NCSEntityPool` autoload enable via Project>Globals

## Recommendation
- After you clone this project open Godot and import this project and to see full demo on how this plugin work.
- You may not expect to gain huge performance boost from this plugin, Just unified architecture it is.


### Credit
- This project inspired by [GECS](https://github.com/csprance/gecs) awesome ECS framework for godot
- Currently develop and maintain by me (GoodyWolf), If interest to contibute contact me at goodywolf101@gmail.com
