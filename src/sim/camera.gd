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
## O70's behaviour (D102): a press moves the camera at least STEP along the
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
## the view catches up (CATCH_UP) while the press moves it on. The dead zone
## (D101, on_call()): a call whose point is already inside a box centred on
## the screen, DEAD_ZONE of its width by DEAD_ZONE of its height (measured on
## the screen, whatever the zoom), doesn't move the camera; off the rails
## (a drag, a return) it holds the camera where it is for the call's window,
## then the camera glides back as after any call.
##
## Framing zones (FramingZone, LevelData.framing_zones). While the camera's
## rail point (the rails' place, before any framing) is inside a zone's box,
## the zone sets the zoom and shifts the camera by its offset: both ease there
## smoothly (FRAME_EASE), and back when the rail point leaves. The framed
## place is the rail point plus the shift, so a zone reframes the rails, it
## doesn't pin the view. Leaving a zone through the edge buttons takes a
## longer push (O70, "Leaving a framing zone"): a move that would take the
## rail point out of the zone is held at its edge until the button has been
## held for EXIT_HOLD (about 1 s) since it was pressed in the zone (a zone
## may ask for longer, its exit_hold). A short press, or a hold let go before
## then, stays inside; a hold that has lasted long enough carries on out,
## the ease after the finger lifts included. Holding across a whole zone at
## PACE is not slowed, as long as crossing takes longer than the exit hold.
## Calls still drag the camera out of a zone; it keeps the zone's framing
## while dragged and is framed again by wherever its rail point lands.
##
## Idle camera and screensaver mode (§5.6, §5.7). After IDLE_SECONDS with no
## finger on the screen (tilt is not counted), the camera leaves the rails and
## follows the train slime nearest its point, gliding there (FOLLOW_EASE,
## FOLLOW_PACE) and keeping it RAIL_OFFSET under the middle of the view. From
## CUE_SECONDS before, the cue: a slow zoom-out toward IDLE_ZOOM, the one zoom
## idle and screensaver mode share (15 % wider than normal play). Framing zones
## are ignored while following. Through fusion it follows the fused slime (the
## lower id, which SlimeBodies.merge keeps); through splitting, the piece that
## keeps the id (SlimeBodies.split's first part); if its slime is gone any
## other way, the train slime nearest where it was. Any touch takes the camera
## back (touched()) and still does its normal job: the camera glides back to
## the rails as after a call, framed again only if its point is still inside
## a zone; an edge button puts it straight back on the rails and moves it on,
## a call drags it. Screensaver mode (Simulation.screensaver, driven by
## sessions in chunk 17) starts on the idle camera at once, at IDLE_ZOOM; a
## touch takes the camera back there too, and it idles again after the usual
## IDLE_SECONDS. The idle zoom never zooms in (D103): where the camera is
## already wider (inside a wide framing zone), the cue and the idle camera
## keep that zoom (_idle_zoom()). At bedtime (watch()'s `bedtime`) the idle
## camera follows no one: it drops its slime and stays where it is, and none
## starts; the cue may still settle the zoom. At sunrise it follows the train
## slime nearest it again.
##
## Showing a gate open (§5.6, show_gate()). When a basket fires and its gate
## isn't wholly in view, the camera glides (SHOW) in SHOW_SECONDS to the rail
## point nearest the gate, framed by the zone there, and is on the rails
## there: it stays under normal control. A touch takes it back as from the
## idle camera. The show ends the idle camera and restarts the idle clock, so
## the camera stays at the gate. No show while an edge button is held.
##
## The zoom is the camera's: no input sets it (DoD 18); framing zones, the
## cue and the idle camera do.
# @spec-link [[req_camera_rails_and_framing]]
# @spec-link [[req_idle_camera_and_screensaver_zoom]]
# @spec-link [[req_camera_shows_gate_opening]]

## On the rails.
const RAILS := "rails"
## Pulled toward a call point.
const DRAG := "drag"
## Gliding back to the rails after a call, or after a touch ends following.
const RETURN := "return"
## The idle camera: following a train slime.
const FOLLOW := "follow"
## Gliding to a gate a basket fired open, to show it opening.
const SHOW := "show"

