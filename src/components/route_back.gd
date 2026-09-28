@tool
class_name RouteBack
extends Path2D
## An exploration branch's route back to the loop (D69, rules 7 and 8), drawn
## as a Path2D curve from inside the branch down to a point on the loop. No
## pathfinding: a heading-back slime follows it, and off screen a free slime
## is placed on it and moves along it at a deterministic pace (chunk 15).
##
## It must start inside the branch it serves, end on the loop, and only go
## down, so gravity leads back (checked by tests/e2e/test_test_level.gd).
# @spec-link [[rule_exploration_branch_has_route_back]]
# @spec-link [[rule_no_dead_ends]]
# @spec-link [[rule_gravity_leads_back_to_loop]]

const COLOR := Color(0.4, 1.0, 0.5, 0.7)

## The route's stable ID, `<place>.route-back.<name>`.
@export var stable_id := "":
	set(value):
		stable_id = value
		queue_redraw()
## The stable ID of the ExplorationBranch it serves.
@export var serves := ""
## Draw the route (greybox).
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
		PlaceholderArt.draw_route(self, curve, COLOR, stable_id)


## The route as a polyline in the coordinates of `level`.
func level_points(level: Level) -> PackedVector2Array:
	if curve == null:
		return PackedVector2Array()
	return level.transform_of(self) * curve.tessellate(6, 2.0)


func references() -> Dictionary:
	return {"serves": serves}
