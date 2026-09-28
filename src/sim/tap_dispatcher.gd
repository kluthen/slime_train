class_name TapDispatcher
extends RefCounted
## Which tap zone a tap lands in (master spec §5.5, D15, D33, D57), checked
## in the spec's order:
##
##   1. the top band of the screen (TOP_BAND_HEIGHT): the parent zone. It
##      reveals the parent buttons (chunk 18) and never calls;
##   2. the left and right edge buttons (EDGE_BUTTON_SIZE, vertically
##      centred on the screen's sides): they move the camera (chunk 12) and
##      never call;
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
## Placeholder sizes: the top band and the edge buttons are interface design
## (ux-writer); they are tuning constants here until the ui_ux tree settles
## them.
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_interactive_objects_general]]

const ZONE_PARENT := "parent_zone"
const ZONE_EDGE := "edge_button"
const ZONE_OBJECT := "object"
const ZONE_GROUND := "open_ground"

## Placeholder: the height of the parent zone at the top of the screen,
## screen pixels.
const TOP_BAND_HEIGHT := 64.0
## Placeholder: each edge button's size, screen pixels. They sit against the
## left and right sides, vertically centred.
const EDGE_BUTTON_SIZE := Vector2(96, 192)
## How much larger than the object's box its hit area is, on every side,
## screen pixels.
const OBJECT_HIT_MARGIN := 24.0

## The tap target kinds (LevelData.tap_targets). Only a sleeper calls.
const KIND_SWITCH := "switch"
const KIND_BASKET := "basket"
const KIND_SLEEPER := "sleeper"


## The left (side -1) or right (side 1) edge button's rectangle on a screen
## of `screen_size`, screen pixels.
static func edge_button_rect(side: int, screen_size: Vector2) -> Rect2:
	var y := (screen_size.y - EDGE_BUTTON_SIZE.y) * 0.5
	var x := 0.0 if side < 0 else screen_size.x - EDGE_BUTTON_SIZE.x
	return Rect2(Vector2(x, y), EDGE_BUTTON_SIZE)


## The zone of a tap at `at` (screen pixels) with the view `view`, the level's
## tap targets being `tap_targets` (LevelData.tap_targets: stable ID ->
## {"kind", "box"}). Returns {"zone", "world" (the tap in level pixels),
## "side" (-1 or 1 for an edge button, else 0), "object" (the stable ID, or
## ""), "kind" (the object's kind, or ""), "call" (whether it calls),
## "call_point" (level pixels: the tap, or the sleeper's centre)}.
static func dispatch(at: Vector2, view: ScreenView, tap_targets: Dictionary) -> Dictionary:
	var world := view.screen_to_world(at)
	var result := {"zone": ZONE_GROUND, "world": world, "side": 0, "object": "", "kind": "",
			"call": true, "call_point": world}
	if at.y < TOP_BAND_HEIGHT:
		result["zone"] = ZONE_PARENT
		result["call"] = false
		return result
	for side in [-1, 1]:
		if edge_button_rect(side, view.screen_size).has_point(at):
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
