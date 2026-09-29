class_name TapDispatcher
extends RefCounted
## Which tap zone a tap lands in (master spec §5.5, D15, D33, D57), checked
## in the spec's order:
##
##   1. the parent zone: a band PARENT_ZONE_MM (7 mm, D113) high along the
##      top of the screen, measured on the screen (ScreenView.mm_to_px), full
##      width. It reveals the parent buttons (chunk 18) and never calls;
##   2. the left and right edge buttons: strips EDGE_STRIP_SHARE (10%, D99)
##      of the screen's width from each side, from the parent zone down to
##      the bottom (the parent zone wins in the top corners). A strip takes
##      the whole tap: it moves the camera (chunk 12), never calls and
##      operates no object under it. Hidden (at bedtime), they are no zone;
##   3. an interactive object's hit area: the object's box grown by
##      OBJECT_HIT_MARGIN screen pixels on every side (generous for small
##      fingers, D91). It operates the object (chunks 9 and 14) and never
##      calls, except a sleeper, which is a call centred on it (D46);
##   4. anywhere else: open ground, a call centred on the tap.
##
## Zones 1 and 2 are screen space; zone 3 is level space (the objects move
## with the camera), with the margin converted at the view's zoom. Where hit
## areas overlap, the object whose box centre is nearest the tap wins (ties:
## the smaller stable ID). Pure functions over plain data.
##
## How the strips and the parent zone are drawn (the arrows, any marking) is
## interface design (ux-writer); src/taps/edge_buttons.gd draws placeholders.
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_interactive_objects_general]]
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[req_camera_rails_and_framing]]

const ZONE_PARENT := "parent_zone"
const ZONE_EDGE := "edge_button"
const ZONE_OBJECT := "object"
const ZONE_GROUND := "open_ground"

## The parent zone's height, millimetres on the screen (D113).
const PARENT_ZONE_MM := 7.0
## Each edge strip's width, as a share of the screen's width (D99).
const EDGE_STRIP_SHARE := 0.1
## How much larger than the object's box its hit area is, on every side,
## screen pixels.
const OBJECT_HIT_MARGIN := 24.0

## The tap target kinds (LevelData.tap_targets). Only a sleeper calls.
const KIND_SWITCH := "switch"
const KIND_BASKET := "basket"
const KIND_SLEEPER := "sleeper"


## The parent zone's height on `view`'s screen, screen pixels: 7 mm at its
## density, whatever the zoom. The band runs from y = 0 down to it; level
## rule 21 (objects below the parent zone) measures against it.
# @spec-link [[req_parent_gate_and_access]]
static func parent_zone_height(view: ScreenView) -> float:
	return view.mm_to_px(PARENT_ZONE_MM)


## The left (side -1) or right (side 1) edge strip's rectangle on `view`'s
## screen, screen pixels: a tenth of the screen's width against that side,
## from the parent zone down to the bottom.
static func edge_button_rect(side: int, view: ScreenView) -> Rect2:
	var top := parent_zone_height(view)
	var width := view.screen_size.x * EDGE_STRIP_SHARE
	var x := 0.0 if side < 0 else view.screen_size.x - width
	return Rect2(x, top, width, maxf(view.screen_size.y - top, 0.0))


## The zone of a tap at `at` (screen pixels) with the view `view`, the level's
## tap targets being `tap_targets` (LevelData.tap_targets: stable ID ->
## {"kind", "box"}). Returns {"zone", "world" (the tap in level pixels),
## "side" (-1 or 1 for an edge button, else 0), "object" (the stable ID, or
## ""), "kind" (the object's kind, or ""), "call" (whether it calls),
## "call_point" (level pixels: the tap, or the sleeper's centre)}.
## `edge_buttons`: whether the edge buttons show; hidden (at bedtime) they
## are no zone, and a tap there lands on what is under it.
static func dispatch(at: Vector2, view: ScreenView, tap_targets: Dictionary, edge_buttons := true) -> Dictionary:
	var world := view.screen_to_world(at)
	var result := {"zone": ZONE_GROUND, "world": world, "side": 0, "object": "", "kind": "",
			"call": true, "call_point": world}
	if at.y < parent_zone_height(view):
		result["zone"] = ZONE_PARENT
		result["call"] = false
		return result
	for side in [-1, 1]:
		if edge_buttons and edge_button_rect(side, view).has_point(at):
			result["zone"] = ZONE_EDGE
			result["side"] = side
			result["call"] = false
			return result
	var hit := object_at(world, view.zoom, tap_targets)
	if not hit.is_empty():
		var box: Rect2 = tap_targets[hit]["box"]
		result["zone"] = ZONE_OBJECT
		result["object"] = hit
		result["kind"] = tap_targets[hit]["kind"]
		result["call"] = result["kind"] == KIND_SLEEPER
		result["call_point"] = box.get_center()
	return result


## The stable ID of the object whose hit area holds `world` (level pixels)
## at `zoom`, or "".
static func object_at(world: Vector2, zoom: float, tap_targets: Dictionary) -> String:
	var margin := OBJECT_HIT_MARGIN / (zoom if zoom > 0.0 else 1.0)
	var ids := tap_targets.keys()
	ids.sort()
	var best := ""
	var best_gap := INF
	for id in ids:
		var box: Rect2 = tap_targets[id]["box"]
		if not box.grow(margin).has_point(world):
			continue
		var gap := world.distance_squared_to(box.get_center())
		if gap < best_gap:
			best_gap = gap
			best = id
	return best
