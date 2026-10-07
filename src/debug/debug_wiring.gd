extends RefCounted
## The game root's debug wiring (health review S3): the debug overlay, and
## what a debug build's launch flags turn on (--debug-labels, --perf-log and
## --max-ticks-per-frame, --phase-timers, --census-every/--census-until,
## --wipe-save). Debug builds only: the game root (src/main.gd,
## _debug_wiring()) loads this script by path, after TestModeGuard allows it,
## so the release preset leaves it out with the rest of src/debug/. The game
## root keeps each flag's release side (the flag looked for, and ignored or
## refused, saying so) and calls here only once the guard allows.
##
## Every function acts on `game`, the game root: what it turns on stays the
## game's (debug_overlay, debug_labels, perf_log, max_ticks_per_frame,
## phase_timers, census), read by the game's frame and tick. Nothing here
## changes the simulation or its hash.

## The debug overlay (speed, reset, labels, kill, counter).
const DEBUG_OVERLAY_SCRIPT := "res://src/debug/debug_overlay.gd"
## The perf log (a PERF line every few seconds, for measuring on a phone).
const PERF_LOG_SCRIPT := "res://src/debug/perf_log.gd"
## The save wipe (--wipe-save, chunk 19w, D148).
const SAVE_WIPE_SCRIPT := "res://src/debug/save_wipe.gd"
## The phase timers (--phase-timers, chunk 5N U0a): every tick timed phase by
## phase, the perf log's PERF line carrying the window's means.
const PHASE_TIMERS_SCRIPT := "res://src/debug/phase_timers.gd"
const PHASE_TIMERS_ON := "Phase timers: on (--phase-timers)."
## The slime census (--census-every=S, --census-until=T): a census of every
## slime printed every S seconds of game time until T.
const CENSUS_SCRIPT := "res://src/debug/slime_census.gd"
## The debug labels at start (--debug-labels, chunk 22's repeat): the debug
## overlay's slime labels shown from launch, as if its Labels button had been
## pressed, so an unattended perf run can measure what they cost.
const DEBUG_LABELS_ON := "Debug labels: on at start (--debug-labels)."


## Adds the debug overlay (src/debug/debug_overlay.gd) to `game`, on its own
## layer, its slime labels shown when --debug-labels asked
## (`game.debug_labels`). The game root calls it when it has none yet.
static func add_debug_overlay(game: Node) -> void:
	game.debug_overlay = load(DEBUG_OVERLAY_SCRIPT).new()
	game.add_child(game.debug_overlay)
	if game.debug_labels:
		game.debug_overlay.show_labels(true)


## Turns the debug labels at start on (--debug-labels): sets
## `game.debug_labels`, and shows the labels of the overlay already there.
## The labels only draw: the simulation and its hash never change. Returns
## the line to print, DEBUG_LABELS_ON.
# @spec-link [[req_platform_and_performance_targets]]
static func use_debug_labels(game: Node) -> String:
	game.debug_labels = true
	if game.debug_overlay != null:
		game.debug_overlay.show_labels(true)
	return DEBUG_LABELS_ON


## Adds the perf log (src/debug/perf_log.gd) to `game` when `user_args` hold
## --perf-log[=SECONDS], in normal play or test mode alike; with
## --max-ticks-per-frame=N (a measurement, with or without the log) sets
## `game.max_ticks_per_frame` to N. Returns the errors: a malformed flag
## (nothing added or set).
static func add_perf_log(game: Node, user_args: PackedStringArray) -> PackedStringArray:
	var script: GDScript = load(PERF_LOG_SCRIPT)
	var parsed: Dictionary = script.parse_args(user_args)
	if not parsed["errors"].is_empty():
		return parsed["errors"]
	if parsed["max_ticks"] > 0:
		game.max_ticks_per_frame = parsed["max_ticks"]
	if parsed["requested"]:
		game.perf_log = script.new(parsed["seconds"])
		game.add_child(game.perf_log)
	return PackedStringArray()


## Turns the phase timers on (--phase-timers, chunk 5N U0a): loads
## src/debug/phase_timers.gd into `game.phase_timers`, so every simulation
## from then on is timed (the one running too). Returns the line to print,
## PHASE_TIMERS_ON.
# @spec-link [[req_platform_and_performance_targets]]
static func use_phase_timers(game: Node) -> String:
	game.phase_timers = load(PHASE_TIMERS_SCRIPT)
	if game.simulation != null:
		game.phase_timers.attach(game.simulation)
	return PHASE_TIMERS_ON


## Turns the slime census's schedule on from `user_args`' --census-every=S
## (and maybe --census-until=T): loads src/debug/slime_census.gd and keeps
## its schedule in `game.census`, which the game's step_simulation() hands
## every tick. Returns {"line" (to print: what it turned on), "errors" (a
## malformed flag: nothing turned on)}.
# @spec-link [[req_platform_and_performance_targets]]
static func use_census(game: Node, user_args: PackedStringArray) -> Dictionary:
	var script: GDScript = load(CENSUS_SCRIPT)
	var parsed: Dictionary = script.parse_args(user_args)
	if not parsed["errors"].is_empty():
		return {"line": "", "errors": parsed["errors"]}
	game.census = script.new(parsed["every"], parsed["until"])
	var until := "until %s s" % parsed["until"] if parsed["until"] > 0.0 else "with no end"
	return {"line": "Census: every %s s of game time, %s." % [parsed["every"], until],
			"errors": PackedStringArray()}


## The save wipe `user_args` ask for (--wipe-save, chunk 19w, D148), on
## `directory`: src/debug/save_wipe.gd's run() (every file in the directory
## deleted, unless the launch also names a save to load: refused). Returns
## {"refusal" ("" or why: the launch then quits with exit code 1), "log"
## (lines for the standard output), "errors" (lines for the error output;
## the launch carries on)}.
# @spec-link [[req_test_level_and_test_mode]]
# @spec-link [[rule_saves_never_wiped]]
static func wipe_saves(user_args: PackedStringArray, directory: String) -> Dictionary:
	return load(SAVE_WIPE_SCRIPT).run(user_args, directory)
