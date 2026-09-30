class_name TapFeedback
extends Node2D
## Draws what the simulation says about taps, above the slimes: every tap's
## ripple, an expanding ring where the finger touched (D65), and each slime's
## facing, a placeholder eye dot on the side it looks at (slimes in range
## turn toward a tap), for the slimes that can be seen only
## (SlimeRenderer.is_seen: not parked, on the shown part of the world). Also
## the first-play hint (Hint), while it shows: a wordless touch mark pulsing
## around the first sleeper (D65). It only reads
## the simulation. Placeholder art until the ui_ux tree settles the look.
## Place it at the world origin. It redraws only when what it draws may have
## changed (refresh()); the eyes of one radius are one instanced draw
## (ShapeInstances, a child drawn after the ripples and the hint).
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_first_play_hint]]

const RIPPLE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
## The ripple's radius at its start and end, and its line width, screen pixels.
const RIPPLE_FROM := 10.0
const RIPPLE_TO := 64.0
const RIPPLE_WIDTH := 3.0
const EYE_COLOR := Color(0.05, 0.05, 0.1)
## The eye dot's radius, and how far out from the centre it sits, as shares
## of the slime's ring radius.
const EYE_SIZE := 0.16
const EYE_OUT := 0.5
const HINT_COLOR := Color(1.0, 1.0, 1.0, 0.85)
## One pulse of the hint, seconds of simulated time (so a recorded run
## shows the same frames).
const HINT_PULSE_SECONDS := 1.2
## The hint's ring: its radius swells from HINT_FROM to HINT_TO and fades
## (screen pixels), with a steady inner ring at HINT_FROM.
const HINT_FROM := 34.0
const HINT_TO := 58.0
const HINT_WIDTH := 4.0

## The simulation drawn.
var simulation: Simulation = null
## The real time its per-frame work took, microseconds: _process checking
## whether a redraw is due and _draw drawing (only on a frame that redraws),
## summed until the debug perf log takes it (and sets it back to 0); nothing
## else reads it. Always counted: a few clock reads a frame.
# @spec-link [[req_platform_and_performance_targets]]
var frame_cost_usec := 0

## The eyes, one instanced draw per eye radius (eye radius -> its
## ShapeInstances, a child: draw_circle()'s disc of that radius in
## EYE_COLOR), made the first time an eye of that radius shows and kept (a
## slime's ring radius depends on its size only, so there are a few).
# @spec-link [[req_platform_and_performance_targets]]
var _eye_groups := {}
## What the last redraw asked for was drawn from (_drawn_key(), and the
## slimes' centres, calm and ring radii); [] before the first.
# @spec-link [[req_platform_and_performance_targets]]
var _drawn: Array = []
var _drawn_centre := PackedVector2Array()
var _drawn_calm := PackedByteArray()
var _drawn_radius := PackedFloat32Array()


func _init() -> void:
	z_index = 10


## Asks for a redraw when due (refresh()); the time it took goes to
## frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _process(_delta: float) -> void:
	var start_usec := Time.get_ticks_usec()
	refresh()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## Asks for a redraw when what _paint() draws from may have changed since the
## last one asked: another simulation, a tick (the ripples and the hint
## animate with it, the slimes move, turn and park in it), the view (zoom,
## shown part of the world), or the slimes changed between ticks (the debug
## tools move them). Otherwise the drawn picture stays on screen. Returns
## whether it asked.
# @spec-link [[req_platform_and_performance_targets]]
func refresh() -> bool:
	var key := _drawn_key()
	var slimes := simulation.slimes if simulation != null else null
	if key == _drawn and (slimes == null or (slimes.centre == _drawn_centre
			and slimes.calm == _drawn_calm and slimes.ring_radius == _drawn_radius)):
		return false
	_drawn = key
	if slimes != null:
		_drawn_centre = slimes.centre.duplicate()
		_drawn_calm = slimes.calm.duplicate()
		_drawn_radius = slimes.ring_radius.duplicate()
	queue_redraw()
	return true


