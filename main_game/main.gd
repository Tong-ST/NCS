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


func _process(_delta: float) -> void:
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)

	perf_counter.text = "FPS: %d\nProcess: %.2f ms\nPhysics Process: %.2f ms\nObjects: %d" % [fps, process_time, physics_time, object_count]


func _on_ent_changed() -> void:
	ncs_ent_count.text = str("NCS Enemies: ", total_ncs_count)
	oop_ent_count.text = str("OOP Enemies: ", total_oop_count)


func _on_ncs_btn_pressed() -> void:
	# spawn NCS enemy
	%NCSBtn.disabled = true
	var enemy_scene = preload("uid://cvael67uegn6h")
	var player = get_tree().get_first_node_in_group(&"player") as Player

	for i in range(50 * 4):
		await get_tree().process_frame
		
		for j in range(10):
			var spawn_pos = player.global_position if player else Vector2.ZERO
			
			# Safely spawn new entity to world use:
			# NCS.spawn(scene, parent_node, position, custom_setup if needed)
			NCS.spawn(enemy_scene, get_parent(), spawn_pos,
				func(enemy_node: Enemy):
					enemy_node.sprite_2d.modulate = Color.WHITE
			)

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
			total_oop_count += 1
			ent_changed.emit()

	%OOPBtn.disabled = false
