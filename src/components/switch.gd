@tool
class_name Switch
extends Area2D
## A switch (master spec §5.4): stands at the fork just before the frontier
## gate. By default the flow carries on (toward the return route while the
## gate is closed); tapped, it flips and sends the flow into its basket.
## It stays flipped until tapped again; flipped back before the basket is
## full, the basket lets its slimes go (opting out). A tap within its hit
## area (TapDispatcher.hit_area(): its box plus 5 mm, at least 20 x 20 mm on
## the screen) flips it and doesn't call while its basket is filling; once
## the basket is full it no longer answers, and a tap on it is a call (D109).
## The behaviour is
## FrontierSets' (src/sim/frontier_sets.gd); this node only configures it.
##
## How it sends the flow: `trapdoor`, a box of the onward path that is solid
## while the switch sends the flow onward and opens, dropping the slimes that
## walk onto it into the basket, while it is flipped.

const COLOR := Color(1.0, 0.6, 0.2)

## The stable ID, `<place>.<kind>.<name>`.
@export var stable_id := "":
	set(value):
		stable_id = value
		queue_redraw()
## The box it covers, centred on its position, in level pixels.
@export var size := Vector2(200, 100):
	set(value):
		size = value
		_resize()
## The basket it sends the flow into when flipped.
# @spec-link [[req_switch_basket_gate_set]]
@export var basket_id := ""
## The trapdoor: a box relative to the switch's position, in level pixels
## (solid while the flow goes onward, open while flipped). Empty: none.
@export var trapdoor := Rect2():
	set(value):
		trapdoor = value
		queue_redraw()

func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _ready() -> void:
	_resize()


func _draw() -> void:
	PlaceholderArt.draw_box(self, size, COLOR, stable_id)
	if Engine.is_editor_hint() and trapdoor.has_area():
		draw_rect(trapdoor, COLOR, false, 2.0)


## Whether `offset` (from its position) is inside its box.
func contains(offset: Vector2) -> bool:
	return PlaceholderArt.box_contains(size, offset)


## What a tap lands on (TapDispatcher): its box, grown to its hit area by
## TapDispatcher.hit_area().
# @spec-link [[req_controls_tap_zones]]
func tap_target() -> Dictionary:
	return {"kind": TapDispatcher.KIND_SWITCH, "size": size}


## The stable IDs it points at, by property (see Level): its basket.
# @spec-link [[req_interactive_objects_general]]
func references() -> Dictionary:
	return {"basket_id": basket_id}


func _resize() -> void:
	if is_node_ready():
		PlaceholderArt.set_area_box(self, size)
	queue_redraw()
