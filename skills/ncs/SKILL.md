---
name: ncs
description: Comprehensive architecture guide, design patterns, rules, and cheatsheet for building games with the NCS (Node-based Component System) framework in Godot 4.
---

# NCS Framework — AI Agent & Developer Cheatsheet

The **NCS (Node-based Component System)** framework is a hybrid architectural pattern for Godot 4. It combines the visual ergonomics of Godot's Scene Tree with the decoupled scalability and batch iteration performance of Data-Driven / ECS architectures.

---

## 1. The Core Architecture & Mental Model

```
┌────────────────────────────────────────────────────────────────────────┐
│                               NCS WORLD                                │
│  ┌─────────────────────────┐             ┌───────────────────────────┐ │
│  │   SystemsFolder       	 │             │    SystemsFolder          │ │
│  │   ├─ SysInput (Process) │             │    ├─ SysHealth (Process) │ │
│  │   └─ SysMovement (Phys) │             │    └─ SysPoison (Process) │ │
│  └────────────┬────────────┘             └─────────────┬─────────────┘ │
└───────────────┼────────────────────────────────────────┼───────────────┘
                │ Batch iterates matched queries         │
                ▼                                        ▼
┌────────────────────────────────────────────────────────────────────────┐
│                              ENTITIES                                  │
│   CharacterBody2D (Entity Root)                                        │
│   ├── EntityConfig (Owns runtime data copy & component maps)           │
│   │     └── runtime_config: NCSEntityDataSet                           │
│   │           ├── DataMovement (Resource)                              │
│   │           └── DataHealth (Resource)                                │
│   └── ComponentsHub (Groups component nodes)                           │
│         ├── CompMovement (Node marker / local logic)                   │
│         └── CompHealth (Node marker / local logic)                     │
└────────────────────────────────────────────────────────────────────────┘
```

| Pillar | Base Class | Naming Convention | Role & Responsibility |
|---|---|---|---|
| **Entity** | `CharacterBody2D`, `Node2D`, `Node3D`, `RigidBody*` | `Player`, `Enemy`, etc. | The physical root GameObject in the Godot scene tree. |
| **EntityConfig** | `EntityConfig` | `EntityConfig` | Sits on the entity. Holds `base_config` blueprint, `entity_node` target, and isolated `runtime_config` copy. Manages $O(1)$ component/data maps and method dispatch. |
| **Data** | `NCSDataBase` | `Data*` (e.g. `DataHealth`) | **Pure Data Resources**. Contain numerical stats, states, and coordinates. Stored in `NCSEntityDataSet` (`.tres`) and duplicated per entity at spawn. |
| **Components** | `ComponentBase` | `Comp*` (e.g. `CompHealth`) | **Node Markers / Local Logic**. Placed inside `ComponentsHub`. Auto-wired with `entity_node` and `config`. Used for query filtering, VFX, audio, local UI, or signal observers. |
| **Systems** | `SystemBase` | `Sys*` (e.g. `SysMovement`) | **Global Logic Engines**. Placed inside `NCSWorld`. Filter entities via queries and execute batched loops over flat data arrays in `ncs_process()` or `ncs_physics_process()`. |
| **SystemManager** | `Node` (Autoload singleton) | `NCS` | Global singleton. Manages active entity registries, query updates, frame flush, batch auto-detection ($\ge 50$ changes), method calls, and safe spawn/despawn queues. |
| **SystemsFolder** | `SystemsFolder` | `SystemsFolder` | Empty visual grouping folder for organizing `SystemBase` children under an `NCSWorld` node. |

---

## 2. Standard Scene Tree Hierarchy

### A. Entity Scene (`Enemy.tscn` / `Player.tscn`)
```
Enemy (CharacterBody2D)
├── EntityConfig (EntityConfig)
│     ├── base_config: ExtResource("enemy_data_sets.tres")
│     └── entity_node: NodePath("..")
├── Sprite2D
├── CollisionShape2D
└── ComponentsHub (ComponentsHub)
      ├── entity_node: NodePath("..")
      ├── CompMovement (ComponentBase, require_data = true)
      ├── CompHealth (ComponentBase, require_data = true)
      └── CompEnemyAI (ComponentBase, require_data = true)
```

