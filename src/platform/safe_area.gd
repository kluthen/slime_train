class_name SafeArea
extends Node
## The display's safe area (clear of cut-outs and rounded corners) in the
## game's viewport coordinates (chunk 20). The Android build draws edge to
## edge in sticky immersive mode, so the window covers the punch-hole camera
## (on a short edge: the left or the right in landscape) and the rounded
## corners: the world is drawn edge to edge, what a parent reads or taps
## stays inside the safe area (ParentLayout).
##
## It reads the game's PhonePlatform's safe_area() (screen pixels) and maps it
## through the stretch (canvas_items, aspect expand: the viewport's final
## transform to window pixels) into insets from the viewport's edges, at
## start, whenever the viewport's size changes and when the app comes back
## from the background (proposed: the project is fixed landscape, so the
## cut-out doesn't move without a resize). The game root (src/main.gd) adds
## it and hands the insets to the simulation's view (apply_to(), in
## sync_view()), which gives the parent layer ScreenView.safe_rect(). On the
## desktop the safe area is the window: no insets, nothing moves.
##
## The tap zones (the parent zone, the edge strips) stay measured on the
## screen's edges (req_controls_tap_zones), not on the safe area.
# @spec-link [[req_parent_gate_and_access]]

## The phone's services.
var platform: PhonePlatform = null
## The insets from the viewport's left and top edges, and from its right and
## bottom edges, viewport pixels (never negative).
var inset_start := Vector2.ZERO
var inset_end := Vector2.ZERO


## The safe area through `phone`.
func _init(phone: PhonePlatform) -> void:
	assert(phone != null, "SafeArea: a platform is required")
	platform = phone
	name = "SafeArea"


## Reads the safe area now and again whenever the viewport changes size.
func _ready() -> void:
	get_viewport().size_changed.connect(refresh)
	refresh()


## Back from the background: the safe area is read again (proposed).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_inside_tree():
		refresh()


## Reads the platform's safe area and turns it into the viewport's insets, for
## the viewport as shown in the window now.
# @spec-link [[req_parent_gate_and_access]]
func refresh() -> void:
	var viewport := get_viewport()
	var window := get_window()
	var view_size := viewport.get_visible_rect().size
	var safe := in_viewport(platform.safe_area(), Rect2i(window.position, window.size),
			viewport.get_final_transform(), view_size)
	var insets := insets_of(safe, view_size)
	inset_start = insets[0]
	inset_end = insets[1]


## Gives `view` the insets (its safe_rect() follows its own size).
# @spec-link [[req_controls_tap_zones]]
func apply_to(view: ScreenView) -> void:
	view.set_safe_insets(inset_start, inset_end)


## The safe area `safe_area` (screen pixels) as a rect of the viewport of
## `view_size`, shown in the window `window` (screen pixels) through
## `to_window` (the viewport's final transform: viewport to window pixels),
## clipped to the viewport. A safe area with no part on the window (a
## headless display reports none) is the whole viewport.
# @spec-link [[req_parent_gate_and_access]]
static func in_viewport(safe_area: Rect2i, window: Rect2i, to_window: Transform2D, view_size: Vector2) -> Rect2:
	var whole := Rect2(Vector2.ZERO, view_size)
	var on_window := Rect2(safe_area.position - window.position, safe_area.size) \
			.intersection(Rect2(Vector2.ZERO, window.size))
	if not on_window.has_area():
		return whole
	var to_view := to_window.affine_inverse()
	var start := to_view * on_window.position
	var end := to_view * on_window.end
	var safe := Rect2(start, end - start).abs().intersection(whole)
	return safe if safe.has_area() else whole


## The insets of `safe` from the edges of a viewport of `view_size`: [left and
## top, right and bottom], viewport pixels.
# @spec-link [[req_controls_tap_zones]]
static func insets_of(safe: Rect2, view_size: Vector2) -> Array[Vector2]:
	return [safe.position, view_size - safe.end]
