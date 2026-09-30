class_name TestModeOverlay
extends Node2D
## Test mode's on-screen marker, a developer aid rather than game interface: a
## banner with the tick, seed and time scale, and a ring on every finger
## down, so a debug run shows what the script is doing. It redraws only when
## the banner's text or the fingers change (refresh()).

const TEXT_COLOR := Color(1.0, 0.2, 0.8)
const FONT_SIZE := 16
const FINGER_RADIUS := 28.0

## The test mode it reports on.
var test_mode: TestMode = null
## How many times _draw ran (lets a headless test see that drawing happens).
var draw_count := 0
## The real time its per-frame work (_process and _draw) took,
## microseconds, summed until the debug perf log takes it (and sets it back
## to 0); nothing else reads it. Always counted: two clock reads a call.
# @spec-link [[req_platform_and_performance_targets]]
var frame_cost_usec := 0
## What the last redraw asked for showed (picture()); [] before the first.
# @spec-link [[req_platform_and_performance_targets]]
var _drawn: Array = []


## Asks for a redraw only when the picture changed (refresh()); the time it
## took goes to frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _process(_delta: float) -> void:
	var start_usec := Time.get_ticks_usec()
	refresh()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## Asks for a redraw when what _paint() draws changed since the last one
## asked (picture()): the banner and the rings drawn stay on screen until
## then. Returns whether it asked.
# @spec-link [[req_platform_and_performance_targets]]
func refresh() -> bool:
	var now := picture()
	if now == _drawn:
		return false
	_drawn = now
	queue_redraw()
	return true


## Everything _paint() draws from, as a value to compare: the banner text
## (banner()), then the fingers down and where they are, in drawing order;
## [""] without a game to report on.
# @spec-link [[req_platform_and_performance_targets]]
func picture() -> Array:
	if test_mode == null or test_mode.game == null:
		return [""]
	var sim: Simulation = test_mode.game.simulation
	return [banner(sim), sim.fingers_down.keys(), sim.fingers_down.values()]


## The banner's text for simulation `sim`: the tick, the seed and the time
## scale.
func banner(sim: Simulation) -> String:
	return "TEST MODE  tick %d  seed %d  time x%s" % [sim.tick, sim.rng.seed_value, test_mode.time_scale]


## Draws this frame (_paint()), adding the time it took to frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _draw() -> void:
	var start_usec := Time.get_ticks_usec()
	_paint()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## This frame's drawing: the banner and a ring on every finger down.
func _paint() -> void:
	draw_count += 1
	if test_mode == null or test_mode.game == null:
		return
	var sim: Simulation = test_mode.game.simulation
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8, 8 + FONT_SIZE), banner(sim), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
	for finger in sim.fingers_down:
		var at: Vector2 = sim.fingers_down[finger]
		draw_arc(at, FINGER_RADIUS, 0.0, TAU, 32, TEXT_COLOR, 3.0)
		draw_string(font, at + Vector2(FINGER_RADIUS, -FINGER_RADIUS), str(finger),
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
