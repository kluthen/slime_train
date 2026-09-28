class_name ScreenView
extends RefCounted
## What the player sees, as plain data for the simulation: the view's centre
## in level pixels, its zoom and the screen's size in viewport pixels. Taps
## arrive in screen pixels; the tap zones (the top band, the edge buttons)
## are in screen space and the call point is the tap in level space, so the
## simulation needs the view to dispatch a tap.
##
## The scene layer (src/main.gd) copies its camera into it before every tick;
## tests set it directly. The mapping is Camera2D's: a screen point `p` shows
## the level point centre + (p - screen_size / 2) / zoom.
# @spec-link [[req_controls_tap_zones]]

## The project's viewport (canvas_items stretch): 1152 x 648 logical pixels.
## Headless runs report a square window, so the size always comes from here
## or from test mode's "screen_size", never from the window.
const DEFAULT_SIZE := Vector2(1152, 648)

## The level point at the middle of the screen, level pixels.
var centre := DEFAULT_SIZE * 0.5
## Screen pixels per level pixel (Camera2D.zoom.x; 0.7 shows more level).
var zoom := 1.0
## The screen's size, viewport pixels.
var screen_size := DEFAULT_SIZE


func _init(view_centre := DEFAULT_SIZE * 0.5, view_zoom := 1.0, size := DEFAULT_SIZE) -> void:
	set_to(view_centre, view_zoom, size)


## Changes the whole view at once. A zoom of 0 or less is ignored (kept at 1).
func set_to(view_centre: Vector2, view_zoom: float, size: Vector2) -> void:
	centre = view_centre
	zoom = view_zoom if view_zoom > 0.0 else 1.0
	screen_size = size


## The level point shown at screen point `at`.
func screen_to_world(at: Vector2) -> Vector2:
	return centre + (at - screen_size * 0.5) / zoom


## The screen point showing level point `at`.
func world_to_screen(at: Vector2) -> Vector2:
	return (at - centre) * zoom + screen_size * 0.5


## How wide the view is, level pixels.
func world_width() -> float:
	return screen_size.x / zoom


func dump() -> Dictionary:
	return {"centre": centre.snapped(Vector2(0.01, 0.01)), "zoom": snappedf(zoom, 0.0001),
			"screen_size": screen_size}
