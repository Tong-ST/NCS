# Copyright (c) 2026 GoodyWolf / Tong-ST.
# Distributed under the terms of the MIT License.
# See LICENSE for more information.

@tool
extends EditorPlugin

var dock: Control


func _enter_tree() -> void:
	add_autoload_singleton("NCS", "res://addons/ncs/core/system_manager.gd")
	dock = load("res://addons/ncs/tools/ncs_tool_dock.gd").new()
	dock.name = "NCS Tools"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

	print("NCS Framework Initialized Successfully.")


func _exit_tree() -> void:
	remove_autoload_singleton("NCS")
	if dock:
		remove_control_from_docks(dock)
		dock.free()

	print("NCS Framework Cleaned Up.")
