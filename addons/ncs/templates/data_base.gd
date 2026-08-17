# Copyright (c) 2026 GoodyWolf / Tong-ST.
# Distributed under the terms of the MIT License.
# See LICENSE for more information.

## Base class for all NCS data resources (D_* naming convention).
## Extend this to define per-entity runtime data (e.g. D_Health, D_Movement).
## Instances live inside NCSEntityDataSet.data_sets and are duplicate per-entity at spawn.
class_name NCSDataBase
extends Resource

## Returns the script class name of this data block (e.g. "D_Health").
## Used internally for editor validation and debug logging.
func get_class_identifier() -> String:
	var script = get_script()
	if script:
		return script.get_global_name()
	return ""
