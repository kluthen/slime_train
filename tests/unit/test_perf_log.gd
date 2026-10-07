extends GutTest
## The perf log (src/debug/perf_log.gd), the phone measurement's PERF line:
## its window statistics (frame times to fps, p50, p95, max), its tick
## statistics (ticks per frame, ms per tick, the frame's rest), the active
## slimes (the crowd count) and candidate pairs, the slime counts, the
## largest awake cluster and the window's train hops and short hops, its
## --perf-log[=SECONDS] and --max-ticks-per-frame=N arguments, the line's
## fields, and the game root adding it only in a debug build (after
## TestModeGuard, by path) and only when asked. tools/android/perf.sh reads
## the line on a phone.

# @test-link [[req_platform_and_performance_targets]]

const MAIN_SCENE := "res://src/main.tscn"
const Support := preload("res://tests/unit/slime_test_support.gd")


func _game_with_guard(is_debug_build: bool) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	add_child_autofree(game)
	return game


## Part means for the line: 0.5, 1.5, 2.5 ... one per part field.
func _parts() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in PerfLog.PART_FIELDS.size():
		out.append(i + 0.5)
	return out


## 1 ms, 2 ms, ... `count` ms.
func _ramp(count: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in range(count, 0, -1):
		out.append(i / 1000.0)
	return out


func test_window_stats_of_a_ramp() -> void:
	var stats := PerfLog.window_stats(_ramp(20))
	assert_eq(stats["frames"], 20)
	assert_almost_eq(stats["fps"], 20.0 / 0.210, 0.001, "frames over the window's total time")
	assert_almost_eq(stats["p50_ms"], 10.0, 0.0001, "nearest rank: the 10th of 20")
	assert_almost_eq(stats["p95_ms"], 19.0, 0.0001, "nearest rank: the 19th of 20")
	assert_almost_eq(stats["max_ms"], 20.0, 0.0001)


func test_window_stats_of_steady_frames_with_one_hitch() -> void:
	var deltas := PackedFloat64Array()
	for i in 99:
		deltas.append(1.0 / 60.0)
	deltas.append(0.1)
	var stats := PerfLog.window_stats(deltas)
	assert_almost_eq(stats["p50_ms"], 1000.0 / 60.0, 0.0001)
	assert_almost_eq(stats["p95_ms"], 1000.0 / 60.0, 0.0001, "one hitch in 100 frames stays out of p95")
	assert_almost_eq(stats["max_ms"], 100.0, 0.0001)
	assert_almost_eq(stats["fps"], 100.0 / (99.0 / 60.0 + 0.1), 0.001)


func test_window_stats_of_one_frame() -> void:
	var stats := PerfLog.window_stats(PackedFloat64Array([0.02]))
	assert_eq(stats["frames"], 1)
	assert_almost_eq(stats["fps"], 50.0, 0.0001)
	assert_almost_eq(stats["p50_ms"], 20.0, 0.0001)
	assert_almost_eq(stats["p95_ms"], 20.0, 0.0001)


func test_window_stats_leave_the_deltas_unsorted() -> void:
	var deltas := _ramp(5)
	PerfLog.window_stats(deltas)
	assert_eq(deltas[0], 0.005)


func test_parse_without_the_flag() -> void:
	var parsed := PerfLog.parse_args(PackedStringArray(["--test-mode", "--seed=1", "--perf-logs=2"]))
	assert_false(parsed["requested"])
	assert_eq(parsed["errors"], PackedStringArray())


func test_parse_the_bare_flag_takes_the_default_window() -> void:
	var parsed := PerfLog.parse_args(PackedStringArray(["--test-mode", "--perf-log"]))
	assert_true(parsed["requested"])
	assert_eq(parsed["seconds"], PerfLog.DEFAULT_SECONDS)
	assert_eq(parsed["seconds"], 5.0)
	assert_eq(parsed["errors"], PackedStringArray())


func test_parse_a_window() -> void:
	assert_eq(PerfLog.parse_args(PackedStringArray(["--perf-log=2.5"]))["seconds"], 2.5)
	assert_eq(PerfLog.parse_args(PackedStringArray(["--perf-log=10"]))["seconds"], 10.0)


func test_parse_rejects_a_malformed_window() -> void:
	for arg in ["--perf-log=", "--perf-log=0", "--perf-log=-1", "--perf-log=abc", "--perf-log=5s"]:
		var parsed := PerfLog.parse_args(PackedStringArray([arg]))
		assert_true(parsed["requested"], arg)
		assert_eq(parsed["errors"].size(), 1, arg)


func test_parse_rejects_the_flag_twice() -> void:
	var parsed := PerfLog.parse_args(PackedStringArray(["--perf-log=5", "--perf-log"]))
	assert_eq(parsed["errors"].size(), 1)
	assert_string_contains(parsed["errors"][0], "more than once")


func test_line_holds_every_field() -> void:
	var sim := Simulation.new(7)
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.05, 0.05]), PackedInt32Array([3, 1]),
			PackedInt64Array([30_000, 10_000]), PackedInt32Array([80, 31]), PackedInt32Array([200, 41]))
	var text := PerfLog.line(12.34, PerfLog.window_stats(_ramp(20)), ticking, 4.5, 300, 9, 4, sim, _parts())
	assert_true(text.begins_with("PERF t=12.3 frames=20 fps=95.2 "), text)
	for field in ["frame_ms_p50=10.00", "frame_ms_p95=19.00", "frame_ms_max=20.00", "process_ms_mean=4.50",
			"ticks=300", "ticks_per_frame_mean=2.00", "ticks_per_frame_max=3", "tick_ms_mean=10.00",
			"tick_ms_frame_mean=20.00", "rest_ms_mean=30.00", "physics=0", "on_screen=0", "in_range=0",
			"parked=0", "resting=0", "largest_cluster=0", "hops=9", "short_hops=4", "bodies=0", "active=55.5",
			"pairs=120.5", "section=0", "zoom=",
			"slimes_ms=0.50", "main_ms=5.50", "field_gpu_ms=10.50", "draw_calls=12", "primitives=14",
			"ceiling=3", "crowd_level=0", "detail=0", "busy=0.00", "missed=0"]:
		assert_string_contains(text, " " + field)
	assert_false("\n" in text, "one line")


