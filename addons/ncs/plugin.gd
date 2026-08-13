@tool
extends EditorPlugin

const CONFIG_NODE_NAME = "NCSEntityConfig"
const CONFIG_NODE_SCRIPT = preload("res://addons/ncs/core/entity_root.gd")
const CONFIG_NODE_ICON = null

func _enter_tree() -> void:
	# Register our custom Node configuration hub type to the editor
	add_custom_type(CONFIG_NODE_NAME, "EntityConfig",
		CONFIG_NODE_SCRIPT, CONFIG_NODE_ICON
	)
	
	# Add the global SystemManager as an Autoload Singleton automatically
	add_autoload_singleton("NCS", "res://addons/ncs/core/system_manager.gd")
	print("NCS Framework Initialized Successfully.")

func _exit_tree() -> void:
	# Clean up types when disabling the plugin
	remove_custom_type(CONFIG_NODE_NAME)
	
	# Clean up the autoload singleton
	remove_autoload_singleton("NCS")
	print("NCS Framework Cleaned Up.")
