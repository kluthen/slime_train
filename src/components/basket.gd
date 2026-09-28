@tool
class_name Basket
extends Area2D
## A basket (master spec §5.4): collects slimes until their weight reaches
## its quota, then fires its target (on_full_object / on_full_action, a rule
## in the shared format, see Rule). Placeholder: no counting or firing yet
## (chunk 14).
# @spec-link [[req_interactive_objects_general]]

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
@export_range(1, 200) var quota := 1:
	set(value):
		quota = value
		queue_redraw()
## What it fires when full: the stable ID of the target (the frontier gate)...
@export var on_full_object := ""
## ...and the action asked of it.
@export var on_full_action := "open"

func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _ready() -> void:
	_resize()


func _draw() -> void:
	PlaceholderArt.draw_box(self, size, COLOR, "%s  quota %d" % [stable_id, quota])


## Whether `offset` (from its position) is inside its box.
func contains(offset: Vector2) -> bool:
	return PlaceholderArt.box_contains(size, offset)


## What a tap lands on (TapDispatcher): its box. The hit area adds a margin.
# @spec-link [[req_controls_tap_zones]]
func tap_target() -> Dictionary:
	return {"kind": TapDispatcher.KIND_BASKET, "size": size}


## Events it can trigger a rule with.
func rule_events() -> PackedStringArray:
	return PackedStringArray(["full"])


## Its rule, in the shared format: when full, fire the target.
func rules() -> Array[Rule]:
	var out: Array[Rule] = []
	if not on_full_object.is_empty():
		out.append(Rule.make(stable_id, "full", on_full_object, on_full_action))
	return out


func _resize() -> void:
	if is_node_ready():
		PlaceholderArt.set_area_box(self, size)
	queue_redraw()