## The line is `key=value` fields after the tag, in the class doc's order,
## every value a number (tools/android/perf_summary.py parses it).
func test_line_is_key_value_numbers_in_the_documented_order() -> void:
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.02]), PackedInt32Array([1]), PackedInt64Array([5_000]),
			PackedInt32Array([1]), PackedInt32Array([0]))
	var fields := PerfLog.line(1.0, PerfLog.window_stats(PackedFloat64Array([0.02])), ticking, 5.0, 1, 0, 0,
			Simulation.new(7), _parts()).split(" ")
	assert_eq(fields[0], "PERF")
	var keys := PackedStringArray()
	for field in fields.slice(1):
		assert_eq(field.get_slice_count("="), 2, field)
		assert_true(field.get_slice("=", 1).is_valid_float(), field)
		keys.append(field.get_slice("=", 0))
	assert_eq(keys, PackedStringArray(["t", "frames", "fps", "frame_ms_p50", "frame_ms_p95", "frame_ms_max",
			"process_ms_mean", "ticks", "ticks_per_frame_mean", "ticks_per_frame_max", "tick_ms_mean",
			"tick_ms_frame_mean", "rest_ms_mean", "physics", "on_screen", "in_range", "parked", "resting",
			"largest_cluster", "hops", "short_hops", "bodies", "active", "pairs", "section", "zoom", "slimes_ms",
			"eyes_ms", "frontier_ms", "hud_ms", "debug_ms",
			"main_ms", "setup_ms", "render_cpu_ms", "render_gpu_ms", "field_cpu_ms", "field_gpu_ms", "draw_calls",
			"objects", "primitives", "ceiling", "crowd_level", "detail", "busy", "missed"]))


## The crowd detail fields (D141): the ceiling handed over, the crowd's
## level, the detail used, and the load meter's last window.
func test_the_line_holds_the_crowd_detail() -> void:
	var sim := Simulation.new(7)
	sim.offscreen.crowd_level = 3
	sim.offscreen.detail_ceiling = 1
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.02]), PackedInt32Array([1]), PackedInt64Array([5_000]),
			PackedInt32Array([1]), PackedInt32Array([0]))
	var text := PerfLog.line(1.0, PerfLog.window_stats(PackedFloat64Array([0.02])), ticking, 5.0, 1, 0, 0,
			sim, _parts(), "", {"verdict": LoadMeter.PRESSED, "busy": 0.917, "missed": 4})
	assert_true(text.ends_with(" ceiling=1 crowd_level=3 detail=1 busy=0.92 missed=4"), text)
	var none := PerfLog.line(1.0, PerfLog.window_stats(PackedFloat64Array([0.02])), ticking, 5.0, 1, 0, 0,
			null, _parts())
	assert_true(none.ends_with(" ceiling=0 crowd_level=0 detail=0 busy=0.00 missed=0"), none)


