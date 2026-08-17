extends Node2D

signal ent_changed

@onready var ncs_ent_count: Label = %NCSEntCount
@onready var oop_ent_count: Label = %OOPEntCount
@onready var perf_counter: Label = %PerfCounter

var total_ncs_count: int = 0
var total_oop_count: int = 0


func _ready() -> void:
	ent_changed.connect(_on_ent_changed)
	ent_changed.emit()

	# preload entity to pool (Optional)
	var enemy_scene = preload("uid://cvael67uegn6h")
	NCSEntityPool.prewarm(enemy_scene, 2000, self)


func _process(_delta: float) -> void:
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)

	perf_counter.text = "FPS: %d\nProcess: %.2f ms\nObjects: %d" % [fps, process_time, object_count]


func _on_ent_changed() -> void:
	ncs_ent_count.text = str("NCS Enemies: ", total_ncs_count)
	oop_ent_count.text = str("OOP Enemies: ", total_oop_count)


func _on_ncs_btn_pressed() -> void:
	# spawn NCS enemy using NCSEntityPool
	%NCSBtn.disabled = true
	var enemy_scene = preload("uid://cvael67uegn6h")
	var player = get_tree().get_first_node_in_group(&"player") as Player

	for i in range(50 * 4):
		await get_tree().process_frame
		
		for j in range(10):
			var spawn_pos = player.global_position if player else Vector2.ZERO
			# (Optional) using EntityPool for spawn entity.
			# Recommend Normal godot add_child if object don't neeed pooling.
			var enemy = NCSEntityPool.spawn(enemy_scene, spawn_pos, self) as Enemy
			enemy.c_health.take_damage(0) # You can then do something when those ent spawn
			total_ncs_count += 1
			ent_changed.emit()

	%NCSBtn.disabled = false


func _on_oop_btn_pressed() -> void:
	# spawn OOP enemy
	%OOPBtn.disabled = true
	var enemy_scene = preload("uid://lvup6a5nx615")
	var player = get_tree().get_first_node_in_group(&"player") as Player

	for i in range(50 * 4):
		await get_tree().process_frame
		
		for j in range(10):
			var spawn_pos = player.global_position if player else Vector2.ZERO
			var enemy = enemy_scene.instantiate() as EnemyOOP
			enemy.global_position = spawn_pos
			add_child(enemy)
			enemy.health_oop.take_damage(0)
			total_oop_count += 1
			ent_changed.emit()

	%OOPBtn.disabled = false
