extends GutTest
## The game root loads the test level in a debug build (a release build has
## no test level: levels/test/ is left out of release exports), puts a plain
## camera on the start basin, and hands the level's plain data to the
## simulation.

# @test-link [[req_test_level_and_test_mode]]

const MAIN_SCENE := "res://src/main.tscn"


func _boot(is_debug_build := true) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	add_child_autofree(game)
	return game


func test_a_debug_run_loads_the_test_level() -> void:
	var game := _boot()
	assert_not_null(game.level)
	assert_eq(game.level.level_id, "test")
	assert_eq(game.level.load_errors, PackedStringArray())


func test_the_camera_starts_on_the_start_basin() -> void:
	var game := _boot()
	var camera: Camera2D = game.camera
	assert_not_null(camera)
	var first_slime_at: Vector2 = game.level.position_of(game.level.find("start.first-slime"))
	assert_lt(camera.position.distance_to(first_slime_at), LevelData.SCREEN / 2.0)


func test_the_simulation_gets_the_level_data() -> void:
	var game := _boot()
	assert_eq(game.simulation.level, game.level.data)
	assert_eq(game.simulation.dump()["level"], {"id": "test", "version": game.level.level_version})


func test_test_mode_keeps_the_level() -> void:
	var game := _boot()
	assert_eq(game.enable_test_mode({"seed": 5, "time_scale": 0}), PackedStringArray())
	assert_eq(game.simulation.level, game.level.data)


func test_a_release_build_has_no_test_level() -> void:
	var game := _boot(false)
	assert_null(game.level)
	assert_null(game.simulation.level)
	assert_eq(game.simulation.dump()["level"], null)
