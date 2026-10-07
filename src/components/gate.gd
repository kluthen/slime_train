@tool
class_name Gate
extends Node2D
## A gate (master spec §5.4): blocks the loop at a section's frontier until
## something opens it. Opening the frontier gate grows the loop: the section's
## return route is retired and the next section's segments join
## (LoopData.current_segments). Its box is solid while it is closed; it
## opens when its basket fires (a rule) and stays open. `entrance_lid` shuts
## the old slide entrance once it is open, so the flow carries on through
## the gate. The behaviour is FrontierSets' (src/sim/frontier_sets.gd).

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
## The lid over the old slide entrance, a box relative to the gate's
## position in level pixels: solid once the gate is open. Empty: none.
@export var entrance_lid := Rect2():
	set(value):
		entrance_lid = value
		queue_redraw()


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _draw() -> void:
	PlaceholderArt.draw_box(self, size, COLOR, stable_id, true)
	if Engine.is_editor_hint() and entrance_lid.has_area():
		draw_rect(entrance_lid, COLOR, false, 2.0)


## Actions a rule can ask of it.
# @spec-link [[req_interactive_objects_general]]
# @spec-link [[req_switch_basket_gate_set]]
# @spec-link [[rule_gate_opens_via_switch_basket_set]]
func rule_actions() -> PackedStringArray:
	return PackedStringArray(["open"])
