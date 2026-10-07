@tool
class_name LoopSegment
extends Path2D
## One segment of the loop: a route drawn as a Path2D curve, a child of the
## Loop. Draw it along the surface at a slime's centre height, in the
## direction of travel.
##
## - `kind` "outgoing": the route out from the start toward the frontier.
## - `kind` "return": a section's return route back to the start, in use while
##   `gate_id` (the section's frontier gate) is closed. In the test level it is
##   an underground slide, a placeholder (O22): nothing depends on what a
##   return route is made of.
##
## Segments join end to start; a return route starts where its section's
## outgoing route ends and ends at the start of the loop.

const ROUTE_COLORS := {"outgoing": Color(1.0, 0.8, 0.3, 0.7), "return": Color(0.3, 0.9, 1.0, 0.7)}

## The segment's stable ID: `s1.loop` for section 1's outgoing route,
## `s1.slide` for its return route in the test level.
@export var stable_id := "":
	set(value):
		stable_id = value
		queue_redraw()
## The section the segment belongs to (1, 2...).
@export_range(1, 99) var section := 1
## "outgoing" or "return".
# @spec-link [[rule_return_route_per_section]]
@export_enum("outgoing", "return") var kind := "outgoing":
	set(value):
		kind = value
		queue_redraw()
## For a return route: the gate whose opening retires it (the section's
## frontier gate). Empty for an outgoing segment, and for a last section's
## return route that is never retired.
# @spec-link [[rule_return_route_per_section]]
@export var gate_id := ""
## Draw the route (greybox); off for the real art.
@export var show_route := true:
	set(value):
		show_route = value
		queue_redraw()


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _ready() -> void:
	if Engine.is_editor_hint() and curve != null and not curve.changed.is_connected(queue_redraw):
		curve.changed.connect(queue_redraw)


func _draw() -> void:
	if show_route:
		PlaceholderArt.draw_route(self, curve, ROUTE_COLORS.get(kind, Color.WHITE), stable_id)


## The route as a polyline in the coordinates of `level`.
# @spec-link [[req_loop_and_world]]
func level_points(level: Level) -> PackedVector2Array:
	if curve == null:
		return PackedVector2Array()
	return level.transform_of(self) * curve.tessellate(6, 2.0)


## The stable IDs it points at, by property (see Level): its gate.
func references() -> Dictionary:
	return {"gate_id": gate_id}
