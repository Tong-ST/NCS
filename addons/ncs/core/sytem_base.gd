class_name NCSSystemBase
extends NCSBase

# A optimized flat array containing all active components managed by this system
var active_components: Array[NCSComponentBase] = []

## Called by components during their _ready initialization hook
func register_component(component: NCSComponentBase) -> void:
	if not active_components.has(component):
		active_components.append(component)
		_on_component_registered(component)

## Called by components during their _exit_tree cleanup hook
func unregister_component(component: NCSComponentBase) -> void:
	if active_components.has(component):
		active_components.erase(component)
		_on_component_unregistered(component)

## VIRTUAL HOOK: Override this if a system needs setup logic when a component arrives
func _on_component_registered(_component: NCSComponentBase) -> void:
	pass

## VIRTUAL HOOK: Override this if a system needs cleanup logic when a component leaves
func _on_component_unregistered(_component: NCSComponentBase) -> void:
	pass
