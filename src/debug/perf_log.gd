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
##   physics, on_screen, in_range, parked, resting
##                        the debug overlay's slime counts at the line
##                        (DebugCounts.count_slimes(), the bar's Physics, On
##                        screen, In range, Parked, plus Resting): calm
##                        ACTIVE and not a sleeper (they cost physics);
##                        centre in the view, any state; not parked; parked;
##                        calm RESTING. They overlap, so they don't add up
##   largest_cluster      the largest awake cluster at the line
##                        (DebugCounts.largest_cluster()): the most Physics
##                        slimes touching each other, directly or through
##                        others, in the last tick's contacts (by distance
##                        when a fusion since the tick wiped them). Taken only
##                        here, once a line, never per frame nor in the tick
##   hops, short_hops     the train hops taken in the window (automatic hops
##                        of train slimes, counted at take-off), and those
##                        that landed in the window less than half their
##                        Train.hop_reach() along the loop past their take-off
##                        (Train.hops_taken, short_hops_taken: the perf log
##                        takes their new counts frame by frame, train_hops())
##   bodies               every slime, whatever its state
##   active               mean slimes that cost physics, per frame
##                        (SlimeBodies.crowd_count(), the same count as
##                        physics and as the crowd detail's): baskets
##                        included, and slimes asleep at bedtime still
##                        settling (they are integrated, so they cost
##                        physics); resting, parked and sleepers excluded
##   pairs                mean candidate pairs on the frame's last tick
##                        (SlimeBodies.candidate_pair_count())
##   section              the section the camera is in (camera_section():
##                        that of the current loop's segment nearest the
##                        view's centre; 0 without a loop)
##   zoom                 the simulation's view's zoom
##
## Then the frame's parts outside the ticks, each a mean per frame over the
## window (PART_FIELDS; take_parts() reads them every frame), ms unless
## noted. The game nodes' own parts are their frame_cost_usec counters (the
## real time around their per-frame work, which the log takes and sets back
## to 0); a node that is absent counts 0:
##
##   slimes_ms            the slime renderer (SlimeRenderer._process)
##   eyes_ms              TapFeedback's _process (its change check) and
##                        _draw: ripples, the hint, the eyes
##   frontier_ms          FrontierView's _process (its change check) and
##                        _draw: switches, signposts, gates, baskets, the
##                        celebration
##   hud_ms               EdgeButtons' _process and _draw
##   debug_ms             the debug overlay's _process, its slime labels'
##                        _draw and test mode's overlay's _process and _draw
##   main_ms              the game root's _process outside the ticks
##   setup_ms             the rendering server's frame setup
##                        (RenderingServer.get_frame_setup_time_cpu())
##   render_cpu_ms, render_gpu_ms
##                        the root viewport's measured render time
##                        (RenderingServer.viewport_get_measured_render_time_*)
##   field_cpu_ms, field_gpu_ms
##                        the same, summed over the renderer's field
##                        SubViewports (0 in DIRECT, which has none)
##   draw_calls, objects, primitives
##                        the frame's Performance.RENDER_TOTAL_*_IN_FRAME
##                        (%.0f)
##
## A _draw runs after every _process (the redraw is deferred), so a node's
## draw is counted on the next frame's take: the sums over a window are
## right, a frame's own split is not. A measurement this renderer doesn't
## support reads 0.
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
## The PERF line's part fields, after zoom, in order (see the class doc):
## ms (%.2f) up to PART_FIRST_COUNT, counts (%.0f) from it.
# @spec-link [[req_platform_and_performance_targets]]
const PART_FIELDS: Array[String] = ["slimes_ms", "eyes_ms", "frontier_ms", "hud_ms", "debug_ms", "main_ms",
		"setup_ms", "render_cpu_ms", "render_gpu_ms", "field_cpu_ms", "field_gpu_ms",
		"draw_calls", "objects", "primitives"]
const PART_FIRST_COUNT := 11

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
## real time they took (microseconds), the slimes that cost physics
## (SlimeBodies.crowd_count()) and candidate pairs after them (0 without a
## simulation).
var _frame_ticks := PackedInt32Array()
var _frame_tick_usec := PackedInt64Array()
var _frame_active := PackedInt32Array()
var _frame_pairs := PackedInt32Array()
## The simulation the ticks were last read from, and its tick then: a
## simulation replaced (a reset, test mode starting) starts counting afresh.
var _sim: Simulation = null
var _last_tick := 0
## The train hops and short hops of the window, and the train's totals
## (train_hops()) when last read, from _sim like the ticks.
# @spec-link [[req_platform_and_performance_targets]]
var _hops := 0
var _short_hops := 0
var _last_hops := Vector2i.ZERO
## Time.get_ticks_usec() at the previous frame, or -1 before the first.
var _last_usec := -1
## The window's sums of take_parts(), one per PART_FIELDS.
# @spec-link [[req_platform_and_performance_targets]]
var _part_sums := PackedFloat64Array()
## The renderer's field viewports whose render time is measured.
var _field_rids: Array[RID] = []