## The camera's point on a rail, from the loop's point: up a little, so the
## view shows the world above the route more than the ground under it. One
## constant for the whole loop; a framing zone's offset (chunk 13) adjusts a
## place that needs it.
const RAIL_OFFSET := Vector2(0, -120)
## The fixed step one press moves at least, px along the loop: a third of a
## screen (specs/tuning.md, "Edge-button press": to try, D102).
const STEP := LevelData.SCREEN / 3.0
## The steady pace while the button is held, px per second along the loop:
## three quarters of a screen a second (to try).
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
## How long an edge button must be held to leave a framing zone, s (O70's
## default, D102: about 1 s; a zone's exit_hold overrides it).
const EXIT_HOLD := 1.0
## How fast the framing (zoom and shift) closes on a zone's, per second: it
## changes by FRAME_EASE times the difference left each second, so it eases
## in and settles (about 2 s from normal play to a zone's).
const FRAME_EASE := 1.5
## The slowest the zoom eases, per second (SETTLE is the shift's): close to
## its goal it keeps this pace and lands on it.
const ZOOM_SETTLE := 0.02
## Seconds with no touch before the idle camera takes over (§5.6).
const IDLE_SECONDS := 45.0
## How long the cue lasts before the idle camera, s: a slow zoom-out.
const CUE_SECONDS := 10.0
## The zoom idle and screensaver mode share: 15 % wider than normal play
## (the spec's 10-20 %; one zoom, it never stacks with a zone's).
const IDLE_ZOOM := 1.0 / 1.15
## How fast the idle camera closes on the slime it follows, per second (as
## EASE), and the fastest it goes, px per second: above a slime's slide
## speed, so it keeps up.
const FOLLOW_EASE := 2.0
const FOLLOW_PACE := LevelData.SCREEN * 0.5
## The call's dead zone: a box centred on the screen, this fraction of its
## width by this fraction of its height (§5.6, D101).
const DEAD_ZONE := 0.2
## How long the glide to a gate a basket fired open lasts, s (§5.6: about
## 1.5 s).
const SHOW_SECONDS := 1.5

## RAILS, DRAG, RETURN, FOLLOW or SHOW.
var mode := RAILS
## Screen pixels per level pixel, as ScreenView.zoom. No input changes it:
## framing zones, the cue and the idle camera do.
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

## The level's framing zones (LevelData.framing_zones): stable ID -> {"box",
## "zoom", "offset", "exit_hold"}. Level data, not state: set before start().
var zones: Dictionary = {}:
	set(value):
		zones = value
		_zone_ids = value.keys()
		_zone_ids.sort()
## The framing zone framing the camera, or "".
var frame_zone := ""
## How far the framing shifts the camera from its rail point, level px:
## eases toward the zone's offset (zero outside zones).
var frame_shift := Vector2.ZERO
## Ticks the edge button has been held since it was pressed in the current
## zone: at the zone's exit hold, the camera may leave it.
var zone_hold := 0
## Ticks since the last touch (a finger down counts all along).
var quiet := 0
## The zoom the cue started from, or -1 when no cue is on.
var cue_from := -1.0
## The slime the idle camera follows, or -1; its species and where it was
## last seen (level px), to find it again after a fusion.
var follow_id := -1
var follow_species := -1
var follow_point := Vector2.ZERO
## Screensaver mode as last seen (watch()): turning it on starts the idle
## camera.
var screensaver := false
## The glide to a gate (SHOW): the rail distance it ends on, and the tick it
## began, or -1.
var show_distance := -1.0
var show_tick := -1

## The side of a press not yet applied: press() records it, step() applies it
## (a press needs the loop, and may be lifted on the same tick).
var _pressed := 0
## Whether a touch landed since the last watch().
var _touched := false
## The zones' IDs, sorted: the smaller ID wins where boxes overlap.
var _zone_ids: Array = []


## Puts the camera on the rails of `loop` (the current segments for
## `open_gates`), at the rail point nearest `near` (a level point), or at the
## start of the loop when `near` is null. Without a loop it stays put.
# @spec-link [[rule_return_route_per_section]]
func start(loop: LoopData, open_gates: Array, near: Variant = null) -> void:
	mode = RAILS
	rail_left = 0.0
	rail_gap = Vector2.ZERO
	hold_finger = -1
	hold_side = 0
	drag_tick = -1
	return_distance = -1.0
	_pressed = 0
	zone_hold = 0
	quiet = 0
	cue_from = -1.0
	_stop_following()
	screensaver = false
	show_distance = -1.0
	show_tick = -1
	_touched = false
	frame_zone = ""
	frame_shift = Vector2.ZERO
	zoom = 1.0
	if not _has_rails(loop, open_gates):
		return
	rail_length = loop.length(open_gates)
	distance = loop.closest(near, open_gates)["distance"] if near is Vector2 else 0.0
	var base := rail_point(loop, open_gates, distance)
	frame_zone = zone_at(base)
	frame_shift = _zone_offset(frame_zone)
	zoom = _zone_zoom(frame_zone)
	position = base + frame_shift


