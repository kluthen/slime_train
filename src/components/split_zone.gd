@tool
class_name SplitZone
extends Area2D
## A split zone (master spec §5.4): splits every slime that enters it into
## base slimes. The start of the loop carries one (rule 4). The component
## marks the box; the splitting is SplitZones' (src/sim/split_zones.gd), in
## the simulation.
# @spec-link [[rule_start_carries_split_zone]]
# @spec-link [[req_interactive_objects_general]]

const COLOR := Color(1.0, 0.4, 0.9)

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
	PlaceholderArt.draw_box(self, size, COLOR, stable_id, true)


## Whether `offset` (from its position) is inside its box.
func contains(offset: Vector2) -> bool:
	return PlaceholderArt.box_contains(size, offset)


func _resize() -> void:
	if is_node_ready():
		PlaceholderArt.set_area_box(self, size)
	queue_redraw()
