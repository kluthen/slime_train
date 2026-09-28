@tool
class_name FramingZone
extends Area2D
## A framing zone (D60, D61, rule 19): an area of the level that sets the
## camera's zoom and position when the camera reaches it. Placeholder: the
## camera doesn't read it yet (chunk 13).
# @spec-link [[req_level_design_rules]]

const COLOR := Color(0.5, 0.8, 1.0, 0.5)

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
## The camera zoom inside the zone, as Camera2D.zoom: 1 is normal play,
## below 1 shows more (0.8 shows 25% more), above 1 closes in.
@export_range(0.25, 2.0, 0.05) var zoom := 1.0:
	set(value):
		zoom = value
		queue_redraw()
## How far the camera shifts from where the rails would put it, in level
## pixels (negative y is up).
@export var offset := Vector2.ZERO:
	set(value):
		offset = value
		queue_redraw()

func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _ready() -> void:
	_resize()


func _draw() -> void:
	PlaceholderArt.draw_box(self, size, COLOR, "%s  zoom %.2f" % [stable_id, zoom])


## Whether `offset` (from its position) is inside its box.
func contains(offset: Vector2) -> bool:
	return PlaceholderArt.box_contains(size, offset)


func _resize() -> void:
	if is_node_ready():
		PlaceholderArt.set_area_box(self, size)
	queue_redraw()