### B. World Scene (`Main.tscn`)
```
Main (Node2D)
├── NCSWorld (NCSWorld)
│     ├── CoreLoops (SystemsFolder)
│     │     ├── SysInput (SystemBase)
│     │     ├── SysMovement (SystemBase)
│     │     └── SysVisual (SystemBase)
│     └── GameplaySystems (SystemsFolder)
│           ├── SysEnemyAI (SystemBase)
│           ├── SysHealth (SystemBase)
│           └── SysPoison (SystemBase)
├── Player (Instance of player.tscn)
└── Enemies / Spawner
```

---

## 3. Step-by-Step Implementation Recipes

### Recipe 1: Creating a Data Block (`Data*`)
Data blocks are pure `Resource` classes that store state.

```gdscript
# res://ncs_data/data_health.gd
class_name DataHealth
extends NCSDataBase

## Exported variables: Configured in the .tres inspector
@export var max_health: float = 100.0

## Runtime variables: Modified dynamically by Systems
var current_health: float = 100.0
var status: String = "ALIVE"
```

> **Steps in Godot:**
> 1. Create a new `NCSEntityDataSet` resource (e.g. `res://ncs_data/enemy_data_sets.tres`).
> 2. Add an instance of `DataHealth` into the `data_sets` array of that `.tres` file.
> 3. Assign the `.tres` file to the `base_config` slot of the entity's `EntityConfig` node.

---

### Recipe 2: Creating a Component (`Comp*`)
Components are Node attachments. Use them for query tags, visual/audio triggers, or local signal watchers.

```gdscript
# res://ncs_components/comp_health.gd
class_name CompHealth
extends ComponentBase

signal on_damaged

## If true, editor validates that a matching DataHealth resource exists in EntityConfig.
@export var require_data: bool = true

## Local data cache (populated on init)
var health_data: DataHealth


## Called on ready once entity_node and config references are auto-wired.
func _on_init_comp() -> void:
	health_data = config.get_data(DataHealth) as DataHealth
	
	# Register observer callbacks on data fields
	config.watch_data(DataHealth, &"status", _on_status_changed)


## Example: Local method callable from systems or other components
## This example is not ideal using Write-data logic, It might conflict with system loops
## Be careful when mutating data directly in components. Prefer using Systems
## Keep components focus on Read-only data or local logic.
func take_damage(amount: float) -> void:
	if not health_data:
		health_data = config.get_data(DataHealth) as DataHealth
	if health_data:
		health_data.current_health -= amount
		on_damaged.emit()


## Triggered when status property changes to "DEAD"
func _on_status_changed(new_status: Variant) -> void:
	if new_status == "DEAD":
		# Safely despawn entity at end of frame
		NCS.despawn(entity_node)


## Called if this component is dynamically added at runtime via config.add_comp()
func _on_add_comp() -> void:
	print("Health component added to: ", entity_node.name)


## Called if this component is dynamically removed at runtime via config.remove_comp()
func _on_remove_comp() -> void:
	print("Health component removed from: ", entity_node.name)
```

---

### Recipe 3: Creating a System (`Sys*`)
Systems contain all gameplay logic and iterate entities in batch.

```gdscript
# res://ncs_system/sys_movement.gd
class_name SysMovement
extends SystemBase


## Declare query filters and data targets once on ready.
func setup_query() -> void:
	# Entity must have ALL of these components/data
	with_all([CompMovement])
	
	# Exclude entities with these components
	with_not([CompDead])
	
	# Pre-fetch data pools in index order:
	# data_pools[0] -> DataMovement
	# data_pools[1] -> DataInput
	iterate_data([DataMovement, DataInput])
	
	# (Optional) Pre-fetch node references:
	# node_pools[0] -> Sprite2D
	fetch_nodes([Sprite2D])


## Main physics tick: Runs at fixed physics rate
func ncs_physics_process(entities: Array[Node], data_pools: Array, node_pools: Array, delta: float) -> void:
	var body_pool = entities as Array[CharacterBody2D]
	var move_pool = data_pools[0] as Array[DataMovement]
	var input_pool = data_pools[1] as Array[DataInput]

	for i in body_pool.size():
		var ent = body_pool[i]
		if not is_instance_valid(ent):
			continue

		var move_data = move_pool[i]
		var input_data = input_pool[i]

		# Direct zero-allocation calculation
		var input_dir = input_data.movement_vector
		if input_dir != Vector2.ZERO:
			move_data.velocity = move_data.velocity.move_toward(
				input_dir * move_data.max_speed,
				move_data.acceleration * delta
			)
		else:
			move_data.velocity = move_data.velocity.move_toward(
				Vector2.ZERO,
				move_data.acceleration * delta
			)

		# Store position in data (separated from render transform)
		move_data.next_global_pos += move_data.velocity * delta
```

