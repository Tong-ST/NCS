# Copyright (c) 2026 GoodyWolf / Tong-ST.
# Distributed under the terms of the MIT License.
# See LICENSE for more information.

@tool
extends EditorPlugin

const CONFIG_NODE_NAME = "NCSEntityConfig"
const CONFIG_NODE_SCRIPT = preload("res://addons/ncs/core/entity_config.gd")
const CONFIG_NODE_ICON = null


func _enter_tree() -> void:
	add_custom_type(CONFIG_NODE_NAME, "EntityConfig",
		CONFIG_NODE_SCRIPT, CONFIG_NODE_ICON
	)

	add_autoload_singleton("NCS", "res://addons/ncs/core/system_manager.gd")
	print("NCS Framework Initialized Successfully.")


func _exit_tree() -> void:
	remove_custom_type(CONFIG_NODE_NAME)

	remove_autoload_singleton("NCS")
	print("NCS Framework Cleaned Up.")