## A perf log printing every `window_seconds` (> 0; parse_args() checks it).
func _init(window_seconds := DEFAULT_SECONDS) -> void:
	assert(window_seconds > 0.0, "PerfLog: the window must be > 0 s")
	seconds = window_seconds


## Takes the game root (its parent), runs its _process last, starts timing
## the process at the tree's process_frame, has the root viewport measure its
## render time, and prints the PERF_INFO line.
func _ready() -> void:
	name = "PerfLog"
	game = get_parent()
	process_priority = LAST_PRIORITY
	get_tree().process_frame.connect(_on_process_frame)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_part_sums.resize(PART_FIELDS.size())
	print(info_line())


## The frame's process starts: every _process of the tree comes after this.
func _on_process_frame() -> void:
	_process_start_usec = Time.get_ticks_usec()


## Times this frame, counts its ticks, takes its parts, and prints the line
## when the window is full.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var parts := take_parts()
	var sim: Simulation = game.get("simulation")
	if sim != null:
		var hops := train_hops(sim)
		if sim == _sim:
			_ticks += sim.tick - _last_tick
			_hops += hops.x - _last_hops.x
			_short_hops += hops.y - _last_hops.y
		_sim = sim
		_last_tick = sim.tick
		_last_hops = hops
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
	_frame_active.append(sim.slimes.crowd_count() if sim != null else 0)
	_frame_pairs.append(sim.slimes.candidate_pair_count() if sim != null else 0)
	for i in parts.size():
		_part_sums[i] += parts[i]
	if _window_s >= seconds:
		print(line(Time.get_ticks_msec() / 1000.0, window_stats(_deltas),
				tick_stats(_deltas, _frame_ticks, _frame_tick_usec, _frame_active, _frame_pairs),
				_process_s * 1000.0 / _deltas.size(), _ticks, _hops, _short_hops, sim,
				part_means(_part_sums, _deltas.size())))
		_part_sums.fill(0.0)
		_deltas = PackedFloat64Array()
		_frame_ticks = PackedInt32Array()
		_frame_tick_usec = PackedInt64Array()
		_frame_active = PackedInt32Array()
		_frame_pairs = PackedInt32Array()
		_window_s = 0.0
		_process_s = 0.0
		_ticks = 0
		_hops = 0
		_short_hops = 0


## This frame's parts outside the ticks, one per PART_FIELDS: the game
## nodes' frame_cost_usec taken (read, then set back to 0) in ms, the frame
## setup, the root viewport's and the field viewports' measured render times
## (ms), and the frame's draw calls, objects and primitives.
# @spec-link [[req_platform_and_performance_targets]]
func take_parts() -> PackedFloat64Array:
	var renderer: SlimeRenderer = game.get("slime_renderer")
	var overlay: Variant = game.get("debug_overlay")
	var labels: Variant = overlay.get("labels") if is_instance_valid(overlay) else null
	var test_mode: Variant = game.get("test_mode")
	var test_overlay: Variant = test_mode.get("overlay") if test_mode != null else null
	_measure_fields(renderer)
	var field_cpu := 0.0
	var field_gpu := 0.0
	for rid in _field_rids:
		field_cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		field_gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var root := get_viewport().get_viewport_rid()
	return PackedFloat64Array([
		_take_cost_ms(renderer),
		_take_cost_ms(game.get("tap_feedback")),
		_take_cost_ms(game.get("frontier_view")),
		_take_cost_ms(game.get("edge_buttons")),
		_take_cost_ms(overlay) + _take_cost_ms(labels) + _take_cost_ms(test_overlay),
		_take_cost_ms(game),
		RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_cpu(root),
		RenderingServer.viewport_get_measured_render_time_gpu(root),
		field_cpu,
		field_gpu,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	])


## `node`'s frame_cost_usec in ms, set back to 0; 0 when there is no node (a
## game without it, or freed). A node without the counter is a bug: it fails.
# @spec-link [[req_platform_and_performance_targets]]
static func _take_cost_ms(node: Variant) -> float:
	if not is_instance_valid(node):
		return 0.0
	var usec: Variant = node.get("frame_cost_usec")
	assert(usec is int, "PerfLog: %s has no frame_cost_usec counter" % node)
	node.set("frame_cost_usec", 0)
	return usec / 1000.0


## Keeps _field_rids on `renderer`'s field viewports (none without a
## renderer), having each new one (a rebuilt pipeline) measure its render time.
# @spec-link [[req_platform_and_performance_targets]]
func _measure_fields(renderer: SlimeRenderer) -> void:
	var rids: Array[RID] = []
	if renderer != null:
		for view in renderer.field_viewports():
			rids.append(view.get_viewport_rid())
	for rid in rids:
		if not rid in _field_rids:
			RenderingServer.viewport_set_measure_render_time(rid, true)
	_field_rids = rids