## The values _paint() draws from, besides the slimes' centres, calm and
## ring radii (refresh() compares those itself), as a value to compare.
# @spec-link [[req_platform_and_performance_targets]]
func _drawn_key() -> Array:
	if simulation == null:
		return [0]
	var slimes := simulation.slimes
	return [simulation.get_instance_id(), simulation.tick, simulation.view.zoom,
			SlimeRenderer.shown_rect(get_viewport()), simulation.ripples.size(),
			simulation.hint.visible, simulation.hint.position, slimes.get_instance_id(),
			slimes.slime_count, slimes.topology_version]


## Draws this frame (_paint()), adding the time it took to frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _draw() -> void:
	var start_usec := Time.get_ticks_usec()
	_paint()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## This frame's drawing: every ripple, the hint while it shows, and the
## seen slimes' eyes (drawn after them, by the eye groups).
func _paint() -> void:
	for group: ShapeInstances in _eye_groups.values():
		group.clear()
	if simulation != null:
		_paint_taps()
		_paint_eyes()
	for group: ShapeInstances in _eye_groups.values():
		group.commit()


## Every ripple and the hint while it shows.
func _paint_taps() -> void:
	var zoom := simulation.view.zoom
	for ripple in simulation.ripples:
		var age := clampf(float(simulation.tick - ripple["tick"]) / Simulation.RIPPLE_TICKS, 0.0, 1.0)
		var radius := lerpf(RIPPLE_FROM, RIPPLE_TO, age) / zoom
		var color := Color(RIPPLE_COLOR, RIPPLE_COLOR.a * (1.0 - age))
		draw_arc(ripple["at"], radius, 0.0, TAU, 40, color, RIPPLE_WIDTH / zoom, true)
	var hint := simulation.hint
	if hint.visible:
		var pulse := fmod(float(simulation.tick) / Simulation.TICK_RATE, HINT_PULSE_SECONDS) / HINT_PULSE_SECONDS
		var swell := lerpf(HINT_FROM, HINT_TO, pulse) / zoom
		draw_arc(hint.position, HINT_FROM / zoom, 0.0, TAU, 40, HINT_COLOR, HINT_WIDTH / zoom, true)
		draw_arc(hint.position, swell, 0.0, TAU, 48, Color(HINT_COLOR, HINT_COLOR.a * (1.0 - pulse)),
				HINT_WIDTH / zoom, true)


## Hands each seen slime's eye to the group of its radius (the eye groups
## were cleared): one draw call per eye radius, where a draw_circle() each
## made one per eye. The eye colour is opaque, so which group draws first
## doesn't show.
# @spec-link [[req_platform_and_performance_targets]]
func _paint_eyes() -> void:
	var slimes := simulation.slimes
	for s in eyed_slimes(slimes, SlimeRenderer.shown_rect(get_viewport())):
		var slime_id := slimes.id[s]
		var r := slimes.ring_radius[s]
		var look: Vector2 = simulation.facing.get(slime_id, Vector2.RIGHT)
		var at := slimes.centre_of(slime_id) + look * r * EYE_OUT + Vector2(0.0, -r * 0.2)
		_eye_group(r * EYE_SIZE).add(at)


## The eye group of eye radius `radius` (see _eye_groups), made (and added
## as a child) the first time.
# @spec-link [[req_platform_and_performance_targets]]
func _eye_group(radius: float) -> ShapeInstances:
	var group: ShapeInstances = _eye_groups.get(radius)
	if group == null:
		group = ShapeInstances.new()
		group.name = "Eyes%d" % _eye_groups.size()
		group.self_modulate = EYE_COLOR
		group.set_disc(radius)
		_eye_groups[radius] = group
		add_child(group)
	return group


## The slime indices of `slimes` whose eye is drawn: those that can be seen
## on world rect `shown` (SlimeRenderer.is_seen), in slime index order.
static func eyed_slimes(slimes: SlimeBodies, shown: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	for s in slimes.slime_count:
		if SlimeRenderer.is_seen(slimes, s, shown):
			out.append(s)
	return out

