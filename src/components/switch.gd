@tool
class_name Switch
extends Area2D
## A switch (master spec §5.4): stands at the fork just before the frontier
## gate. By default the flow carries on (toward the return route while the
## gate is closed); tapped, it flips and sends the flow into its basket.
## Placeholder: no behaviour yet (chunk 14). The hit area larger than the
## drawn switch comes with the taps (chunk 7).
# @spec-link [[req_interactive_objects_general]]

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
@export var basket_id := ""

func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _ready() -> void:
	_resize()


func _draw() -> void:
	PlaceholderArt.draw_box(self, size, COLOR, stable_id)


## Whether `offset` (from its position) is inside its box.
func contains(offset: Vector2) -> bool:
	return PlaceholderArt.box_contains(size, offset)


func references() -> Dictionary:
	return {"basket_id": basket_id}


func _resize() -> void:
	if is_node_ready():
		PlaceholderArt.set_area_box(self, size)
	queue_redraw()
