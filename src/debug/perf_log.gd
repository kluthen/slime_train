class_name PerfLog
extends Node
## The periodic performance line, for measuring the game on a phone. Debug
## builds only: the game root (src/main.gd, add_perf_log()) adds it by path,
## after TestModeGuard allows it, when the user arguments hold --perf-log, in
## normal play or in test mode alike. Nothing outside src/debug/ names this
## class, so the release preset can leave src/debug/ out.
##
## It times every frame on the real clock (Time.get_ticks_usec() between two
## of its _process calls, not the smoothed frame delta, which hides hitches),
## and the frame's process time: from the tree's process_frame signal (just
## before any _process) to its own _process, which runs last
## (LAST_PRIORITY), so the game root's fixed-step ticks are inside it. It
## doesn't read Performance.TIME_PROCESS: Godot updates that once a second,
## with the second's worst frame. Every `seconds` of real time it prints ONE
## line to stdout (logcat's tag "godot" on Android), space-separated
## `key=value` fields, always in this order (tools/android/perf.sh passes
## --perf-log=1: one line a second; tools/android/perf_summary.py reads it):
##
##   PERF                 the line's tag (no value)
##   t                    s since the engine started, at the line
##   frames               frames in the window
##   fps                  frames / the window's real seconds
##   frame_ms_p50, frame_ms_p95, frame_ms_max
##                        the window's frame times (nearest rank), ms
##   process_ms_mean      mean process time per frame, the ticks included, ms
##   ticks                simulation ticks run in the window
##   ticks_per_frame_mean, ticks_per_frame_max
##                        ticks the fixed step ran per frame
##   tick_ms_mean         ms per tick
##   tick_ms_frame_mean   ms per frame spent in ticks
##   rest_ms_mean         ms per frame outside the ticks (frame - ticks):
##                        rendering, input, the rest of the process
##   on_screen, simulated, off_screen
##                        the debug overlay's slime counts at the line
##                        (DebugCounts.count_slimes()): centre in the view;
##                        off the view and fully simulated; off the view
##                        and parked
##   parked               every parked slime (SlimeBodies.is_parked), on
##                        screen or not: off_screen plus the parked ones
##                        whose centre is in the view (they unpark on the
##                        next tick), so parked >= off_screen
##   bodies               every slime, whatever its state (on_screen +
##                        simulated + off_screen)
##   active               mean bodies the solver simulates, per frame
##                        (active_bodies(): baskets included, which
##                        "simulated" doesn't show; resting, parked and
##                        sleeping ones excluded)
##   pairs                mean candidate pairs on the frame's last tick
##                        (SlimeBodies.candidate_pair_count())
##   section              the section the camera is in (camera_section():
##                        that of the current loop's segment nearest the
##                        view's centre; 0 without a loop)
##   zoom                 the simulation's view's zoom
##
## Every field but the first is a number; zeros without a simulation. The
## tick fields come from the game root's own record of each frame
## (frame_ticks, frame_tick_usec: the ticks it ran and the real time around
## their step_simulation() calls), see tick_stats(); active and pairs are read
## after each frame's ticks. At start it prints one "PERF_INFO" line: the
## window, the model, the renderer, the refresh rate, the cap on ticks per
## frame at 1x.
##
## Its measurement flag --max-ticks-per-frame=N (parse_args()) sets that cap
## for the run (the game root's max_ticks_per_frame), to measure what the
## fixed step's catch-up costs.
# @spec-link [[req_platform_and_performance_targets]]

## The user argument that asks for the perf log: --perf-log or --perf-log=SECONDS.
const FLAG := "--perf-log"
## The window when the flag gives none, seconds.
const DEFAULT_SECONDS := 5.0
## The user argument that sets the cap on ticks per frame at 1x:
## --max-ticks-per-frame=N (N >= 1).
const MAX_TICKS_FLAG := "--max-ticks-per-frame"
## Its process priority: after every other node's _process.
const LAST_PRIORITY := 1 << 30

## The window, real seconds.
var seconds := DEFAULT_SECONDS
## The game root it measures (its parent): its `simulation` is read every frame.
var game: Node = null

