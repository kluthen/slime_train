extends GutTest
## The crowd detail mode (D141, chunk 22c) the game root hands the
## simulation's detail ceiling in, before every tick: `always` (the
## simulation's own default, the ceiling at 3: D140's behaviour) in test
## mode, so that every scripted run, fixture and test repeats with the same
## hash; `auto` (the load meter's ceiling) only in normal play; a debug
## build's --crowd-detail=auto|always|off overrides either, a release build
## ignores it.
# @test-link [[req_test_level_and_test_mode]]

const MAIN_SCENE := "res://src/main.tscn"


func _game(is_debug_build := true) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	add_child_autofree(game)
	return game


func test_the_simulation_defaults_to_always() -> void:
	assert_eq(Simulation.new(1).offscreen.detail_ceiling, SlimeBodies.MAX_DETAIL)


## The guard: test mode runs `always` unless its run asks otherwise.
func test_test_mode_defaults_to_always() -> void:
	var game := _game()
	assert_eq(game.enable_test_mode({"seed": 1, "time_scale": 0}), PackedStringArray())
	assert_eq(game.crowd_detail_mode(), LoadMeter.ALWAYS)
	game.load_meter.ceiling = 1
	game.step_simulation()
	assert_eq(game.simulation.offscreen.detail_ceiling, SlimeBodies.MAX_DETAIL, "the meter's ceiling unused")


func test_test_mode_takes_the_flag() -> void:
	var game := _game()
	assert_eq(game.use_crowd_detail(PackedStringArray(["--crowd-detail=auto"]))["errors"], PackedStringArray())
	assert_eq(game.enable_test_mode({"seed": 1, "time_scale": 0}), PackedStringArray())
	assert_eq(game.crowd_detail_mode(), LoadMeter.AUTO)
	game.load_meter.ceiling = 2
	game.step_simulation()
	assert_eq(game.simulation.offscreen.detail_ceiling, 2, "the meter's ceiling")
	game.crowd_detail = LoadMeter.OFF
	game.step_simulation()
	assert_eq(game.simulation.offscreen.detail_ceiling, 0)


func test_test_mode_flags_accept_it() -> void:
	var parsed: Dictionary = TestMode.config_from_args(PackedStringArray(
			["--test-mode", "--fixture=fresh", "--crowd-detail=auto", "--run-ticks=1"]))
	assert_eq(parsed["errors"], PackedStringArray())
	assert_false(parsed["config"].has("crowd_detail"), "the test-mode script format doesn't change")


# @test-link [[req_offscreen_simulation]]
# @test-link [[rule_crowd_detail_only_under_load]]
func test_normal_play_runs_auto_from_0() -> void:
	var game := _game()
	assert_null(game.test_mode)
	assert_eq(game.crowd_detail_mode(), LoadMeter.AUTO)
	game.step_simulation()
	assert_eq(game.simulation.offscreen.detail_ceiling, 0, "a good device keeps full rings")
	game.load_meter.ceiling = 3
	game.step_simulation()
	assert_eq(game.simulation.offscreen.detail_ceiling, 3, "handed over at the next tick")
	game.restart_fresh()
	assert_eq(game.load_meter.ceiling, 0, "a new simulation starts again at 0")


func test_a_bad_value_is_an_error_and_sets_nothing() -> void:
	var game := _game()
	var use: Dictionary = game.use_crowd_detail(PackedStringArray(["--crowd-detail=sometimes"]))
	assert_eq(use["errors"].size(), 1)
	assert_eq(game.crowd_detail, "")
	assert_eq(game.use_crowd_detail(PackedStringArray(["--seed=1"])), {"line": "", "errors": PackedStringArray()})


func test_a_release_build_ignores_the_flag() -> void:
	var game := _game(false)
	var use: Dictionary = game.use_crowd_detail(PackedStringArray(["--crowd-detail=off"]))
	assert_eq(use["line"], load("res://src/main.gd").CROWD_DETAIL_IGNORED)
	assert_eq(use["errors"], PackedStringArray())
	assert_eq(game.crowd_detail_mode(), LoadMeter.AUTO, "a release build is always auto")