func test_the_ceiling_line() -> void:
	var step := {"from": 1, "to": 2, "reason": LoadMeter.PRESSED, "busy": 0.88, "missed": 3, "calm_needed": 60}
	assert_eq(PerfLog.ceiling_line(12.34, step, 3),
			"PERF_CEILING t=12.3 from=1 to=2 reason=pressed busy=0.88 missed=3 crowd_level=3 calm_needed=60")


## The part means: the window's sums over its frames.
func test_part_means_are_sums_over_frames() -> void:
	var sums := PackedFloat64Array()
	sums.resize(PerfLog.PART_FIELDS.size())
	sums[0] = 12.0
	sums[PerfLog.PART_FIRST_COUNT] = 300.0
	var means := PerfLog.part_means(sums, 4)
	assert_eq(means.size(), PerfLog.PART_FIELDS.size())
	assert_almost_eq(means[0], 3.0, 0.0001)
	assert_almost_eq(means[PerfLog.PART_FIRST_COUNT], 75.0, 0.0001)
	assert_eq(means[1], 0.0)


## The line's slime counts are the debug bar's (DebugCounts.count_slimes()):
## parked counts every parked slime, on screen or not; on screen any slime
## whose centre is in the view, parked or not; in range every slime not
## parked; resting the calm RESTING ones; bodies every slime.
func test_the_line_counts_the_slimes_as_the_bar() -> void:
	var sim := Simulation.new(7)
	var bodies := sim.slimes
	var in_view := sim.view.centre
	var far := sim.view.centre + Vector2(100_000, 0)
	bodies.park(bodies.create(0, 1, in_view, SlimeBodies.TRAIN))
	bodies.park(bodies.create(0, 1, far, SlimeBodies.TRAIN))
	bodies.create(0, 1, far + Vector2(200, 0), SlimeBodies.TRAIN)
	var resting := bodies.create(0, 1, far + Vector2(400, 0), SlimeBodies.IN_BASKET)
	bodies.calm[bodies.index_of(resting)] = SlimeBodies.RESTING
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.02]), PackedInt32Array([0]), PackedInt64Array([0]),
			PackedInt32Array([0]), PackedInt32Array([0]))
	var text := PerfLog.line(1.0, PerfLog.window_stats(PackedFloat64Array([0.02])), ticking, 1.0, 0, 0, 0,
			sim, _parts())
	for field in ["physics=1", "on_screen=1", "in_range=2", "parked=2", "resting=1", "largest_cluster=1",
			"bodies=4"]:
		assert_string_contains(text, " " + field)


## The line's largest cluster is DebugCounts.largest_cluster() of the last
## tick's contacts (a row of 3 touching and a pair: 3), and taking the line
## changes nothing in the simulation.
func test_the_line_holds_the_largest_cluster_and_reads_only() -> void:
	var sim := Simulation.new(7)
	var bodies := sim.slimes
	bodies.terrain = TerrainSegments.new([Support.floor_polygon()])
	bodies.auto_hops = false
	for i in 3:
		bodies.create(i % Species.COUNT, 1, Vector2(40.0 * i, -24), SlimeBodies.TRAIN)
	for i in 2:
		bodies.create(i % Species.COUNT, 1, Vector2(600.0 + 40.0 * i, -24), SlimeBodies.TRAIN)
	bodies.tick(1.0 / 60.0)
	assert_eq(DebugCounts.largest_cluster(bodies), 3, "the row touches")
	var hash_before := sim.state_hash()
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.02]), PackedInt32Array([1]), PackedInt64Array([0]),
			PackedInt32Array([5]), PackedInt32Array([0]))
	var text := PerfLog.line(1.0, PerfLog.window_stats(PackedFloat64Array([0.02])), ticking, 1.0, 1, 0, 0,
			sim, _parts())
	assert_string_contains(text, " largest_cluster=3 ")
	assert_string_contains(text, " physics=5 ")
	assert_eq(sim.state_hash(), hash_before, "read only")


