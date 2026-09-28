class_name Camera
extends RefCounted
## The camera, as pure simulation logic (master spec §5.6): the view decides
## where taps land, how wide the call reaches and (chunk 15) what is on
## screen, so it lives in the simulation, deterministic and scriptable. The
## scene's Camera2D only mirrors it (src/main.gd), through the simulation's
## ScreenView (apply_to()).
##
## Rails. On the rails, the camera's place is a distance along the current
## loop (LoopData, the segments in use for the open gates), including the
## section's return route, which has its own rail. Its point is the loop's
## point at that distance, plus RAIL_OFFSET so the view shows more of the
## world above the route than the ground under it. Forward is always
## increasing loop distance, backward decreasing, whatever the direction on
## screen: forward on a return route carries the camera round the frontier
## turn and back toward the start, and the rail wraps at the loop's end, like
## the train. The view never shows left of the level's left edge (x = 0): the
## camera may sit there, the view's centre is held in (view_centre()).
##
## Edge buttons (tap zone 2, TapDispatcher; right forward, left backward, D90),
## O70's proposed behaviour: a press moves the camera at least STEP along the
## rail; while the finger stays down the goal stays one STEP ahead, so the
## camera moves at a steady PACE; after the finger lifts it eases to a stop
## on the goal (EASE). They never call.
##
## Call drag. A call pulls the camera toward the call point at DRAG_PACE,
## slow and steady, off the rails, for the call's DRAG_SECONDS (the answering
## window, FreeSlimes.CALL_SECONDS) or until a new call replaces the point.
## Then it glides back, at the same pace, to the rail point nearest where it
## stopped, and is on the rails again (the return is a tuning value the spec
## leaves open; this is the reading taken). An edge-button press while off
## the rails puts it straight back on them at the nearest rail point, and
## the view catches up (CATCH_UP) while the press moves it on.
##
## The zoom is the camera's; no input changes it (DoD 18). Framing zones and
## the idle and screensaver zoom set it (chunk 13).
# @spec-link [[req_camera_rails_and_framing]]
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[rule_return_route_per_section]]

## On the rails.
const RAILS := "rails"
## Pulled toward a call point.
const DRAG := "drag"
## Gliding back to the rails after a call.
const RETURN := "return"

## The camera's point on a rail, from the loop's point: up a little, so the
## view shows the world above the route more than the ground under it. One
## constant for the whole loop; a framing zone's offset (chunk 13) adjusts a
## place that needs it.
const RAIL_OFFSET := Vector2(0, -120)
## The fixed step one press moves at least, px along the loop: a third of a
## screen (specs/tuning.md, "Edge-button press": proposed, to try).
const STEP := LevelData.SCREEN / 3.0
## The steady pace while the button is held, px per second along the loop:
## three quarters of a screen a second (proposed, to try).
const PACE := LevelData.SCREEN * 0.75
## How fast the camera closes on its goal once it is within reach, per
## second: it moves EASE times the distance left each second, never faster
## than PACE, so it eases to a stop. STEP * EASE must stay above PACE, or
## holding would be slower than PACE.
const EASE := 5.0
## The slowest the camera eases, px per second: close to its goal it keeps
## this pace and settles on it, rather than creeping at it forever.
const SETTLE := 30.0
## How fast the view catches up with the rail after a press takes the camera
## back onto it from off the rails, px per second.
const CATCH_UP := LevelData.SCREEN
## The call drag's pace, and the return's, px per second: a fifth of a
## screen a second (specs/tuning.md: "slow and steady").
const DRAG_PACE := LevelData.SCREEN * 0.2
## How long a call pulls the camera, s: the call's answering window.
const DRAG_SECONDS := FreeSlimes.CALL_SECONDS
## The level's left edge, level px (specs/levels/test/README.md: x = 0).
const LEVEL_LEFT := 0.0

