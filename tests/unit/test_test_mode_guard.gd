extends GutTest
## Test mode must be unreachable in a release build. TestModeGuard is the one
## check; the game asks it before anything from test mode is loaded.

const MAIN_SCENE := "res://src/main.tscn"
const SRC_ROOT := "res://src/"
const TEST_MODE_DIR := "res://src/test_mode/"


func _game_with_guard(is_debug_build: bool) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	add_child_autofree(game)
	return game


func test_guard_refuses_a_release_build() -> void:
	assert_false(TestModeGuard.new(false).allows())


func test_guard_allows_a_debug_build() -> void:
	assert_true(TestModeGuard.new(true).allows())


func test_guard_for_this_build_follows_the_engine() -> void:
	assert_eq(TestModeGuard.for_this_build().allows(), OS.is_debug_build())


func test_test_mode_must_be_asked_for() -> void:
	assert_true(TestModeGuard.requested(PackedStringArray(["--seed=1", "--test-mode"])))
	assert_false(TestModeGuard.requested(PackedStringArray(["--seed=1"])))
	assert_false(TestModeGuard.requested(PackedStringArray()))


func test_release_game_refuses_test_mode() -> void:
	var game := _game_with_guard(false)
	var seed_before: int = game.simulation.rng.seed_value
	var errors: PackedStringArray = game.enable_test_mode({"seed": 1234})
	assert_false(errors.is_empty())
	assert_string_contains(errors[0], "not available")
	assert_null(game.test_mode)
	assert_eq(game.simulation.rng.seed_value, seed_before, "the running simulation is untouched")


func test_release_game_ignores_test_mode_flags() -> void:
	var game := _game_with_guard(false)
	var errors: PackedStringArray = game.start_test_mode_from_args(
			PackedStringArray(["--test-mode", "--seed=1"]))
	assert_false(errors.is_empty())
	assert_null(game.test_mode)
	assert_eq(game.simulation.tick, 0)


func test_debug_game_accepts_test_mode() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.enable_test_mode({"seed": 1234, "time_scale": 0}), PackedStringArray())
	assert_not_null(game.test_mode)
	assert_eq(game.simulation.rng.seed_value, 1234)


func test_code_outside_test_mode_never_names_it() -> void:
	# The game reaches test mode only by loading it by path after the guard,
	# so a release export can leave src/test_mode/ out entirely (chunk 20).
	var offenders := PackedStringArray()
	var pattern := RegEx.create_from_string("\\b(TestMode|TestModeScript|TestModeOverlay)\\b")
	for path in _gd_files(SRC_ROOT):
		if path.begins_with(TEST_MODE_DIR):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0]
			if pattern.search(code):
				offenders.append("%s:%d" % [path, i + 1])
	assert_eq(offenders, PackedStringArray())


func _gd_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		files.append_array(_gd_files(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			files.append(dir_path.path_join(file))
	return files
