extends GutTest
## The debug phase timers (src/debug/phase_timers.gd, chunk 5N U0a) on a
## real fixture and through the bench: gate2-open (shut doors, a moving
## train) loaded as tools/bench_level.gd loads it runs to the same state
## hash timed or not, every phase timed; `tools/bench_level.gd --phases`
## prints the PHASES line and a row for every phase.

# @test-link [[req_platform_and_performance_targets]]

const SEED := 909
const TICKS := 300
const BENCH := "res://tools/bench_level.gd"


## Fixture `fixture_name` of the test level as the bench loads it (its save,
## the camera where the fixture puts it, off-screen simulation on).
func _from_fixture(fixture_name: String) -> Simulation:
	var level: Level = load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate()
	autofree(level)
	assert_eq(level.build(), PackedStringArray(), "the test level builds")
	var loaded := TestMode.load_fixture(fixture_name)
	assert_true(loaded["ok"], str(loaded["error"]))
	var sim := Simulation.from_save(loaded["save"], level.data, SlimeWorld.terrain_from(level), SEED)
	assert_not_null(sim, fixture_name + " loads on the test level")
	var camera: Variant = loaded["camera"]
	if camera is String:
		camera = level.point_of(camera)
	if camera != null:
		sim.camera.start(level.data.loop, sim.train.open_gates, camera)
	sim.offscreen.enabled = true
	sim.hint.world_shown(sim.tick)
	return sim


## One tick as the bench runs it: the view follows the camera first.
func _step(sim: Simulation) -> void:
	sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
	sim.step()


func test_a_timed_fixture_runs_to_the_same_hash_every_phase_timed() -> void:
	var plain := _from_fixture("gate2-open")
	var timed := _from_fixture("gate2-open")
	PhaseTimers.attach(timed)
	for t in TICKS:
		_step(plain)
		_step(timed)
	assert_eq(timed.state_hash(), plain.state_hash(), "the timers never touch the state")
	assert_gt(timed.slimes.doors.size(), 0, "doors shut: the door passes ran")
	var means := PhaseTimers.means(timed)
	assert_eq(means.size(), Simulation.StepPhase.size() - 1 + SlimeBodies.TickPhase.size())
	var split := PhaseTimers.split(means)
	assert_gt(split.x, 0.0, "the solver took time")
	assert_gt(split.y, 0.0, "the behaviour took time")


func test_bench_prints_every_phase() -> void:
	var argv := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", BENCH,
			"--", "--fixture=fresh", "--ticks=5", "--lead-in=0", "--phases"])
	var output := []
	var code := OS.execute(OS.get_executable_path(), argv, output, true)
	var text := "\n".join(output)
	assert_eq(code, 0, text)
	assert_string_contains(text, "PHASES case=start ticks=5 step_us=")
	var names := []
	for name in Simulation.StepPhase.keys():
		if name != "BODIES":
			names.append(name.to_lower())
	for name in SlimeBodies.TickPhase.keys():
		names.append(name.to_lower())
	for name in names:
		var kind := "solver" if name in PhaseTimers.SOLVER_PHASES else "behaviour"
		assert_string_contains(text, "| %s | %s | " % [name, kind])
	assert_string_contains(text, "| **whole step** |")


func test_bench_refuses_a_value_on_phases() -> void:
	var argv := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", BENCH,
			"--", "--phases=yes"])
	var output := []
	assert_eq(OS.execute(OS.get_executable_path(), argv, output, true), 2, "\n".join(output))
