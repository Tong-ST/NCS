# NCS
### Node-based Component System for Godot

Data-Oriented design bridge for Godot. This plugin are NOT try to be Pure ECS framework, But aim to make ECS workflow in godot with less friction and encourage user to build good architect with hybrid approach.

## Core
- Entity: Normal godot reuseable scene e.g. Player, CharacterBody2D, etc.
- Data: Pure variable container for data resource, without any logic.
- Components: A Tag for query by system and reuseable logics focus on local scene.
- System: Isolate node that process system-wide logic which need to share across the your game world.


## How this work
### The Ideal scene tree layout
```text
Enemy (Entity can be CharacterBody2D, Node3D, etc.)
|-- EntityConfig (Data container)
|-- Sprite2D, etc.
|-- ComponentsHub (Hub for all comp.)
	|-- CompMovement (Every comp need a script and class_name with/without logic)
	|-- CompInput
```

### 1. Data (Resource)
Data blocks contain only raw variables. They are written as custom script classes extending `NCSDataBase`.
```gdscript
class_name DataMovement
extends NCSDataBase

@export var max_speed: float = 150.0
@export var acceleration: float = 600.0

var velocity: Vector2 = Vector2.ZERO
```
- Naming convention for ease of use and remember `DataName` for class_name, data_name.gd for template.


### 2. Component (Node)
Components live in the scene tree under the `ComponentsHub` folder. They inherit from `ComponentBase` and handle localized, visual tasks (like playing a sound, triggering particles, or running a hit-flash color tween).

```gdscript
# You can put logics in component with Native godot style.
# Make sure there focus on local scene.
# Avoid run process loop inside each comp.
# Avoid Write to DataName that may use in system,
# Make habit of Read-only from DataName to avoid conflict with SysSystem. 

class_name CompHealth
extends ComponentBase

signal health_updated(current_hp: float)

@export var sprite_2d: Sprite2D


# Can also call from systems via config.call_method()
func flash_red() -> void:
	if is_instance_valid(sprite_2d):
		var tween = create_tween()
		sprite_2d.modulate = Color.RED
		tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.05).set_delay(0.1)

# Recommend to read-only from Data to update in scene-tree.
func update_health() -> void:
	var health_data = config.get_data(DataHealth) as DataHealth
	health_updated.emit(health_data.current_health)
```
- Naming convention for ease of use and remember `CompComponent` for class_name, comp_component.gd for scripts.
- Local Comp should focus on Read-Only from Data, And let system handle write to data.


### 3. System (Node)
Systems are the "process" of your game architecture, Which will filter from components, to filtered arrays of entities, That you loop through and create game logic.

```gdscript
class_name SysMovement
extends SystemBase

## Query step filters and caches from components and data
func setup_query() -> void:
	with_all([CompMovement]).with_not([CompDead, DataStun]) # filter for entities, by components/data.
	iterate_data([DataMovement, DataInput]) # caching data and all data must exist in entity.

## Iterated through all filtered entities.
func ncs_physics_process(entities: Array[Node], data_pools: Array, delta: float) -> void:
	# Assign CharacterBody2D, In-case you need specific access e.g. global_position, move_and_slide(), etc.
	var current_entities = entities as Array[CharacterBody2D] 
	var move_pool = data_pools[0] as Array[DataMovement] # allocated data pool.
	var input_pool = data_pools[1] as Array[DataInput] # with index accordingly to iterate_data() above
	
	# Iterate through all entities
	for i in current_entities.size():
		# allocate data for each entities
		var ent = current_entities[i]
		if not is_instance_valid(ent): continue

		var move_data = move_pool[i]
		var input_data = input_pool[i]

		# Do regular logic.
		var current_input = input_data.movement_vector
		if current_input != Vector2.ZERO:
			move_data.velocity = move_data.velocity.move_toward(
					current_input * move_data.max_speed, 
					move_data.acceleration * delta
			)
		else:
			move_data.velocity = move_data.velocity.move_toward(
					Vector2.ZERO,
					move_data.acceleration * delta
			)
		# In real usecase Recommend to separate pure data calculation and scene-tree update.
		ent.velocity = move_data.velocity
		ent.move_and_slide()
```


