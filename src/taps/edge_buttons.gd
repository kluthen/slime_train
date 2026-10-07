class_name EdgeButtons
extends Node2D
## Draws the left and right edge buttons (tap zone 2, master spec §5.5):
## a translucent arrow in the middle of each strip (TapDispatcher.edge_button_rect,
## whole-height strips since chunk 23B), pointing back (left) and forward
## (right); the strip itself isn't marked. It only reads the simulation:
## the screen size from its view, and whether to show them from its camera
## (Camera.edge_buttons_visible; hidden at bedtime, chunk 17). Placeholder
## art until the ui_ux tree settles the look. Place it on a CanvasLayer: it
## draws in screen pixels. It redraws only when what it draws changes
## (refresh()).

const FILL := Color(1.0, 1.0, 1.0, 0.22)
const OUTLINE := Color(1.0, 1.0, 1.0, 0.45)
## The arrow's width and height as shares of the strip's width.
const ARROW_WIDTH := 0.45
const ARROW_HEIGHT := 0.8

## The simulation drawn.
var simulation: Simulation = null
## The real time its per-frame work (_process and _draw) took,
## microseconds, summed until the debug perf log takes it (and sets it back
## to 0); nothing else reads it. Always counted: two clock reads a call.
# @spec-link [[req_platform_and_performance_targets]]
var frame_cost_usec := 0


## What the last redraw asked for showed (picture()); [] before the first.
# @spec-link [[req_platform_and_performance_targets]]
var _drawn: Array = []


## Shows the buttons when the camera does, and asks for a redraw only when
## the picture changed (refresh()); the time it took goes to frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _process(_delta: float) -> void:
	var start_usec := Time.get_ticks_usec()
	refresh()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## Shows the buttons when the camera does, and asks for a redraw when what
## _paint() draws changed since the last one asked (picture()): the drawn
## arrows stay on screen until then. Returns whether it asked.
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_platform_and_performance_targets]]
func refresh() -> bool:
	visible = simulation != null and simulation.camera.edge_buttons_visible
	var now := picture()
	if now == _drawn:
		return false
	_drawn = now
	queue_redraw()
	return true


## Everything _paint() draws from, as a value to compare: whether it is
## shown, then the two edge strips' rectangles (left, right), or nothing
## more without a simulation.
# @spec-link [[req_platform_and_performance_targets]]
func picture() -> Array:
	if simulation == null:
		return [visible]
	return [visible, TapDispatcher.edge_button_rect(-1, simulation.view),
			TapDispatcher.edge_button_rect(1, simulation.view)]


## Draws this frame (_paint()), adding the time it took to frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _draw() -> void:
	var start_usec := Time.get_ticks_usec()
	_paint()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## This frame's drawing: an arrow in the middle of each edge strip.
# @spec-link [[req_controls_tap_zones]]
func _paint() -> void:
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