## The line's hops and short_hops are the window's: the perf log takes the
## train's new hops (TrainHopLog.hops_taken, short_hops_taken) frame by
## frame, so those counted before its first frame aren't the window's.
# @test-link [[req_platform_and_performance_targets]]
func test_the_window_counts_the_trains_new_hops() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.enable_test_mode({"seed": 1}), PackedStringArray())
	assert_eq(game.add_perf_log(PackedStringArray(["--perf-log=100"])), PackedStringArray())
	var train: Train = game.simulation.train
	assert_not_null(train, "test mode's level has a train")
	train.hop_log.hops_taken += 7
	train.hop_log.short_hops_taken += 2
	var perf_log: PerfLog = game.perf_log
	perf_log._on_process_frame()
	perf_log._process(0.0)
	assert_eq([perf_log._hops, perf_log._short_hops], [0, 0], "counted before the log's first frame")
	train.hop_log.hops_taken += 5
	train.hop_log.short_hops_taken += 1
	perf_log._on_process_frame()
	perf_log._process(0.0)
	train.hop_log.hops_taken += 2
	perf_log._on_process_frame()
	perf_log._process(0.0)
	assert_eq([perf_log._hops, perf_log._short_hops], [7, 1])


## The camera's section: that of the current loop's segment nearest the
## view's centre; a section behind a closed gate isn't in the loop yet.
func test_camera_section_follows_the_view_along_the_current_loop() -> void:
	var sim := Simulation.new(7)
	assert_eq(PerfLog.camera_section(sim), 0, "no level")
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(-1500, 0), Vector2(0, 0)]))
	loop.add_segment("t.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(0, 0), Vector2(0, 400), Vector2(-1500, 400), Vector2(-1500, 0)]), "t.gate")
	loop.add_segment("t.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(0, 0), Vector2(1500, 0)]))
	loop.add_segment("t.s2.back", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, 0), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, 0)]))
	sim.level = LevelData.new("t", 1)
	sim.level.loop = loop
	sim.view.centre = Vector2(-700, 0)
	assert_eq(PerfLog.camera_section(sim), 1)
	sim.view.centre = Vector2(1000, 0)
	assert_eq(PerfLog.camera_section(sim), 1, "section 2 is behind the closed gate")
	sim.gate_states["t.gate"] = {"open": true}
	assert_eq(PerfLog.camera_section(sim), 2)


func test_tick_stats_split_the_frame_into_ticks_and_the_rest() -> void:
	# Three frames of 50 ms: 3 ticks in 36 ms, none, 1 tick in 9 ms.
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.05, 0.05, 0.05]), PackedInt32Array([3, 0, 1]),
			PackedInt64Array([36_000, 0, 9_000]), PackedInt32Array([90, 30, 30]), PackedInt32Array([10, 0, 5]))
	assert_almost_eq(ticking["ticks_per_frame_mean"], 4.0 / 3.0, 0.0001)
	assert_eq(ticking["ticks_per_frame_max"], 3)
	assert_almost_eq(ticking["tick_ms_mean"], 45.0 / 4.0, 0.0001, "ms per tick")
	assert_almost_eq(ticking["tick_ms_frame_mean"], 15.0, 0.0001, "ms per frame in ticks")
	assert_almost_eq(ticking["rest_ms_mean"], 35.0, 0.0001, "frame minus ticks")
	assert_almost_eq(ticking["active_mean"], 50.0, 0.0001)
	assert_almost_eq(ticking["pairs_mean"], 5.0, 0.0001)


func test_tick_stats_without_a_tick() -> void:
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.02]), PackedInt32Array([0]), PackedInt64Array([0]),
			PackedInt32Array([0]), PackedInt32Array([0]))
	assert_eq(ticking["ticks_per_frame_max"], 0)
	assert_eq(ticking["tick_ms_mean"], 0.0)
	assert_almost_eq(ticking["rest_ms_mean"], 20.0, 0.0001)


