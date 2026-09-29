class_name EdgeButtons
extends Node2D
## Draws the left and right edge buttons (tap zone 2, master spec §5.5):
## a translucent arrow in the middle of each strip (TapDispatcher.edge_button_rect,
## whole-height strips since chunk 23B), pointing back (left) and forward
## (right); the strip itself isn't marked. It only reads the simulation:
## the screen size from its view, and whether to show them from its camera
## (Camera.edge_buttons_visible; hidden at bedtime, chunk 17). Placeholder
## art until the ui_ux tree settles the look. Place it on a CanvasLayer: it
## draws in screen pixels.
# @spec-link [[req_controls_tap_zones]]

const FILL := Color(1.0, 1.0, 1.0, 0.22)
const OUTLINE := Color(1.0, 1.0, 1.0, 0.45)
## The arrow's width and height as shares of the strip's width.
const ARROW_WIDTH := 0.45
const ARROW_HEIGHT := 0.8

## The simulation drawn.
var simulation: Simulation = null


func _process(_delta: float) -> void:
	visible = simulation != null and simulation.camera.edge_buttons_visible
	queue_redraw()


func _draw() -> void:
	if simulation == null:
		return
	for side in [-1, 1]:
		var box := TapDispatcher.edge_button_rect(side, simulation.view)
		var centre := box.get_center()
		var half := Vector2(ARROW_WIDTH, ARROW_HEIGHT) * box.size.x * 0.5
		var arrow := PackedVector2Array([
			centre + Vector2(side * half.x, 0.0),
			centre + Vector2(-side * half.x, -half.y),
			centre + Vector2(-side * half.x, half.y),
		])
		draw_colored_polygon(arrow, FILL)
		arrow.append(arrow[0])
		draw_polyline(arrow, OUTLINE, 2.0, true)
