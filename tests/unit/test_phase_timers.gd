extends GutTest
## The debug phase timers (src/debug/phase_timers.gd, chunk 5N U0a): off by
## default, and then never called (every call in src/sim behind a null
## check, no clock read there); on, Simulation.step and SlimeBodies.tick time
## every phase once per tick in order (on the native tick, the native step as
## one phase); the means put the slime bodies' passes
## in place of the bodies' phase and add up to the step; the solver and
## behaviour split, the perf log's field and the bench's table; the game
## root's --phase-timers (debug builds only, by path, after the guard, every
## simulation it runs timed) and the PERF line's phases field.

# @test-link [[req_platform_and_performance_targets]]

const MAIN_SCENE := "res://src/main.tscn"
const SIM_FILES := ["res://src/sim/simulation.gd", "res://src/sim/slime_bodies.gd"]


## Records the timer calls it gets: "start", then each lap's phase.
class Recorder:
	extends RefCounted
	var calls: Array = []

	func start() -> void:
		calls.append("start")

	func lap(phase: int) -> void:
		calls.append(phase)


func _game_with_guard(is_debug_build: bool) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	add_child_autofree(game)
	return game


## A simulation with a few slimes on a floor, ticking.
func _sim() -> Simulation:
	var sim := Simulation.new(7)
	for i in 3:
		sim.slimes.create(0, 1, Vector2(100.0 + 50.0 * i, 0.0), SlimeBodies.FREE)
	return sim


func test_off_by_default_and_stays_off() -> void:
	var sim := _sim()
	assert_null(sim.phases)
	assert_null(sim.slimes.phases)
	sim.run(30)
	assert_null(sim.phases, "nothing turns them on")
	assert_null(sim.slimes.phases)
	assert_false(PhaseTimers.attached(sim))
	assert_eq(PhaseTimers.means(sim), {}, "no timers, no means")


## Off costs no timer call: in src/sim every start() and lap() of the timers
## sits right under its null check, and src/sim never reads the clock.
func test_every_timer_call_in_src_sim_is_behind_its_null_check() -> void:
	for path in SIM_FILES:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var calls := 0
		for i in lines.size():
			var text := lines[i].strip_edges()
			if not (text.begins_with("ph.") or text.begins_with("phases.")):
				continue
			calls += 1
			var guard := lines[i - 1].strip_edges()
			assert_true(guard == "if ph != null:" or guard == "if phases != null:",
					"%s:%d '%s' under '%s'" % [path, i + 1, text, guard])
		assert_gt(calls, 5, path + " times its phases")
		assert_false("Time." in FileAccess.get_file_as_string(path), path + " reads no clock")


## On the GDScript tick, every pass is timed once, in order.
func test_step_times_each_of_its_phases_once_in_order() -> void:
	var sim := _sim()
	assert_true(sim.slimes.use_native(false))
	var step := Recorder.new()
	var bodies := Recorder.new()
	sim.phases = step
	sim.slimes.phases = bodies
	sim.step()
	var expected: Array = ["start"]
	expected.append_array(Simulation.StepPhase.values())
	assert_eq(step.calls, expected)
	var body_expected: Array = ["start", SlimeBodies.TickPhase.AUTO_HOPS, SlimeBodies.TickPhase.TICK_OTHER]
	for sub in sim.slimes.substeps:
		body_expected.append(SlimeBodies.TickPhase.INTEGRATE)
		if sub == 0:
			body_expected.append(SlimeBodies.TickPhase.PAIRS)
		for it in sim.slimes.iterations:
			body_expected.append_array([SlimeBodies.TickPhase.CONTACTS, SlimeBodies.TickPhase.RINGS,
					SlimeBodies.TickPhase.TERRAIN, SlimeBodies.TickPhase.DOORS])
	body_expected.append_array([SlimeBodies.TickPhase.TICK_OTHER, SlimeBodies.TickPhase.REST])
	assert_eq(bodies.calls, body_expected)


## On the native tick, the native step (SlimeSolver.step) runs every solver
## pass in one call: one lap for it (NATIVE), after the hops and the support
## reset. Pending on SLIME_TICK=gdscript without the extension.
func test_the_native_step_is_timed_as_one_phase() -> void:
	if not ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		if OS.get_environment(TickChoice.ENV) == TickChoice.GDSCRIPT:
			pending("SLIME_TICK=gdscript and the slime_native extension isn't loaded")
		else:
			fail_test("SlimeSolver is not registered: the slime_native extension didn't load")
		return
	var sim := _sim()
	assert_true(sim.slimes.use_native(true))
	var bodies := Recorder.new()
	sim.slimes.phases = bodies
	sim.step()
	assert_eq(bodies.calls, ["start", SlimeBodies.TickPhase.AUTO_HOPS, SlimeBodies.TickPhase.TICK_OTHER,
			SlimeBodies.TickPhase.NATIVE])


## The timers leave the state alone: two runs, one timed, the same hash.
func test_timers_on_leave_the_state_hash_unchanged() -> void:
	var plain := _sim()
	var timed := _sim()
	PhaseTimers.attach(timed)
	plain.run(120)
	timed.run(120)
	assert_eq(timed.state_hash(), plain.state_hash())
	assert_eq(timed.phases.ticks, 120)
	assert_eq(timed.slimes.phases.ticks, 120)
	PhaseTimers.detach(timed)
	assert_false(PhaseTimers.attached(timed))


