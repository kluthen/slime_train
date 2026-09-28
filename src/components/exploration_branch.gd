@tool
class_name ExplorationBranch
extends Area2D
## An exploration branch: an area off the loop that slimes reach only when
## called (master spec §5.1). Its box covers where a free slime in the branch
## can be. Every branch has a RouteBack whose `serves` is this branch's ID
## (rule 8). No behaviour yet: chunk 15 uses it to find a free slime's route
## back.
# @spec-link [[rule_exploration_branch_has_route_back]]
# @spec-link [[req_loop_and_world]]

const COLOR := Color(0.4, 1.0, 0.5, 0.5)

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


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _ready() -> void:
	_resize()


func _draw() -> void:
	PlaceholderArt.draw_box(self, size, COLOR, stable_id)


## Whether `offset` (from its position) is inside its box.
func contains(offset: Vector2) -> bool:
	return PlaceholderArt.box_contains(size, offset)


func _resize() -> void:
	if is_node_ready():
		PlaceholderArt.set_area_box(self, size)
	queue_redraw()
