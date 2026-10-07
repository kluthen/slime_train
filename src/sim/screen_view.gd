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
##
## The phone's density (chunk 20): Android's densityDpi (what Godot's
## screen_get_dpi() reports) is a logical bucket that the user's "display
## size" setting moves, not the panel's pixels per inch (the reference phone
## reports 480 for its 405 ppi, so millimetres came out 18 % too big). The
## panel's own density (PhonePlatform.physical_dpi()) is used instead when it
## is plausible against the logical one (dpi_for_mm(): some devices report
## bogus physical values), else the logical one.
##
## The safe area (chunk 20): the part of the screen clear of the display's
## cut-outs and rounded corners, kept as insets from the screen's edges
## (set_safe_insets(), from SafeArea; none by default and on the desktop), so
## safe_rect() follows the screen's size. What the parent reads or taps is
## laid out inside it (ParentLayout); the tap zones stay on the screen's
## edges. A property of the display too: neither in dump() nor in saves.
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
## A physical density is plausible from this share to this share of the
## logical one, both included (proposed): the "display size" setting moves
## the logical one by about 0.85x to 1.3x around a default that is itself
## 0.8x to 1.25x the panel's (the reference phone: 405 / 480 = 0.84), while a
## bogus reading (a default 160, a wrong unit) lands far outside.
const PHYSICAL_DPI_MIN_SHARE := 0.6
const PHYSICAL_DPI_MAX_SHARE := 1.6

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
## The safe area's insets from the screen's left and top edges, and from its
## right and bottom edges, viewport pixels (see the class doc).
var safe_inset_start := Vector2.ZERO
var safe_inset_end := Vector2.ZERO


func _init(view_centre := DEFAULT_SIZE * 0.5, view_zoom := 1.0, size := DEFAULT_SIZE) -> void:
	set_to(view_centre, view_zoom, size)


## Changes the whole view at once. A zoom of 0 or less can only be a caller
## bug: it is refused loudly and the view is left as it was.
func set_to(view_centre: Vector2, view_zoom: float, size: Vector2) -> void:
	if view_zoom <= 0.0:
		push_error("ScreenView.set_to: the zoom must be above 0, got %s" % view_zoom)
		return
	centre = view_centre
	zoom = view_zoom
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


## Whether `physical_dpi`, the panel's reported pixels per inch, is
## plausible against `logical_dpi`, the density bucket Android reports:
## both above 0 and physical within PHYSICAL_DPI_MIN_SHARE to
## PHYSICAL_DPI_MAX_SHARE of logical.
# @spec-link [[req_parent_gate_and_access]]
static func physical_dpi_plausible(physical_dpi: float, logical_dpi: float) -> bool:
	if physical_dpi <= 0.0 or logical_dpi <= 0.0:
		return false
	var share := physical_dpi / logical_dpi
	return share >= PHYSICAL_DPI_MIN_SHARE and share <= PHYSICAL_DPI_MAX_SHARE


## The density to measure millimetres with, px per inch: `physical_dpi` when
## it is plausible (physical_dpi_plausible()), else `logical_dpi` (a
## physical reading of 0 or less means unknown). The caller refuses a
## logical reading of 0 or less.
# @spec-link [[req_parent_gate_and_access]]
static func dpi_for_mm(physical_dpi: float, logical_dpi: float) -> float:
	return physical_dpi if physical_dpi_plausible(physical_dpi, logical_dpi) else logical_dpi


## Sets the safe area's insets: `start` from the left and top edges, `end`
## from the right and bottom ones, viewport pixels, none negative.
func set_safe_insets(start: Vector2, end: Vector2) -> void:
	assert(start.x >= 0.0 and start.y >= 0.0 and end.x >= 0.0 and end.y >= 0.0,
			"ScreenView.set_safe_insets: insets can't be negative (%s, %s)" % [start, end])
	safe_inset_start = start
	safe_inset_end = end


## The safe area on this screen, viewport pixels: the screen less the insets,
## never past the screen (empty when the insets meet).
# @spec-link [[req_parent_gate_and_access]]
func safe_rect() -> Rect2:
	var start := safe_inset_start.min(screen_size)
	var end := (screen_size - safe_inset_end).max(start)
	return Rect2(start, end - start)


## How wide the view is, level pixels.
func world_width() -> float:
	return screen_size.x / zoom


func dump() -> Dictionary:
	return {"centre": centre.snapped(Vector2(0.01, 0.01)), "zoom": snappedf(zoom, 0.0001),
			"screen_size": screen_size}