## An edge button pressed by `finger`: `side` -1 is the left button
## (backward), 1 the right (forward). The press is applied on the next step().
# @spec-link [[req_controls_tap_zones]]
func press(side: int, finger: int) -> void:
	_take_back()
	_pressed = side
	hold_side = side
	hold_finger = finger
	zone_hold = 0


## A finger lifting: if it was holding an edge button, the camera eases to a
## stop.
# @spec-link [[req_controls_tap_zones]]
func release(finger: int) -> void:
	if finger == hold_finger:
		hold_finger = -1
		hold_side = 0


## A call at `point` (level px) on `tick`: the camera leaves the rails and is
## pulled toward it. A new call replaces the point and restarts the pull.
func follow_call(point: Vector2, tick: int) -> void:
	_take_back()
	mode = DRAG
	drag_point = point
	drag_tick = tick
	rail_left = 0.0
	rail_gap = Vector2.ZERO


## A call at `point` (level px) on `tick`, `view` showing the camera: inside
## the dead zone it doesn't move the camera (on the rails it stays as it is;
## off them it is held where it is for the call's window, which stops a
## drag); outside, the call drag (follow_call()).
# @spec-link [[req_camera_rails_and_framing]]
# @spec-link [[req_call_mechanic]]
func on_call(point: Vector2, tick: int, view: ScreenView) -> void:
	if not in_dead_zone(point, view):
		follow_call(point, tick)
		return
	_take_back()
	if mode == RAILS:
		return
	follow_call(position, tick)


## Whether level point `point` shows inside the call's dead zone of `view`:
## the box centred on the screen, DEAD_ZONE of its width by DEAD_ZONE of its
## height, on the screen whatever the zoom.
static func in_dead_zone(point: Vector2, view: ScreenView) -> bool:
	var half := view.screen_size * DEAD_ZONE * 0.5
	var off := view.world_to_screen(point) - view.screen_size * 0.5
	return absf(off.x) <= half.x and absf(off.y) <= half.y


## A basket fired open the gate whose box is `box` (level px) on `tick`, the
## player seeing `view`: unless the whole gate is in view (or an edge button
## is held), the camera glides to the rail point nearest it on `loop`'s
## current segments for `open_gates` (the gate already open), framed by the
## zone there. It ends the idle camera and restarts the idle clock.
# @spec-link [[req_camera_shows_gate_opening]]
func show_gate(box: Rect2, view: ScreenView, loop: LoopData, open_gates: Array, tick: int) -> void:
	if hold_finger >= 0 or not _has_rails(loop, open_gates):
		return
	if Fusion.view_rect(view).encloses(box):
		return
	_stop_following()
	mode = SHOW
	show_distance = loop.closest(box.get_center(), open_gates)["distance"]
	show_tick = tick
	rail_left = 0.0
	rail_gap = Vector2.ZERO
	drag_tick = -1
	return_distance = -1.0
	_pressed = 0
	quiet = 0
	cue_from = -1.0
	frame_zone = zone_at(rail_point(loop, open_gates, show_distance))
	zone_hold = 0


## Puts the camera at `centre` (level px), off the rails, at `view_zoom`: it
## glides back to the rails as after a call, framed by the zone its centre
## is in, if any (the zoom eases from `view_zoom` to that zone's). It ends the
## idle camera and restarts the idle clock. For tests and debugging, and the
## hook for later chunks that place the camera; not an input. A zoom of 0 or
## less can only be a caller bug: it is refused loudly and the camera is left
## as it was.
func place(centre: Vector2, view_zoom := 1.0) -> void:
	if view_zoom <= 0.0:
		push_error("Camera.place: the zoom must be above 0, got %s" % view_zoom)
		return
	position = centre
	zoom = view_zoom
	mode = RETURN
	return_distance = -1.0
	rail_left = 0.0
	rail_gap = Vector2.ZERO
	drag_tick = -1
	_stop_following()
	quiet = 0
	cue_from = -1.0
	frame_zone = zone_at(centre)
	frame_shift = _zone_offset(frame_zone)
	zone_hold = 0


