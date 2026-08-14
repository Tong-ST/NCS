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
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)

	perf_counter.text = "FPS: %d\nProcess: %.2f ms\nObjects: %d" % [fps, process_time, object_count]

func _unhandled_input(event: InputEvent) -> void:
	# spawn NCS enemy
	if event.is_action_pressed("ui_cancel"):
		for i in range(500):
			await get_tree().process_frame
			var enemy = preload("uid://cvael67uegn6h").instantiate() as Enemy
			total_ncs_count += 1
			add_child(enemy)
			ent_changed.emit()

	# spawn OOP enemy
	if event.is_action_pressed("ui_end"):
		for i in range(500):
			await get_tree().process_frame
			var enemy = preload("uid://lvup6a5nx615").instantiate() as EnemyOOP
			total_oop_count += 1
			add_child(enemy)
			ent_changed.emit()


func _on_ent_changed() -> void:
	ncs_ent_count.text = str("NCS Enemies: ", total_ncs_count)
	oop_ent_count.text = str("OOP Enemies: ", total_oop_count)