## The frame times of the current window, seconds.
var _deltas := PackedFloat64Array()
## The real time the window covers so far (the sum of _deltas), seconds.
var _window_s := 0.0
## The sum of the window's frames' process times, seconds.
var _process_s := 0.0
## Time.get_ticks_usec() at this frame's process_frame signal, or -1 before the first.
var _process_start_usec := -1
## The simulation ticks run in the window.
var _ticks := 0
## Per frame of the window (as _deltas): the ticks the game root ran, the
## real time they took (microseconds), the active bodies and candidate pairs
## after them (0 without a simulation).
var _frame_ticks := PackedInt32Array()
var _frame_tick_usec := PackedInt64Array()
var _frame_active := PackedInt32Array()
var _frame_pairs := PackedInt32Array()
## The simulation the ticks were last read from, and its tick then: a
## simulation replaced (a reset, test mode starting) starts counting afresh.
var _sim: Simulation = null
var _last_tick := 0
## Time.get_ticks_usec() at the previous frame, or -1 before the first.
var _last_usec := -1


## A perf log printing every `window_seconds` (> 0; parse_args() checks it).
func _init(window_seconds := DEFAULT_SECONDS) -> void:
	assert(window_seconds > 0.0, "PerfLog: the window must be > 0 s")
	seconds = window_seconds


## Takes the game root (its parent), runs its _process last, starts timing
## the process at the tree's process_frame, and prints the PERF_INFO line.
func _ready() -> void:
	name = "PerfLog"
	game = get_parent()
	process_priority = LAST_PRIORITY
	get_tree().process_frame.connect(_on_process_frame)
	print(info_line())


## The frame's process starts: every _process of the tree comes after this.
func _on_process_frame() -> void:
	_process_start_usec = Time.get_ticks_usec()


## Times this frame, counts its ticks, and prints the line when the window is full.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var sim: Simulation = game.get("simulation")
	if sim != null:
		if sim == _sim:
			_ticks += sim.tick - _last_tick
		_sim = sim
		_last_tick = sim.tick
	if _last_usec < 0 or _process_start_usec < 0:
		_last_usec = now
		return
	var frame_s := (now - _last_usec) / 1_000_000.0
	_deltas.append(frame_s)
	_window_s += frame_s
	_last_usec = now
	_process_s += (now - _process_start_usec) / 1_000_000.0
	_frame_ticks.append(int(game.get("frame_ticks")))
	_frame_tick_usec.append(int(game.get("frame_tick_usec")))
	_frame_active.append(active_bodies(sim) if sim != null else 0)
	_frame_pairs.append(sim.slimes.candidate_pair_count() if sim != null else 0)
	if _window_s >= seconds:
		print(line(Time.get_ticks_msec() / 1000.0, window_stats(_deltas),
				tick_stats(_deltas, _frame_ticks, _frame_tick_usec, _frame_active, _frame_pairs),
				_process_s * 1000.0 / _deltas.size(), _ticks, sim))
		_deltas = PackedFloat64Array()
		_frame_ticks = PackedInt32Array()
		_frame_tick_usec = PackedInt64Array()
		_frame_active = PackedInt32Array()
		_frame_pairs = PackedInt32Array()
		_window_s = 0.0
		_process_s = 0.0
		_ticks = 0


## Reads --perf-log[=SECONDS] and --max-ticks-per-frame=N from the user
## arguments (after "--"); every other argument is left alone. Returns
## {"requested" (bool: --perf-log given), "seconds" (float, DEFAULT_SECONDS
## when the flag gives none), "max_ticks" (int, -1 when not given),
## "errors"}: a value that isn't a number > 0 (a whole number >= 1 for N),
## or a flag given twice, is an error.
static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var result := {"requested": false, "seconds": DEFAULT_SECONDS, "max_ticks": -1, "errors": PackedStringArray()}
	for arg in user_args:
		if arg.get_slice("=", 0) == MAX_TICKS_FLAG:
			_parse_max_ticks(arg, result)
			continue
		if arg.get_slice("=", 0) != FLAG:
			continue
		if result["requested"]:
			result["errors"].append("%s is given more than once" % FLAG)
			continue
		result["requested"] = true
		if not "=" in arg:
			continue
		var value := arg.substr(FLAG.length() + 1)
		if value.is_valid_float() and value.to_float() > 0.0:
			result["seconds"] = value.to_float()
		else:
			result["errors"].append("%s=SECONDS expects a number of seconds > 0, got '%s'" % [FLAG, value])
	return result