## A touch landed (the Simulation calls it for a touch that counts, before
## the tap does its job): the idle clock starts again, the cue stops, and the
## idle camera hands the camera back. It glides back to the rails as after a
## call, framed only if its point is still inside a zone; the tap's own job
## (an edge press, a call) then applies as usual.
func touched() -> void:
	_touched = true
	quiet = 0
	cue_from = -1.0
	_take_back()


## Once a tick, before step(): whether a finger is `touching` the screen,
## whether the game is in `screensaver_mode`, whether it is `bedtime`, and
## the slimes (`bodies`) for the idle camera. Runs the idle clock, the cue,
## and which slime to follow (no one at bedtime).
# @spec-link [[req_idle_camera_and_screensaver_zoom]]
# @spec-link [[req_session_lifecycle]]
func watch(bodies: SlimeBodies, touching: bool, screensaver_mode: bool, bedtime: bool) -> void:
	var idle_ticks := int(IDLE_SECONDS * Simulation.TICK_RATE)
	var cue_ticks := int(CUE_SECONDS * Simulation.TICK_RATE)
	var starting := screensaver_mode and not screensaver
	screensaver = screensaver_mode
	if touching or _touched:
		quiet = 0
		cue_from = -1.0
	else:
		quiet += 1
		if starting:
			# Screensaver mode starts on the idle camera: no wait, no cue.
			quiet = maxi(quiet, idle_ticks)
	_touched = false
	if mode == FOLLOW:
		if bedtime:
			_follow_no_one()
		else:
			_keep_following(bodies)
		return
	if quiet < idle_ticks - cue_ticks:
		return
	if cue_from < 0.0:
		cue_from = zoom
	var goal := _idle_zoom(cue_from)
	var t := clampf(float(quiet - (idle_ticks - cue_ticks)) / cue_ticks, 0.0, 1.0)
	zoom = goal if t >= 1.0 else lerpf(cue_from, goal, smoothstep(0.0, 1.0, t))
	if quiet >= idle_ticks and not bedtime:
		_start_following(bodies)


## Advances the camera by `dt` seconds on `tick`, on `loop`'s current
## segments for `open_gates` (null or empty: no rails, it stays put).
func step(loop: LoopData, open_gates: Array, dt: float, tick: int) -> void:
	if mode == FOLLOW:
		_pressed = 0
		zoom = _idle_zoom(zoom)
		if follow_id < 0:
			# Following no one (bedtime): it stays where it is.
			return
		var goal := follow_point + RAIL_OFFSET
		var speed := clampf(position.distance_to(goal) * FOLLOW_EASE, SETTLE, FOLLOW_PACE)
		position = position.move_toward(goal, speed * dt)
		return
	_ease_framing(dt)
	var has_rails := _has_rails(loop, open_gates)
	if not has_rails:
		_pressed = 0
		if mode == RETURN or mode == SHOW:
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
			distance = loop.closest(position - rail_gap - frame_shift - RAIL_OFFSET, open_gates)["distance"]
			rail_gap = position - frame_shift - rail_point(loop, open_gates, distance)
		return_distance = -1.0
		rail_length = length
	if _pressed != 0:
		if mode != RAILS:
			_back_on_rails(loop, open_gates)
		rail_left = _pushed(rail_left, _pressed)
		_pressed = 0
	match mode:
		RAILS:
			if hold_finger >= 0 and frame_zone != "":
				zone_hold += 1
			if hold_side != 0:
				rail_left = _pushed(rail_left, hold_side)
			var was := distance
			var was_left := rail_left
			_move_along(length, dt)
			if _fenced(loop, open_gates, was):
				# Held at the zone's edge: a held button keeps pushing, a
				# short press is spent.
				distance = was
				rail_left = was_left if hold_finger >= 0 else 0.0
			rail_gap = rail_gap.move_toward(Vector2.ZERO, CATCH_UP * dt)
			var base := rail_point(loop, open_gates, distance)
			_frame_at(base)
			position = base + frame_shift + rail_gap
		DRAG:
			if _call_over(tick):
				mode = RETURN
				return_distance = -1.0
			else:
				position = position.move_toward(drag_point, DRAG_PACE * dt)
		SHOW:
			_glide_to_gate(loop, open_gates, tick)
	if mode == RETURN:
		if return_distance < 0.0:
			return_distance = loop.closest(position - frame_shift - RAIL_OFFSET, open_gates)["distance"]
		var target := rail_point(loop, open_gates, return_distance) + frame_shift
		position = position.move_toward(target, DRAG_PACE * dt)
		if position == target:
			mode = RAILS
			distance = return_distance
			return_distance = -1.0
			rail_left = 0.0
			rail_gap = Vector2.ZERO
			_frame_at(rail_point(loop, open_gates, distance))