## RAILS, DRAG or RETURN.
var mode := RAILS
## Screen pixels per level pixel, as ScreenView.zoom. No input changes it.
var zoom := 1.0
## The camera's point, level px: the middle of the view, before the level's
## left edge holds the view in (view_centre()).
var position := ScreenView.DEFAULT_SIZE * 0.5
## Where on the rails, px along the current loop from its start, in
## [0, loop length). Kept while off the rails.
var distance := 0.0
## How far the camera still has to go along the rails, px: positive is
## forward. A press sets it to a STEP; holding keeps it there.
var rail_left := 0.0
## How far the camera still is from its rail point after a press took it
## back onto the rails, level px; it shrinks at CATCH_UP.
var rail_gap := Vector2.ZERO
## The loop's length when last seen: a change means a gate opened and the
## loop changed, and the camera finds its place on the new one.
var rail_length := 0.0
## The finger holding an edge button, or -1, and which button: -1 left
## (backward), 1 right (forward), 0 none.
var hold_finger := -1
var hold_side := 0
## The call pulling the camera: its point (level px) and tick, or -1.
var drag_point := Vector2.ZERO
var drag_tick := -1
## The rail distance the camera glides back to after a call, or -1 until it
## is chosen (on the next step).
var return_distance := -1.0
## Whether the scene draws the edge buttons. Hidden at bedtime (chunk 17).
var edge_buttons_visible := true

## The side of a press not yet applied: press() records it, step() applies it
## (a press needs the loop, and may be lifted on the same tick).
var _pressed := 0


## Puts the camera on the rails of `loop` (the current segments for
## `open_gates`), at the rail point nearest `near` (a level point), or at the
## start of the loop when `near` is null. Without a loop it stays put.
func start(loop: LoopData, open_gates: Array, near: Variant = null) -> void:
	mode = RAILS
	rail_left = 0.0
	rail_gap = Vector2.ZERO
	hold_finger = -1
	hold_side = 0
	drag_tick = -1
	return_distance = -1.0
	_pressed = 0
	if not _has_rails(loop, open_gates):
		return
	rail_length = loop.length(open_gates)
	distance = loop.closest(near, open_gates)["distance"] if near is Vector2 else 0.0
	position = rail_point(loop, open_gates, distance)


## An edge button pressed by `finger`: `side` -1 is the left button
## (backward), 1 the right (forward). The press is applied on the next step().
func press(side: int, finger: int) -> void:
	_pressed = side
	hold_side = side
	hold_finger = finger


## A finger lifting: if it was holding an edge button, the camera eases to a
## stop.
func release(finger: int) -> void:
	if finger == hold_finger:
		hold_finger = -1
		hold_side = 0


## A call at `point` (level px) on `tick`: the camera leaves the rails and is
## pulled toward it. A new call replaces the point and restarts the pull.
func follow_call(point: Vector2, tick: int) -> void:
	mode = DRAG
	drag_point = point
	drag_tick = tick
	rail_left = 0.0
	rail_gap = Vector2.ZERO


## Puts the camera at `centre` (level px), off the rails, at `view_zoom`: it
## glides back to the rails as after a call. For tests and debugging, and the
## hook for later chunks that place the camera; not an input.
func place(centre: Vector2, view_zoom := 1.0) -> void:
	position = centre
	zoom = view_zoom if view_zoom > 0.0 else 1.0
	mode = RETURN
	return_distance = -1.0
	rail_left = 0.0
	rail_gap = Vector2.ZERO
	drag_tick = -1


## Advances the camera by `dt` seconds on `tick`, on `loop`'s current
## segments for `open_gates` (null or empty: no rails, it stays put).
func step(loop: LoopData, open_gates: Array, dt: float, tick: int) -> void:
	var has_rails := _has_rails(loop, open_gates)
	if not has_rails:
		_pressed = 0
		if mode == RETURN:
			mode = RAILS
		if mode == DRAG and _call_over(tick):
			mode = RAILS
		if mode == DRAG:
			position = position.move_toward(drag_point, DRAG_PACE * dt)
		return
	var length := loop.length(open_gates)
	if length != rail_length:
		# The loop changed (a gate opened): find the camera's place on it.
		if mode == RAILS:
			distance = loop.closest(position - rail_gap - RAIL_OFFSET, open_gates)["distance"]
			rail_gap = position - rail_point(loop, open_gates, distance)
		return_distance = -1.0
		rail_length = length
	if _pressed != 0:
		if mode != RAILS:
			_back_on_rails(loop, open_gates)
		rail_left = _pushed(rail_left, _pressed)
		_pressed = 0
	match mode:
		RAILS:
			if hold_side != 0:
				rail_left = _pushed(rail_left, hold_side)
			_move_along(length, dt)
			rail_gap = rail_gap.move_toward(Vector2.ZERO, CATCH_UP * dt)
			position = rail_point(loop, open_gates, distance) + rail_gap
		DRAG:
			if _call_over(tick):
				mode = RETURN
				return_distance = -1.0
			else:
				position = position.move_toward(drag_point, DRAG_PACE * dt)
	if mode == RETURN:
		if return_distance < 0.0:
			return_distance = loop.closest(position - RAIL_OFFSET, open_gates)["distance"]
		var target := rail_point(loop, open_gates, return_distance)
		position = position.move_toward(target, DRAG_PACE * dt)
		if position == target:
			mode = RAILS
			distance = return_distance
			return_distance = -1.0
			rail_left = 0.0
			rail_gap = Vector2.ZERO