## Reads one --max-ticks-per-frame argument `arg` into `result`
## (parse_args()'s): its "max_ticks", or an error.
static func _parse_max_ticks(arg: String, result: Dictionary) -> void:
	if result["max_ticks"] != -1:
		result["errors"].append("%s is given more than once" % MAX_TICKS_FLAG)
		return
	var value := arg.substr(MAX_TICKS_FLAG.length() + 1) if "=" in arg else ""
	if value.is_valid_int() and value.to_int() >= 1:
		result["max_ticks"] = value.to_int()
	else:
		result["errors"].append("%s=N expects a whole number >= 1, got '%s'" % [MAX_TICKS_FLAG, value])
		result["max_ticks"] = 0


## The statistics of one window of frame times `deltas_s` (seconds, at least
## one): {"frames", "fps" (frames over the window's total time), "p50_ms",
## "p95_ms", "max_ms"}. Percentiles are nearest-rank: the smallest frame time
## that at least that share of the frames don't exceed.
static func window_stats(deltas_s: PackedFloat64Array) -> Dictionary:
	assert(not deltas_s.is_empty(), "PerfLog.window_stats: a window has at least one frame")
	var sorted := deltas_s.duplicate()
	sorted.sort()
	var total := 0.0
	for each in sorted:
		total += each
	return {
		"frames": sorted.size(),
		"fps": sorted.size() / total if total > 0.0 else 0.0,
		"p50_ms": _nearest_rank(sorted, 0.50) * 1000.0,
		"p95_ms": _nearest_rank(sorted, 0.95) * 1000.0,
		"max_ms": sorted[sorted.size() - 1] * 1000.0,
	}


## The tick statistics of one window: per frame, its time `deltas_s`
## (seconds), the ticks the game root ran `frame_ticks`, their real time
## `frame_tick_usec` (microseconds), the active bodies `frame_active` and
## candidate pairs `frame_pairs` after them, all the same size, at least one
## frame. Returns {"ticks_per_frame_mean", "ticks_per_frame_max",
## "tick_ms_mean" (ms per tick; 0 without a tick), "tick_ms_frame_mean" (ms
## per frame spent in ticks), "rest_ms_mean" (ms per frame outside them),
## "active_mean", "pairs_mean"}.
static func tick_stats(deltas_s: PackedFloat64Array, frame_ticks: PackedInt32Array,
		frame_tick_usec: PackedInt64Array, frame_active: PackedInt32Array,
		frame_pairs: PackedInt32Array) -> Dictionary:
	var frames := deltas_s.size()
	assert(frames > 0 and frame_ticks.size() == frames and frame_tick_usec.size() == frames
			and frame_active.size() == frames and frame_pairs.size() == frames,
			"PerfLog.tick_stats: one entry per frame of the window, at least one")
	var active := 0
	var pairs := 0
	for i in frames:
		active += frame_active[i]
		pairs += frame_pairs[i]
	var window_ms := 0.0
	for each in deltas_s:
		window_ms += each * 1000.0
	var ticks := 0
	var most := 0
	var tick_ms := 0.0
	for i in frames:
		ticks += frame_ticks[i]
		most = maxi(most, frame_ticks[i])
		tick_ms += frame_tick_usec[i] / 1000.0
	return {
		"ticks_per_frame_mean": float(ticks) / frames,
		"ticks_per_frame_max": most,
		"tick_ms_mean": tick_ms / ticks if ticks > 0 else 0.0,
		"tick_ms_frame_mean": tick_ms / frames,
		"rest_ms_mean": (window_ms - tick_ms) / frames,
		"active_mean": float(active) / frames,
		"pairs_mean": float(pairs) / frames,
	}


## How many of `sim`'s slimes the solver simulates: calm ACTIVE (neither
## resting nor parked) and not a sleeper nor asleep at bedtime, whatever
## else their state (a slime in a basket counts).
static func active_bodies(sim: Simulation) -> int:
	var bodies := sim.slimes
	var count := 0
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.ACTIVE and bodies.state[s] != SlimeBodies.STATE_SLEEPER \
				and bodies.state[s] != SlimeBodies.STATE_BEDTIME_ASLEEP:
			count += 1
	return count