## The window's mean part per frame: `sums` (one per PART_FIELDS) over
## `frames` (at least one).
# @spec-link [[req_platform_and_performance_targets]]
static func part_means(sums: PackedFloat64Array, frames: int) -> PackedFloat64Array:
	assert(frames > 0 and sums.size() == PART_FIELDS.size(),
			"PerfLog.part_means: one sum per part field, at least one frame")
	var out := PackedFloat64Array()
	for each in sums:
		out.append(each / frames)
	return out


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
## `frame_tick_usec` (microseconds), the slimes that cost physics
## `frame_active` and candidate pairs `frame_pairs` after them, all the same
## size, at least one frame. Returns {"ticks_per_frame_mean", "ticks_per_frame_max",
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


## The nearest-rank `share` percentile of `sorted` (ascending, not empty).
static func _nearest_rank(sorted: PackedFloat64Array, share: float) -> float:
	var rank := clampi(ceili(share * sorted.size()), 1, sorted.size())
	return sorted[rank - 1]


## The PERF line for a window: `t` seconds since the engine started, its
## window_stats() `stats` and tick_stats() `ticking` (active and pairs
## included), the mean process time `process_ms_mean`, the `ticks` run, the
## train `hops` taken and `short_hops` landed in it, `sim`'s slime counts,
## largest awake cluster, total slimes, camera section and zoom (zeros
## without a simulation), and the part_means() `parts`. The fields are the
## class doc's, in its order. Read only.
# @spec-link [[req_platform_and_performance_targets]]
static func line(t: float, stats: Dictionary, ticking: Dictionary, process_ms_mean: float, ticks: int,
		hops: int, short_hops: int, sim: Simulation, parts: PackedFloat64Array) -> String:
	assert(parts.size() == PART_FIELDS.size(), "PerfLog.line: one mean per part field")
	var counts := {DebugCounts.PHYSICS: 0, DebugCounts.ON_SCREEN: 0, DebugCounts.IN_RANGE: 0,
			DebugCounts.PARKED: 0, DebugCounts.RESTING: 0}
	var largest_cluster := 0
	var bodies := 0
	var section := 0
	var zoom := 0.0
	if sim != null:
		counts = DebugCounts.count_slimes(sim)
		largest_cluster = DebugCounts.largest_cluster(sim.slimes)
		bodies = sim.slimes.slime_count
		section = camera_section(sim)
		zoom = sim.view.zoom
	return ("PERF t=%.1f frames=%d fps=%.1f frame_ms_p50=%.2f frame_ms_p95=%.2f frame_ms_max=%.2f"
			+ " process_ms_mean=%.2f ticks=%d ticks_per_frame_mean=%.2f ticks_per_frame_max=%d"
			+ " tick_ms_mean=%.2f tick_ms_frame_mean=%.2f rest_ms_mean=%.2f"
			+ " physics=%d on_screen=%d in_range=%d parked=%d resting=%d largest_cluster=%d"
			+ " hops=%d short_hops=%d bodies=%d"
			+ " active=%.1f pairs=%.1f"
			+ " section=%d zoom=%.3f") % [
			t, stats["frames"], stats["fps"], stats["p50_ms"], stats["p95_ms"], stats["max_ms"],
			process_ms_mean, ticks, ticking["ticks_per_frame_mean"], ticking["ticks_per_frame_max"],
			ticking["tick_ms_mean"], ticking["tick_ms_frame_mean"], ticking["rest_ms_mean"],
			counts[DebugCounts.PHYSICS], counts[DebugCounts.ON_SCREEN], counts[DebugCounts.IN_RANGE],
			counts[DebugCounts.PARKED], counts[DebugCounts.RESTING], largest_cluster, hops, short_hops, bodies,
			ticking["active_mean"], ticking["pairs_mean"], section, zoom] + _part_text(parts)


## The part fields of the PERF line for the means `parts` (one per
## PART_FIELDS): " key=value" each, ms with 2 decimals, counts whole.
# @spec-link [[req_platform_and_performance_targets]]
static func _part_text(parts: PackedFloat64Array) -> String:
	var text := ""
	for i in PART_FIELDS.size():
		text += (" %s=%.0f" if i >= PART_FIRST_COUNT else " %s=%.2f") % [PART_FIELDS[i], parts[i]]
	return text


## `sim`'s train hops and short hops so far (Train.hops_taken,
## short_hops_taken) as (hops, short hops); zeros without a train (no level).
# @spec-link [[req_platform_and_performance_targets]]
static func train_hops(sim: Simulation) -> Vector2i:
	if sim.train == null:
		return Vector2i.ZERO
	return Vector2i(sim.train.hops_taken, sim.train.short_hops_taken)


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