## Active, per frame: the slimes that cost physics (SlimeBodies.crowd_count(),
## the bar's Physics): a slime in a basket and one asleep at bedtime still
## settling included; not a sleeper, a resting or a parked slime.
func test_active_is_the_crowd_count_per_frame() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.enable_test_mode({"seed": 1}), PackedStringArray())
	assert_eq(game.add_perf_log(PackedStringArray(["--perf-log=100"])), PackedStringArray())
	var sim: Simulation = game.simulation
	var bodies := sim.slimes
	var before := bodies.crowd_count()
	var at := Vector2(0, -20_000)
	bodies.create(0, 1, at, SlimeBodies.TRAIN)
	bodies.create(0, 1, at + Vector2(100, 0), SlimeBodies.IN_BASKET)
	bodies.create(0, 1, at + Vector2(200, 0), SlimeBodies.SLEEPER)
	bodies.create(0, 1, at + Vector2(300, 0), SlimeBodies.BEDTIME_ASLEEP)
	bodies.park(bodies.create(0, 1, at + Vector2(400, 0), SlimeBodies.TRAIN))
	var resting := bodies.create(0, 1, at + Vector2(500, 0), SlimeBodies.IN_BASKET)
	bodies.calm[bodies.index_of(resting)] = SlimeBodies.RESTING
	assert_eq(bodies.crowd_count(), before + 3, "train, basket and bedtime-asleep")
	var perf_log: PerfLog = game.perf_log
	for i in 2:
		perf_log._on_process_frame()
		perf_log._process(0.0)
	assert_eq(perf_log._frame_active, PackedInt32Array([before + 3]), "the frame's active: the crowd count")


## The solver's candidate pairs of the last tick: neighbours in reach, never
## two walls.
func test_candidate_pairs_are_the_last_ticks() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	assert_eq(bodies.candidate_pair_count(), 0, "before any tick")
	var states := [SlimeBodies.SLEEPER, SlimeBodies.TRAIN, SlimeBodies.SLEEPER, SlimeBodies.SLEEPER]
	for i in states.size():
		bodies.create(i % Species.COUNT, 1, Vector2(40.0 * i, -24), states[i])
	bodies.tick(1.0 / 60.0)
	assert_eq(bodies.candidate_pair_count(), 2, "the train slime with each sleeper beside it")


func test_parse_max_ticks_per_frame() -> void:
	var parsed := PerfLog.parse_args(PackedStringArray(["--test-mode", "--max-ticks-per-frame=1"]))
	assert_false(parsed["requested"], "not the perf log itself")
	assert_eq(parsed["max_ticks"], 1)
	assert_eq(parsed["errors"], PackedStringArray())
	assert_eq(PerfLog.parse_args(PackedStringArray(["--perf-log"]))["max_ticks"], -1, "not given")


func test_parse_rejects_a_malformed_max_ticks_per_frame() -> void:
	for arg in ["--max-ticks-per-frame", "--max-ticks-per-frame=", "--max-ticks-per-frame=0",
			"--max-ticks-per-frame=-2", "--max-ticks-per-frame=1.5", "--max-ticks-per-frame=x"]:
		assert_eq(PerfLog.parse_args(PackedStringArray([arg]))["errors"].size(), 1, arg)
	var twice := PerfLog.parse_args(PackedStringArray(["--max-ticks-per-frame=2", "--max-ticks-per-frame=3"]))
	assert_eq(twice["errors"].size(), 1)
	assert_string_contains(twice["errors"][0], "more than once")


func test_test_mode_accepts_the_flag() -> void:
	var game := _game_with_guard(true)
	var errors: PackedStringArray = game.start_test_mode_from_args(
			PackedStringArray(["--test-mode", "--seed=1", "--perf-log=5", "--max-ticks-per-frame=1"]))
	assert_eq(errors, PackedStringArray())
	assert_not_null(game.test_mode)


func test_debug_game_adds_the_perf_log_when_asked() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.add_perf_log(PackedStringArray(["--seed=1"])), PackedStringArray())
	assert_null(game.perf_log, "not asked for")
	assert_eq(game.add_perf_log(PackedStringArray(["--perf-log=2"])), PackedStringArray())
	assert_not_null(game.perf_log)
	assert_eq(game.perf_log.seconds, 2.0)
	assert_eq(game.perf_log.get_parent(), game)


func test_debug_game_sets_the_cap_on_ticks_per_frame_when_asked() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.max_ticks_per_frame, game.MAX_TICKS_PER_FRAME)
	assert_eq(game.add_perf_log(PackedStringArray(["--max-ticks-per-frame=1"])), PackedStringArray())
	assert_eq(game.max_ticks_per_frame, 1)
	assert_null(game.perf_log, "the cap alone adds no perf log")
	assert_eq(game.add_perf_log(PackedStringArray(["--max-ticks-per-frame=0"])).size(), 1, "malformed")
	assert_eq(game.max_ticks_per_frame, 1, "a malformed flag sets nothing")


