@tool
class_name Basket
extends Area2D
## A basket (master spec §5.4): collects slimes until their weight reaches
## its quota, then fires its target (on_full_object / on_full_action, a rule
## in the shared format, see Rule). Its box is where the slimes rest: a slime
## whose centre is inside is in the basket. It shows the weight it still
## needs as slime outlines; when full, the reward waits until it is in view,
## then it fires and releases its slimes through its outlet. The behaviour is
## FrontierSets' (src/sim/frontier_sets.gd); this node only configures it.
##
## Where it releases its slimes (after firing, and after an opt-out) belongs
## to the basket's own design, not settled yet (Known gap 3, O62): it is the
## `outlet` property, so it can change. "onward_route" (the default, the test
## level's assumption) drops them onto the onward route `outlet_before` px
## before the slide entrance its target gate retires; "point" drops them at
## `outlet_point`.

const COLOR := Color(1.0, 1.0, 1.0)

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
## The weight that fills it (a size-3 slime counts 3).
# @spec-link [[req_switch_basket_gate_set]]
@export_range(1, 200) var quota := 1:
	set(value):
		quota = value
		queue_redraw()
## What it fires when full: the stable ID of the target (the frontier gate)...
@export var on_full_object := ""
## ...and the action asked of it.
@export var on_full_action := "open"
## Where it releases its slimes: "onward_route" or "point" (see above).
@export_enum("onward_route", "point") var outlet := "onward_route"
## For "onward_route": how far before the slide entrance, in px along the
## loop.
@export var outlet_before := 200.0
## For "point": where, relative to the basket's position, in level pixels.
@export var outlet_point := Vector2.ZERO

func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _ready() -> void:
	_resize()


func _draw() -> void:
	PlaceholderArt.draw_box(self, size, COLOR, "%s  quota %d" % [stable_id, quota])


## Whether `offset` (from its position) is inside its box.
func contains(offset: Vector2) -> bool:
	return PlaceholderArt.box_contains(size, offset)


## Its box as a tap target (TapDispatcher). A basket never answers a tap
## (D109: FrontierSets.answering() leaves it out, so a tap on it calls); it
## is listed so level rule 21 can check where it sits.
# @spec-link [[req_controls_tap_zones]]
func tap_target() -> Dictionary:
	return {"kind": TapDispatcher.KIND_BASKET, "size": size}


## Events it can trigger a rule with.
# @spec-link [[req_interactive_objects_general]]
func rule_events() -> PackedStringArray:
	return PackedStringArray(["full"])


## Its rule, in the shared format: when full, fire the target.
# @spec-link [[req_interactive_objects_general]]
# @spec-link [[req_switch_basket_gate_set]]
func rules() -> Array[Rule]:
	var out: Array[Rule] = []
	if not on_full_object.is_empty():
		out.append(Rule.make(stable_id, "full", on_full_object, on_full_action))
	return out


func _resize() -> void:
	if is_node_ready():
		PlaceholderArt.set_area_box(self, size)
	queue_redraw()
