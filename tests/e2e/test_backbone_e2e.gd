extends GutTest
## End-to-end: boots the real game scene (src/main.tscn) headless, drives it
## through test mode from a scripted input file, and compares state hashes.
## This is the pattern every later end-to-end test follows:
##   1. boot the scene, 2. enable test mode with a seed and a script,
##   3. run ticks, 4. assert on the simulation state or its hash.

const MAIN_SCENE := "res://src/main.tscn"
const SCRIPT_PATH := "res://tests/e2e/scripts/backbone.json"
const RUN_TICKS := 600


func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	return game


func _config(overrides := {}) -> Dictionary:
	var loaded := TestMode.load_config_file(SCRIPT_PATH)
	assert_eq(loaded["errors"], PackedStringArray())
	var config: Dictionary = loaded["config"]
	# Hold the frame clock: only run_ticks advances the simulation, so the
	# frames GUT spends awaiting can't add ticks.
	config["time_scale"] = 0
	config.merge(overrides, true)
	return config


func _run_scripted(overrides := {}) -> Node:
	var game := _boot()
	assert_eq(game.enable_test_mode(_config(overrides)), PackedStringArray())
	game.test_mode.run_ticks(RUN_TICKS)
	return game


func test_same_script_and_seed_give_the_same_hash() -> void:
	var first := _run_scripted()
	var second := _run_scripted()
	assert_eq(first.simulation.tick, RUN_TICKS)
	assert_eq(first.simulation.state_hash(), second.simulation.state_hash())


func test_a_different_seed_gives_a_different_hash() -> void:
	var first := _run_scripted()
	var other := _run_scripted({"seed": 20260929})
	assert_ne(first.simulation.state_hash(), other.simulation.state_hash())


func test_a_separate_process_gives_the_same_hash() -> void:
	# The strongest form of "run twice": a fresh Godot process, started from
	# the command line the way a developer or CI would.
	var in_process: String = _run_scripted().simulation.state_hash()
	var output := []
	# --quit-after bounds the child if it ever fails to quit on its own.
	var args := PackedStringArray([
		"--headless", "--quit-after", "600", "--path", ProjectSettings.globalize_path("res://"), "--",
		"--test-mode", "--test-script=" + SCRIPT_PATH, "--run-ticks=%d" % RUN_TICKS,
	])
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	assert_eq(code, 0, "child exit code")
	var text := "\n".join(output)
	var line := RegEx.create_from_string("STATE tick=(\\d+) hash=([0-9a-f]{64})").search(text)
	assert_not_null(line, "no STATE line in:\n%s" % text)
	if line:
		assert_eq(line.get_string(1), str(RUN_TICKS))
		assert_eq(line.get_string(2), in_process)


func test_injected_input_arrives_on_its_tick() -> void:
	var game := _boot()
	assert_eq(game.enable_test_mode(_config()), PackedStringArray())
	var sim = game.simulation
	game.test_mode.run_ticks(10)
	assert_eq(sim.input_log, [], "nothing before tick 10")
	game.test_mode.run_ticks(1)
	assert_eq(sim.input_log.size(), 2, "the tap: down and up")
	assert_eq(sim.input_log[0]["tick"], 10)
	assert_eq(sim.fingers_down, {})
	game.test_mode.run_until(32)
	assert_eq(sim.fingers_down, {0: Vector2(200, 200), 1: Vector2(900, 500)}, "a second finger")
	game.test_mode.run_until(61)
	assert_eq(sim.fingers_down, {})
	assert_eq(sim.tilt_degrees, 20.0)


func test_scene_ticks_from_frames_headless() -> void:
	# Normal play, no test mode: the frame clock drives the fixed step.
	var game := _boot()
	gut.p("Display server: %s; viewport: %s" % [DisplayServer.get_name(), game.get_viewport_rect().size])
	await wait_seconds(0.3)
	assert_gt(game.simulation.tick, 0)


func test_time_scale_speeds_up_the_frame_clock() -> void:
	var normal := _boot()
	var fast := _boot()
	var paused := _boot()
	normal.enable_test_mode(_config({"time_scale": 1}))
	fast.enable_test_mode(_config({"time_scale": 4}))
	paused.enable_test_mode(_config({"time_scale": 0}))
	await wait_seconds(0.5)
	gut.p("ticks after 0.5 s: x1=%d x4=%d x0=%d" % [normal.simulation.tick, fast.simulation.tick, paused.simulation.tick])
	assert_gt(normal.simulation.tick, 0)
	assert_gt(fast.simulation.tick, normal.simulation.tick * 3)
	assert_eq(paused.simulation.tick, 0)


func test_an_unknown_fixture_is_reported() -> void:
	var game := _boot()
	var errors: PackedStringArray = game.enable_test_mode(_config({"fixture": "no-such-fixture"}))
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "levels/test/fixtures/no-such-fixture.fixture.json")
	assert_null(game.test_mode)


func test_overlay_draws_headless() -> void:
	# Whether CanvasItem drawing runs without a screen. The overlay counts its
	# own _draw calls.
	var game := _boot()
	game.enable_test_mode(_config({"time_scale": 1}))
	await wait_process_frames(5)
	var overlay: Node = game.test_mode.overlay
	assert_not_null(overlay)
	assert_true(overlay.is_inside_tree())
	assert_gt(overlay.draw_count, 0)