---

## 4. Runtime Operations & API Cheatsheet

### A. Spawning & Despawning Entities
Always use `NCS.spawn()` and `NCS.despawn()` during gameplay to ensure thread safety and deferred query synchronization.

```gdscript
# Spawning an entity safely into the scene tree:
NCS.spawn(
	enemy_scene,                 # PackedScene
	get_parent(),                # Parent node
	spawn_position,              # Vector2 or Vector3
	func(instance):              # (Optional) Setup callback
		instance.sprite_2d.modulate = Color.WHITE
)

# Despawning an entity safely:
NCS.despawn(enemy_node)          # Accepts CharacterBody2D or EntityConfig
```

---

### B. Reading & Mutating Data

```gdscript
# 1. Direct fetch (O(1) lookup):
var health_data = config.get_data(DataHealth) as DataHealth
health_data.current_health -= 25.0

# 2. Mutate with watcher notification:
config.change_data(DataHealth, &"status", "DEAD")

# 3. Dynamic Data Addition / Removal at runtime:
config.add_data(DataPoisonStatus)       # Instantiates and registers DataPoisonStatus
config.remove_data(DataPoisonStatus)    # Removes DataPoisonStatus and triggers re-query
```

---

### C. Data Watchers & Observer Pattern

```gdscript
# Watch a specific property on a data resource:
config.watch_data(DataHealth, &"status", func(new_status):
	print("Status changed to: ", new_status)
)

# Watch data addition and removal lifecycle:
config.watch_data_lifecycle(
	DataPoisonStatus,
	func(poison_data): print("Poison applied!"),
	func(poison_data): print("Poison removed!")
)
```

---

### D. Component Method Calling (Fast Dispatch)

NCS uses a pre-bound `Callable` cache for component method calls, eliminating runtime reflection.

```gdscript
# Immediate call:
config.call_method(CompHealth, &"take_damage", 20.0)

# Multi-argument call (pass as Array):
config.call_method(CompVFX, &"play_effect", ["slash", 1.5])

# Deferred call (queued safely to end of frame without closure allocations):
config.call_method_deferred(CompHealth, &"take_damage", 20.0)
```

---

### E. Runtime Component Mutations (Archetype Shifts)

```gdscript
# Dynamically attach a new component:
config.add_comp(CompDead)

# Dynamically remove a component:
config.remove_comp(CompMovement)
```

---
#### Add/remove System at runtime/via code.
```gdscript
# Add SysMovement to $NCSWorld Core Folder at index 2
NCS.add_system(SysMovement, $NCSWorld/CoreFolder, 2)

# Add to NCSWorld node at last child
NCS.add_system(SysMovement) # Duplicate system will be ignored.

# Remove selected system from NCSWorld
NCS.remove_system(SysMovement)
```
- You'll need to prepare e.g. sys_movement.gd with class_name `SysMovement`, No need to create scene or node, Just a script with class_name.
---
## 5. Architectural Rules & Best Practices for AI Agents

> [!IMPORTANT]
> Follow these strict guidelines when generating or refactoring NCS code:

### Rule 1: Where Logic Lives
* **Systems (`Sys*`)**: All batch processing, physics integration, AI targeting, damage calculations, and collision handling.
* **Components (`Comp*`)**: Local node-specific glue only (triggering a `GPUParticles2D`, playing an `AudioStreamPlayer2D`, updating a local `ProgressBar`, or listening to `watch_data`).
* **Data (`Data*`)**: State only. No game logic inside `Data*` classes.

