# Copyright (c) 2026 GoodyWolf / Tong-ST.
# Distributed under the terms of the MIT License.
# See LICENSE for more information.

@tool
extends EditorPlugin

# ==============================================================================
# PLUGIN LIFECYCLE
# ==============================================================================

func _enter_tree() -> void:
	add_autoload_singleton("NCS", "res://addons/ncs/core/system_manager.gd")
	print("NCS Framework Initialized Successfully.")


func _exit_tree() -> void:
	remove_autoload_singleton("NCS")
	print("NCS Framework Cleaned Up.")