## The nearest-rank `share` percentile of `sorted` (ascending, not empty).
static func _nearest_rank(sorted: PackedFloat64Array, share: float) -> float:
	var rank := clampi(ceili(share * sorted.size()), 1, sorted.size())
	return sorted[rank - 1]


## The PERF line for a window: `t` seconds since the engine started, its
## window_stats() `stats` and tick_stats() `ticking` (active and pairs
## included), the mean process time `process_ms_mean`, the `ticks` run, and
## `sim`'s slime counts, parked slimes, camera section and zoom (zeros
## without a simulation). The fields are the class doc's, in its order.
static func line(t: float, stats: Dictionary, ticking: Dictionary, process_ms_mean: float, ticks: int,
		sim: Simulation) -> String:
	var counts := {DebugCounts.ON_SCREEN: 0, DebugCounts.SIMULATED: 0, DebugCounts.OFF_SCREEN: 0}
	var parked := 0
	var section := 0
	var zoom := 0.0
	if sim != null:
		counts = DebugCounts.count_slimes(sim)
		parked = parked_bodies(sim)
		section = camera_section(sim)
		zoom = sim.view.zoom
	var bodies: int = counts[DebugCounts.ON_SCREEN] + counts[DebugCounts.SIMULATED] + counts[DebugCounts.OFF_SCREEN]
	return ("PERF t=%.1f frames=%d fps=%.1f frame_ms_p50=%.2f frame_ms_p95=%.2f frame_ms_max=%.2f"
			+ " process_ms_mean=%.2f ticks=%d ticks_per_frame_mean=%.2f ticks_per_frame_max=%d"
			+ " tick_ms_mean=%.2f tick_ms_frame_mean=%.2f rest_ms_mean=%.2f"
			+ " on_screen=%d simulated=%d off_screen=%d parked=%d bodies=%d active=%.1f pairs=%.1f"
			+ " section=%d zoom=%.3f") % [
			t, stats["frames"], stats["fps"], stats["p50_ms"], stats["p95_ms"], stats["max_ms"],
			process_ms_mean, ticks, ticking["ticks_per_frame_mean"], ticking["ticks_per_frame_max"],
			ticking["tick_ms_mean"], ticking["tick_ms_frame_mean"], ticking["rest_ms_mean"],
			counts[DebugCounts.ON_SCREEN], counts[DebugCounts.SIMULATED], counts[DebugCounts.OFF_SCREEN], parked,
			bodies, ticking["active_mean"], ticking["pairs_mean"], section, zoom]


## How many of `sim`'s slimes are parked (SlimeBodies.PARKED), wherever they are.
static func parked_bodies(sim: Simulation) -> int:
	var bodies := sim.slimes
	var count := 0
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.PARKED:
			count += 1
	return count


## The section the camera is in: that of the current loop's segment (for the
## open gates, DebugCounts.open_gates()) nearest the centre of `sim`'s view;
## 0 when the simulation has no level or no loop.
static func camera_section(sim: Simulation) -> int:
	if sim.level == null or sim.level.loop == null:
		return 0
	var loop := sim.level.loop
	var nearest := loop.closest(sim.view.centre, DebugCounts.open_gates(sim))
	if nearest["segment"] == "":
		return 0
	return int(loop.segment(nearest["segment"])["section"])


## The PERF_INFO line: the window, the device model, the rendering method and
## driver, the screen's refresh rate, the window's size, the vsync mode and
## the game root's cap on ticks per frame at 1x (spaces in names become
## underscores, so every value is one word).
func info_line() -> String:
	var size := DisplayServer.window_get_size()
	return ("PERF_INFO seconds=%s model=%s renderer=%s driver=%s refresh_hz=%.1f window=%dx%d vsync=%d"
			+ " max_ticks_per_frame=%d") % [
			seconds, OS.get_model_name().replace(" ", "_"),
			RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(),
			DisplayServer.screen_get_refresh_rate(), size.x, size.y, DisplayServer.window_get_vsync_mode(),
			int(game.get("max_ticks_per_frame"))]
