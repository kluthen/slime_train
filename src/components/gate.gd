@tool
class_name Gate
extends Node2D
## A gate (master spec §5.4): blocks the loop at a section's frontier until
## something opens it. Opening the frontier gate grows the loop: the section's
## return route is retired and the next section's segments join
## (LoopData.current_segments). Placeholder: no body or opening yet
## (chunk 14).
# @spec-link [[req_interactive_objects_general]]

const COLOR := Color(0.85, 0.3, 0.3)

## The stable ID, `<place>.gate`.
@export var stable_id := "":
	set(value):
		stable_id = value
		queue_redraw()
## The box it blocks, centred on its position, in level pixels.
@export var size := Vector2(40, 160):
	set(value):
		size = value
		queue_redraw()


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _draw() -> void:
	PlaceholderArt.draw_box(self, size, COLOR, stable_id, true)


## Actions a rule can ask of it.
func rule_actions() -> PackedStringArray:
	return PackedStringArray(["open"])