## Whether the camera is on the rails (not dragged by a call, returning,
## following nor showing a gate).
func is_on_rails() -> bool:
	return mode == RAILS


## The framing zone whose box holds `point` (level px), or "": the current
## zone while it still holds it, else the smaller ID where boxes overlap.
# @spec-link [[rule_framing_zone_wherever_wider_view_needed]]
func zone_at(point: Vector2) -> String:
	if frame_zone != "" and zones.has(frame_zone) and (zones[frame_zone]["box"] as Rect2).has_point(point):
		return frame_zone
	for id in _zone_ids:
		if (zones[id]["box"] as Rect2).has_point(point):
			return id
	return ""


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
		"frame_zone": frame_zone,
		"frame_shift": frame_shift,
		"zone_hold": zone_hold,
		"quiet": quiet,
		"cue_from": cue_from,
		"follow_id": follow_id,
		"follow_species": follow_species,
		"follow_point": follow_point,
		"screensaver": screensaver,
		"show_distance": show_distance,
		"show_tick": show_tick,
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
	frame_zone = str(data.get("frame_zone", ""))
	frame_shift = _vector(data.get("frame_shift", Vector2.ZERO))
	zone_hold = int(data.get("zone_hold", 0))
	quiet = int(data.get("quiet", 0))
	cue_from = float(data.get("cue_from", -1.0))
	follow_id = int(data.get("follow_id", -1))
	follow_species = int(data.get("follow_species", -1))
	follow_point = _vector(data.get("follow_point", Vector2.ZERO))
	screensaver = bool(data.get("screensaver", false))
	show_distance = float(data.get("show_distance", -1.0))
	show_tick = int(data.get("show_tick", -1))
	_pressed = 0
	_touched = false


## A press takes the camera from off the rails straight back onto them, at
## the rail point nearest it; the view catches up from where it was.
func _back_on_rails(loop: LoopData, open_gates: Array) -> void:
	distance = loop.closest(position - frame_shift - RAIL_OFFSET, open_gates)["distance"]
	rail_gap = position - frame_shift - rail_point(loop, open_gates, distance)
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


## Whether the move from `was` px along the rails to `distance` takes the
## rail point out of the framing zone before the button has been held long
## enough to leave it.
func _fenced(loop: LoopData, open_gates: Array, was: float) -> bool:
	if frame_zone == "" or distance == was or not zones.has(frame_zone):
		return false
	if zone_hold >= _exit_ticks(frame_zone):
		return false
	var box: Rect2 = zones[frame_zone]["box"]
	return box.has_point(rail_point(loop, open_gates, was)) and not box.has_point(rail_point(loop, open_gates, distance))


## How many ticks of holding leave zone `id`.
func _exit_ticks(id: String) -> int:
	var hold := float(zones[id].get("exit_hold", -1.0))
	if hold < 0.0:
		hold = EXIT_HOLD
	return roundi(hold * Simulation.TICK_RATE)


## Frames the camera by the zone holding the rail point `base`: a new zone
## restarts the exit hold.
# @spec-link [[rule_framing_zone_wherever_wider_view_needed]]
func _frame_at(base: Vector2) -> void:
	var zone := zone_at(base)
	if zone != frame_zone:
		frame_zone = zone
		zone_hold = 0


## Eases the shift and the zoom toward the framing zone's (normal play
## outside zones) for `dt` seconds. The cue has the zoom while it runs.
func _ease_framing(dt: float) -> void:
	var shift := _zone_offset(frame_zone)
	frame_shift = frame_shift.move_toward(shift, maxf(frame_shift.distance_to(shift) * FRAME_EASE, SETTLE) * dt)
	if cue_from >= 0.0:
		return
	var goal := _zone_zoom(frame_zone)
	zoom = move_toward(zoom, goal, maxf(absf(goal - zoom) * FRAME_EASE, ZOOM_SETTLE) * dt)