## Whether the camera is on the rails (not dragged by a call nor returning).
func is_on_rails() -> bool:
	return mode == RAILS


## The camera's point on the rail at `at` px along `loop`'s current segments.
static func rail_point(loop: LoopData, open_gates: Array, at: float) -> Vector2:
	return loop.position_at(at, open_gates) + RAIL_OFFSET


## The middle of the view on a `screen_size` screen: the camera's point, held
## so the view never shows left of the level's left edge.
func view_centre(screen_size: Vector2) -> Vector2:
	var centre := position
	centre.x = maxf(centre.x, LEVEL_LEFT + screen_size.x * 0.5 / zoom)
	return centre


## Sets `view` to what the camera shows on a `screen_size` screen.
func apply_to(view: ScreenView, screen_size: Vector2) -> void:
	view.set_to(view_centre(screen_size), zoom, screen_size)


## The state as plain data (Simulation.dump, saves), floats at full
## precision so a restored camera carries on exactly.
func dump() -> Dictionary:
	return {
		"mode": mode,
		"zoom": zoom,
		"position": position,
		"distance": distance,
		"rail_left": rail_left,
		"rail_gap": rail_gap,
		"rail_length": rail_length,
		"hold_finger": hold_finger,
		"hold_side": hold_side,
		"drag_point": drag_point,
		"drag_tick": drag_tick,
		"return_distance": return_distance,
		"edge_buttons_visible": edge_buttons_visible,
	}


## Sets the state back from dump(), or from its JSON form (vectors as
## [x, y]).
func restore(data: Dictionary) -> void:
	mode = str(data.get("mode", RAILS))
	zoom = float(data.get("zoom", 1.0))
	position = _vector(data.get("position", position))
	distance = float(data.get("distance", 0.0))
	rail_left = float(data.get("rail_left", 0.0))
	rail_gap = _vector(data.get("rail_gap", Vector2.ZERO))
	rail_length = float(data.get("rail_length", 0.0))
	hold_finger = int(data.get("hold_finger", -1))
	hold_side = int(data.get("hold_side", 0))
	drag_point = _vector(data.get("drag_point", Vector2.ZERO))
	drag_tick = int(data.get("drag_tick", -1))
	return_distance = float(data.get("return_distance", -1.0))
	edge_buttons_visible = bool(data.get("edge_buttons_visible", true))
	_pressed = 0


## A press takes the camera from off the rails straight back onto them, at
## the rail point nearest it; the view catches up from where it was.
func _back_on_rails(loop: LoopData, open_gates: Array) -> void:
	distance = loop.closest(position - RAIL_OFFSET, open_gates)["distance"]
	rail_gap = position - rail_point(loop, open_gates, distance)
	mode = RAILS
	rail_left = 0.0
	drag_tick = -1
	return_distance = -1.0


## Moves `distance` toward its goal (`rail_left` ahead) for `dt` seconds: at
## PACE, easing within reach (never slower than SETTLE), wrapping round a
## `length` px loop.
func _move_along(length: float, dt: float) -> void:
	if rail_left == 0.0:
		return
	var reach := absf(rail_left)
	var move := minf(reach, maxf(minf(PACE, reach * EASE), SETTLE) * dt)
	move *= signf(rail_left)
	rail_left -= move
	distance = fposmod(distance + move, length)


## The distance left to go after a push on the button of `side`: at least a
## STEP that way (a press the other way turns back).
static func _pushed(left: float, side: int) -> float:
	if signf(left) != float(side):
		return side * STEP
	return side * maxf(absf(left), STEP)


## Whether the call pulling the camera is over on `tick`: DRAG_SECONDS after
## it, counted in simulation ticks as FreeSlimes counts the call's 8 s.
func _call_over(tick: int) -> bool:
	return tick - drag_tick >= int(DRAG_SECONDS * Simulation.TICK_RATE)


static func _has_rails(loop: LoopData, open_gates: Array) -> bool:
	return loop != null and loop.length(open_gates) > 0.0


static func _vector(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
