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
##
## Millimetres on the screen (chunk 23B): some sizes are physical, measured
## on the screen whatever the zoom (the parent zone's 7 mm, D113; objects'
## hit areas, D109). `px_per_mm` is how many viewport pixels make a
## millimetre on this screen, and mm_to_px() converts. It defaults to the
## reference phone's; the scene layer sets it from the display
## (px_per_mm_for()), tests set it directly. It is a property of the display,
## like the window, not of the game: it is neither in dump() nor in saves
## (what it decided is, in the taps).
# @spec-link [[req_controls_tap_zones]]

## The project's viewport (canvas_items stretch): 1152 x 648 logical pixels.
## Headless runs report a square window, so the size always comes from here
## or from test mode's "screen_size", never from the window.
const DEFAULT_SIZE := Vector2(1152, 648)
const MM_PER_INCH := 25.4
## The reference phone (Galaxy S20 FE): 2400 x 1080 physical px at about
## 405 ppi. In landscape with the project's stretch (canvas_items, aspect
## expand) its 1080 px show the viewport's 648, so its screen is 1440 x 648
## viewport px, each 1080 / 648 physical px across.
const REFERENCE_PHONE_PPI := 405.0
const REFERENCE_PHONE_SCALE := 1080.0 / 648.0
const REFERENCE_PHONE_SIZE := Vector2(1440, 648)
## Viewport px per millimetre on the reference phone: about 9.57.
const REFERENCE_PX_PER_MM := REFERENCE_PHONE_PPI / MM_PER_INCH / REFERENCE_PHONE_SCALE

## The level point at the middle of the screen, level pixels.
var centre := DEFAULT_SIZE * 0.5
## Screen pixels per level pixel (Camera2D.zoom.x; 0.7 shows more level).
var zoom := 1.0
## The screen's size, viewport pixels.
var screen_size := DEFAULT_SIZE
## Viewport px per millimetre on this screen (see the class doc). A value of 0
## or less is refused loudly and the old one kept.
var px_per_mm := REFERENCE_PX_PER_MM:
	set(value):
		if value <= 0.0:
			push_error("ScreenView: px_per_mm must be above 0, got %s" % value)
			return
		px_per_mm = value


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


## The viewport px that `millimetres` span on this screen (at any zoom).
func mm_to_px(millimetres: float) -> float:
	return millimetres * px_per_mm


## Viewport px per millimetre for a display of `ppi` physical px per inch
## showing each viewport px as `physical_per_viewport` physical px across.
## Both must be above 0 (the caller validates the display's readings).
static func px_per_mm_for(ppi: float, physical_per_viewport: float) -> float:
	assert(ppi > 0.0 and physical_per_viewport > 0.0, "ScreenView.px_per_mm_for: readings must be above 0")
	return ppi / MM_PER_INCH / physical_per_viewport


## How wide the view is, level pixels.
func world_width() -> float:
	return screen_size.x / zoom


func dump() -> Dictionary:
	return {"centre": centre.snapped(Vector2(0.01, 0.01)), "zoom": snappedf(zoom, 0.0001),
			"screen_size": screen_size}