func _zone_zoom(id: String) -> float:
	return float(zones[id]["zoom"]) if zones.has(id) else 1.0


func _zone_offset(id: String) -> Vector2:
	return zones[id]["offset"] if zones.has(id) else Vector2.ZERO


## Starts the idle camera on the train slime nearest the camera's point; with
## none, it tries again next tick.
func _start_following(bodies: SlimeBodies) -> void:
	var chosen := _nearest_train(bodies, position)
	if chosen < 0:
		return
	mode = FOLLOW
	_follow(bodies, chosen)
	zoom = _idle_zoom(zoom)
	cue_from = -1.0
	frame_zone = ""
	frame_shift = Vector2.ZERO
	zone_hold = 0
	rail_left = 0.0
	rail_gap = Vector2.ZERO
	drag_tick = -1
	return_distance = -1.0
	_pressed = 0


## Finds the followed slime again: the same id (a split keeps it on one
## piece), else the fused slime (the nearest of its species with a lower id,
## SlimeBodies.merge keeping the lower), else the train slime nearest where
## it was.
func _keep_following(bodies: SlimeBodies) -> void:
	if follow_id >= 0 and bodies.has(follow_id):
		follow_point = bodies.centre_of(follow_id)
		return
	var fused := -1
	var best := INF
	for slime_id in bodies.ids():
		if slime_id >= follow_id or bodies.species_of(slime_id) != follow_species:
			continue
		var gap := bodies.centre_of(slime_id).distance_squared_to(follow_point)
		if gap < best:
			fused = slime_id
			best = gap
	if fused < 0:
		fused = _nearest_train(bodies, follow_point)
	if fused >= 0:
		_follow(bodies, fused)


func _follow(bodies: SlimeBodies, slime_id: int) -> void:
	follow_id = slime_id
	follow_species = bodies.species_of(slime_id)
	follow_point = bodies.centre_of(slime_id)


## At bedtime the idle camera follows no one: it drops its slime and stays
## where it is; after it, the train slime nearest the camera's point is
## followed (_keep_following()'s last resort, from follow_point).
func _follow_no_one() -> void:
	if follow_id < 0:
		return
	_stop_following()
	follow_point = position


## The zoom the cue and the idle camera go to from `from`: IDLE_ZOOM, or
## `from` where that is already wider (it never zooms in, D103).
static func _idle_zoom(from: float) -> float:
	return minf(IDLE_ZOOM, from)


## One tick of the glide to a gate (SHOW): the camera closes on the framed
## rail point at show_distance so as to reach it SHOW_SECONDS after the show
## began, then is on the rails there.
func _glide_to_gate(loop: LoopData, open_gates: Array, tick: int) -> void:
	var base := rail_point(loop, open_gates, show_distance)
	var target := base + frame_shift
	var left := show_tick + roundi(SHOW_SECONDS * Simulation.TICK_RATE) - tick
	if left > 1:
		position += (target - position) / left
		return
	mode = RAILS
	distance = show_distance
	show_distance = -1.0
	show_tick = -1
	position = target
	_frame_at(base)


## The train slime whose centre is nearest `point`, or -1 (the smaller id on
## a tie).
static func _nearest_train(bodies: SlimeBodies, point: Vector2) -> int:
	var nearest := -1
	var best := INF
	for slime_id in bodies.ids():
		if bodies.state_of(slime_id) != SlimeBodies.TRAIN:
			continue
		var gap := bodies.centre_of(slime_id).distance_squared_to(point)
		if gap < best:
			nearest = slime_id
			best = gap
	return nearest


## Ends the idle camera or the glide to a gate, if on: the camera glides back
## to the rails as after a call, framed by the zone its point is in, if any.
func _take_back() -> void:
	if mode != FOLLOW and mode != SHOW:
		return
	mode = RETURN
	return_distance = -1.0
	show_distance = -1.0
	show_tick = -1
	_stop_following()
	frame_zone = zone_at(position)
	zone_hold = 0


func _stop_following() -> void:
	follow_id = -1
	follow_species = -1
	follow_point = Vector2.ZERO


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
