class_name NCSComponentBase
extends NCSBase


## Access to owner of current scene that tag by NCSComponentHub
var owner_node: Node
## Access to EntityConfig Node that have all D_Data of current scenes
var entity_config: EntityConfig

# Do not OVERRIDDE anything here, To create custom logic for component,
# just create new script/class e.g. C_Player and extends NCSComponentBase
# then attach script to C_Player node in NCSComponentHub node.

# Name of node are matter!, C_Player, C_Movement, C_Input, Make it consistency.
# And Component can be just a TAG to filter in S_System, That not need for any script.