#### Runtime Component mutations via system.
```gdscript
# Example your custom s_combat.gd system loop...

if target_enemy_health <= 0:
	config[i].add_comp(CompDead)
	config[i].remove_comp(CompMovement)
	
	# Triggers a visual method in your local components.
	config[i].call_method_deferred(CompHealth, &"flash_red")
```
- Naming convention for ease of use and remember `SysSystem` for class_name, sys_system.gd for scripts.


### Query Filtering & Pre-fetched

System queries are configured in `setup_query()` using method chaining. You can filter entities by their attached components and pre-fetch resources or scene nodes directly into process pools.


#### Filtering Entities
* `with_all([CompMove, CompInput])`: Entity **must have all** listed components/data.
* `with_any([DataPoison, DataFreeze])`: Entity **must have at least one** of the listed components/data.
* `with_not([CompDead, DataStun])`: Entity **must not have** any of the listed components/data.


#### Pre-fetched Data & Nodes
* `iterate_data([DataMove, DataInput])`: Populates `data_pools[n]` and all data must exist in entity, Act like `with_all()` filter for data.
* `fetch_nodes([Sprite2D, AnimationPlayer])`: Populates `node_pools[n]` with references to optional internal sub-nodes (returns `null` if not found).
* `config`: Built-in array providing direct access to each matched entity's `EntityConfig` without setup.


#### Example
```gdscript
class_name SysRender
extends SystemBase

func setup_query() -> void:
    with_all([CompMovement]).with_any([DataPoison, DataFreeze]).with_not([CompDead, DataStun])
    iterate_data([DataMovement])
    fetch_nodes([Sprite2D, AnimationPlayer])

func ncs_process(entities: Array[Node], data_pools: Array, node_pools: Array, delta: float) -> void:
    var move_pool = data_pools[0] as Array[DataMovement]
    var sprite_pool = node_pools[0] as Array[Sprite2D]
    var anim_pool = node_pools[1] as Array[AnimationPlayer]

    for i in entities.size():
        var move_data = move_pool[i]
        var sprite = sprite_pool[i]
        var anim = anim_pool[i]

        if move_data and sprite:
            sprite.flip_h = move_data.velocity.x < 0
```
- You can still do e.g. `ent.get_node_or_null("Sprite2D")`, `config[i].get_comp(CompMove), config[i].get_data(DataMove)` at process if you don't want pre-fetched, But make sure to safety check inside loop if you do dynamically fetch e.g. `if not move_data: continue`


### The layout on your game world
To activate your systems and allow your entities to be tracked automatically, you use an NCSWorld node inside your main level scene.
```text
Level_Main
|-- TileMap
|-- Player
|-- Enemy
|-- NCSWorld
	|-- CoreLoops (Just a folder)
	|   |-- SysInput (Your system script)
	|   |-- SysMovement (Your system script)
	|-- AISystems (folder)
		|-- SysEnemyAI (Your system script)
```

## Installation
- Clone this git or download zip.
- In addons folder copy `ncs` to your godot project addons.
- Enable plugin via Project>Plugin>NCS
- Make sure `NCS` autoload enable via Project>Globals


## Use with AI Agents
- If you're develop a game with AI agents you can add [SKILL.md](skills/ncs/SKILL.md) to your AI agents.
- SKILL.md also act as developer cheatsheet, You can get overview of this project workflow there.


## Recommendations
- After you clone this project open Godot and import this project and to see full demo on how this plugin work.
- You may not expect to gain huge performance boost from this plugin, Just unified architecture it is.


### Credits & Contibute
- This project inspired by [GECS](https://github.com/csprance/gecs) awesome ECS framework for godot
- Currently develop and maintain by me (GoodyWolf), If interest to contibute contact me at goodywolf101@gmail.com
