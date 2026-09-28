@tool
class_name FramingZone
extends Area2D
## A framing zone (D60, D61, rule 19): an area of the level that sets the
## camera's zoom and shifts its place while the camera's rail point is inside
## it (Camera, "Framing zones"). Level.build() hands it to the simulation as
## LevelData.framing_zones. Put one wherever the view needs to be wider: a
## branch, a high step, a place the child must see to understand.
# @spec-link [[req_level_design_rules]]
# @spec-link [[req_camera_rails_and_framing]]
# @spec-link [[rule_framing_zone_wherever_wider_view_needed]]

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
## How long an edge button must be held to leave the zone, seconds; -1 uses
## the camera's default (Camera.EXIT_HOLD, about 1 s, O70). A short press
## inside the zone stays inside.
@export var exit_hold := -1.0

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