### Rule 2: Zero-Allocation System Loops
* Always index directly into `data_pools[n][i]` inside `ncs_process` / `ncs_physics_process`.
* Never call `config.get_data()` or `config.get_comp()` inside high-frequency system loops, Except for optional data which don't need to be cached.
* Pre-assign class at start process e.g. `var move_pool = data_pools[0] as Array[DataMovement]` will be a bit faster than assign inside hot loop.

### Rule 3: Separate Simulation from Visual Syncing
* Compute movement/physics in `ncs_physics_process` (e.g. `SysMovement` calculating `move_data.next_global_pos`).
* Synchronize node transforms and camera culling in `ncs_process` (e.g. `SysVisual` setting `ent.global_position = move_data.next_global_pos`).

### Rule 4: Always Guard Instance Validity
* Systems iterate pooled arrays. Always add:
  ```gdscript
  if not is_instance_valid(ent):
      continue
  ```
  at the top of every entity loop.

### Rule 5: Pass Raw Arguments to `call_method`
* Write `config.call_method(CompHealth, &"take_damage", 20)` instead of `[20]`. Passing direct variants avoids allocating heap arrays on every call.

---

## 6. Framework API Quick Reference

| Class / Singleton | Method / Property | Description |
|---|---|---|
| `NCS` | `spawn(scene, parent, pos, cb)` | Safely instantiates and adds an entity. |
| `NCS` | `despawn(node_or_config)` | Safely unregisters and frees an entity at frame end. |
| `NCS` | `push_command(callable)` | Pushes a lambda/command to the deferred frame buffer. |
| `NCS` | `mark_dirty(entity, script)` | Queues single entity for deferred candidate re-evaluation. |
| `NCS` | `add_system(SystemBase)` | Adds a system at runtime. |
| `NCS` | `remove_system(SystemBase)` | Removes a system at runtime. |
| `EntityConfig` | `get_data(Script)` | Returns runtime data block in $O(1)$. |
| `EntityConfig` | `get_comp(Script)` | Returns component node in $O(1)$. |
| `EntityConfig` | `has_data(Script)` | Returns true if data type is present. |
| `EntityConfig` | `has_comp(Script)` | Returns true if component type is present. |
| `EntityConfig` | `change_data(Script, prop, val)` | Updates data field and notifies watchers. |
| `EntityConfig` | `watch_data(Script, prop, cb)` | Attaches observer callback to a data property. |
| `EntityConfig` | `watch_data_lifecycle(Script, add_cb, rem_cb)` | Attaches observers to data addition/removal. |
| `EntityConfig` | `add_comp(Script)` | Dynamically attaches component node at runtime. |
| `EntityConfig` | `remove_comp(Script)` | Dynamically removes component node at runtime. |
| `EntityConfig` | `add_data(Script)` | Dynamically appends data resource at runtime. |
| `EntityConfig` | `remove_data(Script)` | Dynamically removes data resource at runtime. |
| `EntityConfig` | `call_method(Script, name, arg)` | Invokes component method immediately via cached Callable. |
| `EntityConfig` | `call_method_deferred(Script, name, arg)` | Queues component method for deferred execution. |
| `SystemBase` | `with_all(Array[Script])` | Query: Entity must have all listed components/data. |
| `SystemBase` | `with_any(Array[Script])` | Query: Entity must have at least one listed type. |
| `SystemBase` | `with_not(Array[Script])` | Query: Entity must have none of the listed types. |
| `SystemBase` | `iterate_data(Array[Script])` | Pre-fetches typed data arrays into `data_pools`. |
| `SystemBase` | `fetch_nodes(Array)` | Pre-fetches child nodes into `node_pools`. |
| `SystemBase` | `config: Array[EntityConfig]` | Parallel array of EntityConfigs aligned with matched entities. |
| `ComponentBase` | `entity_node: Node` | Auto-wired parent entity body (CharacterBody2D, etc.). |
| `ComponentBase` | `config: EntityConfig` | Auto-wired sibling EntityConfig node. |
| `ComponentBase` | `require_data: bool` | Enables editor configuration warnings if Data* is missing. |
| `ComponentsHub` | `entity_node: Node` | Physical body of the entity this hub operates on. |
| `SystemsFolder` | `(Grouping Node)` | Organizational folder for grouping `SystemBase` nodes in `NCSWorld`. |
