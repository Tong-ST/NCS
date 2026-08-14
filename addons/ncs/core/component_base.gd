class_name NCSComponentBase
extends NCSBase

# Do not OVERRIDDE anything here, To create custom logic for component,
# just create new script/class e.g. C_Player and extends NCSComponentBase
# then attach script to C_Player node in NCSComponentHub node.

# Name of node are matter!, C_Player, C_Movement, C_Input, Make it consistency.
# And Component can be just a TAG to filter in S_System, That not need for any script.
@export var require_data: bool = false

var owner_node: Node
var config: EntityConfig

func _init_comp() -> void:
	pass
