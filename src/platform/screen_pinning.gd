class_name ScreenPinning
extends Node
## Screen pinning and the back gesture over the game (master spec §5.9),
## through the game's PhonePlatform. The game root (src/main.gd) adds it and
## calls launch() once, in its boot.
##
## - Pinning is asked at each launch, never on coming back from the
##   background: on a later launch (a parent code exists, even a locked
##   store's) at once, before the world takes a tap; on first launch right
##   after setup finishes (ParentGate.setup_finished), so an interrupted setup,
##   which starts over, asks only once it is finished. A game with no parent
##   layer asks nothing: nothing could leave the pinning (proposed).
## - Back (Android's back gesture or button, NOTIFICATION_WM_GO_BACK_REQUEST;
##   project.godot's application/config/quit_on_go_back is off, so it never
##   quits the app): while pinned, nothing happens; not pinned (the parent
##   declined, or unpinned), the app goes to the background as Android
##   normally does, the session counting on (the game root's autosave saves
##   on the same notification).
## - The back gesture is kept out of the whole edge strips, as full-height
##   bands on the window's left and right edges (edge_strip_exclusions()), at
##   start and whenever the viewport's size changes.
# @spec-link [[req_screen_pinning]]

## The phone's services.
var platform: PhonePlatform = null


## Pinning and the back gesture through `phone`.
func _init(phone: PhonePlatform) -> void:
	assert(phone != null, "ScreenPinning: a platform is required")
	platform = phone
	name = "ScreenPinning"


## Keeps the back gesture off the edge strips from now on, as the window
## changes size.
# @spec-link [[req_screen_pinning]]
func _ready() -> void:
	get_viewport().size_changed.connect(exclude_edge_strips)
	exclude_edge_strips()


## The launch's pinning, for the parent layer `gate` (null: none): asked now,
## or once setup finishes when `gate` is on setup (first launch).
# @spec-link [[req_screen_pinning]]
func launch(gate: ParentGate) -> void:
	if gate == null:
		return
	if gate.state == ParentGate.State.SETUP:
		gate.setup_finished.connect(platform.request_pinning, CONNECT_ONE_SHOT)
	else:
		platform.request_pinning()


## Back: to the background unless the screen is pinned.
# @spec-link [[req_screen_pinning]]
# @spec-link [[req_session_lifecycle]]
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not platform.is_pinned():
		platform.move_to_background()


## Hands the platform the edge strips' exclusion rects for the viewport as
## shown in the window now.
# @spec-link [[req_screen_pinning]]
func exclude_edge_strips() -> void:
	var viewport := get_viewport()
	platform.set_back_gesture_exclusion(
			edge_strip_exclusions(viewport.get_visible_rect().size, viewport.get_final_transform(), get_window().size))


## The back gesture's excluded rects, window pixels: the left and the right
## edge strip (TapDispatcher.EDGE_STRIP_SHARE of the viewport's width
## `view_size`, as `to_window` maps viewport pixels to the window's) as bands
## the window's full height (`window_size`), against its edges. Full height,
## not from the parent zone down like the strips' tap zone: the parent zone
## is a touch area too (proposed). Rounded outward to whole pixels.
# @spec-link [[req_screen_pinning]]
static func edge_strip_exclusions(view_size: Vector2, to_window: Transform2D, window_size: Vector2i) -> Array[Rect2i]:
	var width := view_size.x * TapDispatcher.EDGE_STRIP_SHARE
	var left_end := clampi(ceili((to_window * Vector2(width, 0.0)).x), 0, window_size.x)
	var right_start := clampi(floori((to_window * Vector2(view_size.x - width, 0.0)).x), 0, window_size.x)
	var rects: Array[Rect2i] = [
		Rect2i(0, 0, left_end, window_size.y),
		Rect2i(right_start, 0, window_size.x - right_start, window_size.y),
	]
	return rects