func test_release_game_refuses_the_cap_on_ticks_per_frame() -> void:
	var game := _game_with_guard(false)
	var errors: PackedStringArray = game.add_perf_log(PackedStringArray(["--max-ticks-per-frame=1"]))
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "not available")
	assert_eq(game.max_ticks_per_frame, game.MAX_TICKS_PER_FRAME)


## The game root records each frame's ticks and their time for the perf log.
func test_game_records_the_frames_ticks() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.enable_test_mode({"seed": 1, "time_scale": 1}), PackedStringArray())
	game._process(2.0 / 60.0)
	assert_eq(game.frame_ticks, 2)
	assert_gt(game.frame_tick_usec, 0)
	game._process(0.0)
	assert_eq(game.frame_ticks, 0)
	assert_lt(game.frame_tick_usec, 1000, "no tick: next to no time")


## The perf log takes each game node's frame_cost_usec (in ms, per part)
## and sets it back to 0: the debug overlay, its labels and test mode's
## overlay add up to debug_ms.
func test_perf_log_takes_and_resets_the_parts_counters() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.enable_test_mode({"seed": 1}), PackedStringArray())
	game.add_debug_overlay()
	assert_eq(game.add_perf_log(PackedStringArray(["--perf-log=100"])), PackedStringArray())
	var costs := {game.slime_renderer: 3000, game.tap_feedback: 1500, game.frontier_view: 250,
			game.edge_buttons: 100, game.debug_overlay: 40, game.debug_overlay.labels: 20,
			game.test_mode.overlay: 10, game: 700}
	for node in costs:
		node.frame_cost_usec = costs[node]
	var parts: PackedFloat64Array = game.perf_log.take_parts()
	assert_eq(parts.size(), PerfLog.PART_FIELDS.size())
	var expected := {"slimes_ms": 3.0, "eyes_ms": 1.5, "frontier_ms": 0.25, "hud_ms": 0.1, "debug_ms": 0.07,
			"main_ms": 0.7}
	for field in expected:
		assert_almost_eq(parts[PerfLog.PART_FIELDS.find(field)], expected[field], 0.0001, field)
	for node in costs:
		assert_eq(node.frame_cost_usec, 0, "taken, set back to 0: %s" % node.name)
	parts = game.perf_log.take_parts()
	for field in expected:
		assert_eq(parts[PerfLog.PART_FIELDS.find(field)], 0.0, "nothing since: " + field)


## Every node the perf log reads counts its own per-frame work, its _draw
## included, over real frames.
func test_game_nodes_count_their_frame_cost() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.enable_test_mode({"seed": 1, "time_scale": 1}), PackedStringArray())
	await wait_process_frames(3)
	for node in [game, game.slime_renderer, game.tap_feedback, game.frontier_view, game.edge_buttons,
			game.test_mode.overlay]:
		assert_gt(node.frame_cost_usec, 0, node.name)


func test_debug_game_refuses_a_malformed_flag() -> void:
	var game := _game_with_guard(true)
	var errors: PackedStringArray = game.add_perf_log(PackedStringArray(["--perf-log=never"]))
	assert_eq(errors.size(), 1)
	assert_null(game.perf_log)


func test_release_game_refuses_the_perf_log() -> void:
	var game := _game_with_guard(false)
	var errors: PackedStringArray = game.add_perf_log(PackedStringArray(["--perf-log"]))
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "not available")
	assert_null(game.perf_log)


## src/debug/ stays strippable: the game root loads the perf log by path, in
## one place, after the guard.
func test_main_loads_the_perf_log_only_after_the_guard() -> void:
	var text := FileAccess.get_file_as_string("res://src/main.gd")
	assert_eq(text.count("load(PERF_LOG_SCRIPT)"), 1, "one place loads it")
	var body := text.get_slice("func add_perf_log(", 1).get_slice("\nfunc ", 0)
	assert_true(body.find("test_mode_guard.allows()") >= 0
			and body.find("test_mode_guard.allows()") < body.find("load(PERF_LOG_SCRIPT)"),
			"add_perf_log() asks the guard before loading")