func test_means_put_the_bodies_passes_in_its_place_and_add_up_to_the_step() -> void:
	var sim := _sim()
	PhaseTimers.attach(sim)
	var step: PhaseTimers = sim.phases
	var bodies: PhaseTimers = sim.slimes.phases
	step.ticks = 4
	bodies.ticks = 4
	for i in step.usec.size():
		step.usec[i] = 40 * (i + 1)
	for k in bodies.usec.size():
		bodies.usec[k] = 4 * (k + 1)
	var means := PhaseTimers.means(sim)
	var names := []
	for name in Simulation.StepPhase.keys():
		if name == "BODIES":
			for pass_name in SlimeBodies.TickPhase.keys():
				names.append(pass_name.to_lower())
		else:
			names.append(name.to_lower())
	assert_eq(means.keys(), names, "tick order, the bodies' passes in place of bodies")
	assert_eq(means["input"], 10.0, "40 µs over 4 ticks")
	assert_eq(means["auto_hops"], 1.0)
	assert_eq(means["tick_other"], 9.0)
	var split := PhaseTimers.split(means)
	assert_almost_eq(split.x, (2 + 3 + 4 + 5 + 6 + 7 + 8 + 10) * 1.0, 0.001, "integrate .. rest, and native")
	var total := 0.0
	for name in means:
		total += means[name]
	assert_almost_eq(split.x + split.y, total, 0.01, "solver and behaviour: the whole step")
	var field := PhaseTimers.field(means)
	assert_true(field.begins_with("input:10,session:20,offscreen:30,"), field)
	assert_eq(field.split(",").size(), names.size())
	assert_false(" " in field, "one word")
	var table := PhaseTimers.table(means)
	assert_eq(table.size(), 2 + names.size() + 3, "header, a row per phase, three totals")
	assert_eq(table[2], "| input | behaviour | 10.0 | %.1f %% |" % (1000.0 / total))
	assert_string_contains(table[2 + names.find("contacts")], "| contacts | solver |")
	assert_string_contains(table[-1], "| **whole step** |  | ")
	assert_string_contains(table[-1], "| 100.0 % |")


func test_take_reads_then_clears() -> void:
	var sim := _sim()
	PhaseTimers.attach(sim)
	sim.run(5)
	var taken := PhaseTimers.take(sim)
	assert_eq(taken.size(), Simulation.StepPhase.size() - 1 + SlimeBodies.TickPhase.size())
	assert_eq(sim.phases.ticks, 0)
	assert_eq(sim.slimes.phases.ticks, 0)
	assert_eq(PhaseTimers.means(sim), {}, "nothing timed since")
	assert_eq(PhaseTimers.field({}), "")


func test_test_mode_accepts_the_flag() -> void:
	var game := _game_with_guard(true)
	var errors: PackedStringArray = game.start_test_mode_from_args(
			PackedStringArray(["--test-mode", "--seed=1", "--phase-timers"]))
	assert_eq(errors, PackedStringArray())
	assert_not_null(game.test_mode)


## In a debug build the flag times the running simulation and every one the
## game runs after it (a test mode run, a fresh start).
func test_debug_game_times_every_simulation_when_asked() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.use_phase_timers(PackedStringArray(["--seed=1"])), "")
	assert_null(game.phase_timers, "not asked for")
	assert_false(PhaseTimers.attached(game.simulation))
	assert_eq(game.use_phase_timers(PackedStringArray(["--phase-timers"])), load("res://src/debug/debug_wiring.gd").PHASE_TIMERS_ON)
	assert_true(PhaseTimers.attached(game.simulation), "the running one")
	assert_eq(game.enable_test_mode({"seed": 1}), PackedStringArray())
	assert_true(PhaseTimers.attached(game.simulation), "test mode's")
	game.restart_fresh()
	assert_true(PhaseTimers.attached(game.simulation), "a fresh start's")


func test_release_game_ignores_the_flag() -> void:
	var game := _game_with_guard(false)
	assert_eq(game.use_phase_timers(PackedStringArray(["--phase-timers"])), game.PHASE_TIMERS_IGNORED)
	assert_null(game.phase_timers)
	assert_false(PhaseTimers.attached(game.simulation))


## src/debug/ stays strippable: the debug wiring loads the timers by path,
## in one place, and the game root reaches it only after the guard
## (test_debug_overlay.gd checks main.gd's _debug_wiring(), and that no code
## outside src/debug/ names PhaseTimers).
func test_main_loads_the_phase_timers_only_after_the_guard() -> void:
	var text := FileAccess.get_file_as_string("res://src/debug/debug_wiring.gd")
	assert_eq(text.count("load(PHASE_TIMERS_SCRIPT)"), 1, "one place loads it")
	var body := FileAccess.get_file_as_string("res://src/main.gd").get_slice(
			"func use_phase_timers(", 1).get_slice("\nfunc ", 0)
	assert_true(body.find("_debug_wiring()") >= 0, "use_phase_timers() goes through the guarded wiring")


## The PERF line carries the phases field last, only when given.
func test_perf_line_carries_the_phases_field_last() -> void:
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.02]), PackedInt32Array([1]), PackedInt64Array([5_000]),
			PackedInt32Array([1]), PackedInt32Array([0]))
	var stats := PerfLog.window_stats(PackedFloat64Array([0.02]))
	var parts := PackedFloat64Array()
	parts.resize(PerfLog.PART_FIELDS.size())
	var plain := PerfLog.line(1.0, stats, ticking, 5.0, 1, 0, 0, Simulation.new(7), parts)
	assert_false("phases=" in plain, "off: no field")
	var timed := PerfLog.line(1.0, stats, ticking, 5.0, 1, 0, 0, Simulation.new(7), parts, "input:1,rest:20")
	assert_true(timed.begins_with(plain + " "), "the same line, then the field")
	assert_true(timed.ends_with(" phases=input:1,rest:20"), timed)
