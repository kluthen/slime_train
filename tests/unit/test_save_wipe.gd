extends GutTest
## The save wipe (chunk 19w, D148, D149): with --wipe-save on the command
## line, a debug build deletes every file in the level saves' directory at
## launch, before anything reads a save, and keeps the parent code
## (parent.json and its backup, outside that directory). For automated test
## runs only. A release build ignores the flag (one log line, nothing
## deleted); a launch that also names a save to start from (--load=PATH, or a
## test script's "load") is refused: nothing deleted, the error that makes a
## debug launch quit with exit code 1. Only the main scene's default
## directory (user://saves/) is wiped: a store a test gives never is.
##
## Every test here works on a scratch directory: the game root's
## wipe_saves() takes its directory, and a game a test adds wipes only the
## directory it is given (save_wipe_directory). This is the flag's own test
## file, the one file under tests/ the guard test below lets name it.

const MAIN_SCENE := "res://src/main.tscn"
const ROOT := "user://test-save-wipe/"
const DIR := ROOT + "saves/"
const PARENT := ROOT + "parent.json"
const SCRIPT := ROOT + "script.json"
const FLAG := "--wipe-save"
const LEVEL := "test"
const PERF_SH := "res://tools/android/perf.sh"
const EXPORT_PRESETS := "res://export_presets.cfg"
const WIPE_FILE := "src/debug/save_wipe.gd"
const OWN_FILE := "res://tests/unit/test_save_wipe.gd"
## Every kind of file the saves' directory holds: two levels' saves and
## backups, side files, set-aside files and a version copy.
const SAVE_FILES := ["test.json", "test.json.bak", "test.json.new", "test.json.bak.new",
		"test.json.unreadable", "test.json.unreadable.2", "test.json.bak.unreadable", "test.json.v1",
		"meadow.json", "meadow.json.bak"]


func before_each() -> void:
	_clear(ROOT)


func after_all() -> void:
	_clear(ROOT)


## Tests may delete their own scratch files. Writable first: a test that
## made a directory read-only and stopped half-way may have left it so.
func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(path),
			FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	for sub in DirAccess.get_directories_at(path):
		_clear(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## Lays `text` down as the file at `path` (its directory made).
func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Every file of SAVE_FILES in DIR, and the parent code and its backup beside
## it, each holding its own name.
func _lay_out_files() -> void:
	for file in SAVE_FILES:
		_put(DIR + file, file)
	_put(PARENT, "parent")
	_put(PARENT + ".bak", "parent backup")


## The bytes of every file in `dir` and of the parent code files, by path.
func _snapshot(dir := DIR) -> Dictionary:
	var out := {}
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			out[dir + file] = FileAccess.get_file_as_bytes(dir + file)
	for path in [PARENT, PARENT + ".bak"]:
		if FileAccess.file_exists(path):
			out[path] = FileAccess.get_file_as_bytes(path)
	return out


## A game with an explicit guard, added to the tree (no store, no wipe of
## its own: a game a test adds has no wipe directory).
func _game_with_guard(is_debug_build: bool) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	add_child_autofree(game)
	return game


## A save of level LEVEL in DIR, played a little and with the hint done, as a
## real game writes it (with its backup: two writes).
func _write_played_save() -> Dictionary:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = SaveStore.new(DIR)
	add_child_autofree(game)
	game.simulation.run(60)
	game.simulation.hint.called()
	assert_eq(game.save_now(), "")
	game.simulation.run(60)
	assert_eq(game.save_now(), "")
	game.autosave.enabled = false
	assert_true(FileAccess.file_exists(DIR + "test.json.bak"), "a backup too")
	return {"tick": game.simulation.tick, "bytes": FileAccess.get_file_as_bytes(DIR + "test.json")}


# --- The wipe ---------------------------------------------------------------------

# @test-link [[req_test_level_and_test_mode]]
func test_the_flag_wipes_every_file_and_keeps_the_parent_code() -> void:
	_lay_out_files()
	var parent_before := _snapshot(ROOT + "nowhere/")
	var game := _game_with_guard(true)
	var result: Dictionary = game.wipe_saves(PackedStringArray([FLAG]), DIR)
	assert_eq(result["refusal"], "")
	assert_eq(result["errors"], PackedStringArray())
	assert_eq(DirAccess.get_files_at(DIR), PackedStringArray(), "every file in the directory deleted")
	assert_eq(_snapshot(ROOT + "nowhere/"), parent_before, "parent.json and its backup untouched")
	assert_eq(result["log"], PackedStringArray([
			"Save wipe (--wipe-save): deleted %d files from %s; parent.json kept." % [SAVE_FILES.size(), DIR]]),
			"one line with the count")


# @test-link [[req_test_level_and_test_mode]]
func test_without_the_flag_every_file_stays_byte_identical() -> void:
	_lay_out_files()
	var before := _snapshot()
	var game := _game_with_guard(true)
	var result: Dictionary = game.wipe_saves(PackedStringArray(["--seed=1", "--perf-log"]), DIR)
	assert_eq(result, {"refusal": "", "log": PackedStringArray(), "errors": PackedStringArray()})
	assert_eq(_snapshot(), before)


# @test-link [[req_test_level_and_test_mode]]
func test_an_empty_or_missing_directory_wipes_nothing_and_says_so() -> void:
	var game := _game_with_guard(true)
	var result: Dictionary = game.wipe_saves(PackedStringArray([FLAG]), DIR)
	assert_eq(result["log"], PackedStringArray([
			"Save wipe (--wipe-save): deleted 0 files from %s; parent.json kept." % DIR]))
	assert_eq(result["errors"], PackedStringArray())


## A file that can't be deleted is named in an error line, and the launch
## carries on (no refusal).
# @test-link [[req_test_level_and_test_mode]]
func test_a_file_that_cant_be_deleted_gets_an_error_line_and_the_launch_carries_on() -> void:
	_put(DIR + "test.json", "save")
	var dir := ProjectSettings.globalize_path(DIR)
	var mode := FileAccess.get_unix_permissions(dir)
	FileAccess.set_unix_permissions(dir, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	var game := _game_with_guard(true)
	var result: Dictionary = game.wipe_saves(PackedStringArray([FLAG]), DIR)
	FileAccess.set_unix_permissions(dir, mode)
	assert_eq(result["refusal"], "", "not refused: the launch carries on")
	assert_eq(result["errors"].size(), 1)
	assert_string_contains(result["errors"][0] if not result["errors"].is_empty() else "", DIR + "test.json")
	assert_eq(result["log"], PackedStringArray([
			"Save wipe (--wipe-save): deleted 0 files from %s; parent.json kept." % DIR]))
	assert_true(FileAccess.file_exists(DIR + "test.json"))


# @test-link [[rule_saves_never_wiped]]
func test_a_release_build_ignores_the_flag_and_deletes_nothing() -> void:
	_lay_out_files()
	var before := _snapshot()
	var game := _game_with_guard(false)
	var result: Dictionary = game.wipe_saves(PackedStringArray([FLAG]), DIR)
	assert_eq(result["log"], PackedStringArray(["Save wipe: --wipe-save ignored, not a debug build."]))
	assert_eq(result["refusal"], "")
	assert_eq(_snapshot(), before, "nothing deleted")
	# With a save to load as well: both flags are a release build's to ignore.
	result = game.wipe_saves(PackedStringArray([FLAG, "--load=" + DIR + "test.json"]), DIR)
	assert_eq(result["refusal"], "", "no refusal: the release build ignores both")
	assert_eq(_snapshot(), before)


# --- With a save to load: refused -------------------------------------------------

# @test-link [[req_test_level_and_test_mode]]
func test_with_load_the_wipe_is_refused_and_nothing_deleted() -> void:
	_lay_out_files()
	var before := _snapshot()
	var game := _game_with_guard(true)
	var result: Dictionary = game.wipe_saves(
			PackedStringArray(["--test-mode", FLAG, "--load=" + DIR + "test.json"]), DIR)
	assert_ne(result["refusal"], "", "the error that makes a debug launch quit with exit code 1")
	assert_string_contains(result["refusal"], "--load")
	assert_eq(result["log"], PackedStringArray())
	assert_eq(_snapshot(), before, "nothing deleted")


# @test-link [[req_test_level_and_test_mode]]
func test_with_a_test_script_holding_load_the_wipe_is_refused() -> void:
	_lay_out_files()
	_put(SCRIPT, JSON.stringify({"seed": 1, "load": DIR + "test.json"}))
	var before := _snapshot()
	var game := _game_with_guard(true)
	var result: Dictionary = game.wipe_saves(
			PackedStringArray(["--test-mode", "--test-script=" + SCRIPT, FLAG]), DIR)
	assert_ne(result["refusal"], "")
	assert_string_contains(result["refusal"], SCRIPT)
	assert_eq(_snapshot(), before, "nothing deleted")


## Proposed: a test script that can't be read may name a save to load, so the
## wipe is refused too (test mode would refuse the run anyway).
# @test-link [[req_test_level_and_test_mode]]
func test_with_an_unreadable_test_script_the_wipe_is_refused() -> void:
	_lay_out_files()
	var before := _snapshot()
	var game := _game_with_guard(true)
	var result: Dictionary = game.wipe_saves(
			PackedStringArray(["--test-mode", "--test-script=" + ROOT + "missing.json", FLAG]), DIR)
	assert_ne(result["refusal"], "")
	assert_eq(_snapshot(), before, "nothing deleted")


## --fixture is no conflict (fixtures are res:// files), nor a test script
## without "load".
# @test-link [[req_test_level_and_test_mode]]
func test_a_fixture_or_a_script_without_load_is_no_conflict() -> void:
	_put(SCRIPT, JSON.stringify({"seed": 1, "fixture": "bump"}))
	var game := _game_with_guard(true)
	for args in [["--test-mode", "--fixture=bump", FLAG], ["--test-mode", "--test-script=" + SCRIPT, FLAG]]:
		_lay_out_files()
		var result: Dictionary = game.wipe_saves(PackedStringArray(args), DIR)
		assert_eq(result["refusal"], "", str(args))
		assert_eq(DirAccess.get_files_at(DIR), PackedStringArray(), "%s: wiped" % str(args))


# @test-link [[req_test_level_and_test_mode]]
func test_test_mode_accepts_the_flag() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.start_test_mode_from_args(PackedStringArray(["--test-mode", "--seed=1", FLAG])),
			PackedStringArray())
	assert_not_null(game.test_mode)


# --- At launch ----------------------------------------------------------------------

## Before any read: a game started with the flag on a directory holding a
## save starts fresh, the first-play hint due, every file gone.
# @test-link [[req_test_level_and_test_mode]]
func test_a_game_started_with_the_flag_starts_fresh() -> void:
	var saved := _write_played_save()
	assert_gt(saved["tick"], 0)
	_put(PARENT, "parent")
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = SaveStore.new(DIR)
	game.save_wipe_directory = DIR
	game.launch_args = PackedStringArray([FLAG])
	add_child_autofree(game)
	assert_null(game.test_mode, "normal play")
	assert_eq(game.simulation.tick, 0, "fresh, not resumed")
	assert_false(game.simulation.hint.done, "the first-play hint is due")
	assert_false(FileAccess.file_exists(DIR + "test.json"), "the save is gone")
	assert_false(FileAccess.file_exists(DIR + "test.json.bak"), "its backup too")
	assert_eq(FileAccess.get_file_as_string(PARENT), "parent", "the parent code kept")


## Only the default directory: a store a test gives is never wiped by the
## flag (a game a test adds has no wipe directory of its own).
# @test-link [[req_test_level_and_test_mode]]
func test_a_store_a_test_gives_is_never_wiped() -> void:
	var saved := _write_played_save()
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = SaveStore.new(DIR)
	game.launch_args = PackedStringArray([FLAG])
	add_child_autofree(game)
	assert_eq(game.save_wipe_directory, "", "a game a test adds wipes nothing")
	assert_eq(game.simulation.tick, saved["tick"], "resumed from the save")
	assert_eq(FileAccess.get_file_as_bytes(DIR + "test.json"), saved["bytes"], "untouched")
	assert_true(FileAccess.file_exists(DIR + "test.json.bak"))


# --- Guards -------------------------------------------------------------------------

## Save and restore tests never pass the flag (D148, 8): no file under
## tests/ (the test scripts included) or levels/*/fixtures/ names it, this
## file apart.
# @test-link [[req_persistence_and_saves]]
func test_no_test_fixture_or_test_script_names_the_flag() -> void:
	var files := _files("res://tests/")
	for level in DirAccess.get_directories_at("res://levels/"):
		files.append_array(_files("res://levels/".path_join(level).path_join("fixtures")))
	assert_gt(files.size(), 50, "the scan found too few files")
	assert_true(files.has("res://tests/e2e/scripts/save_call.json"), "the test scripts are scanned")
	assert_true(files.has("res://levels/test/fixtures/old-version.json"), "the fixtures are scanned")
	var offenders := PackedStringArray()
	for path in files:
		if path != OWN_FILE and FLAG in FileAccess.get_file_as_string(path):
			offenders.append(path)
	assert_eq(offenders, PackedStringArray())


## The release preset leaves the wipe's file out (src/debug/*), as it leaves
## out test mode: a release install never has it.
# @test-link [[req_test_level_and_test_mode]]
func test_the_release_preset_leaves_the_wipe_out() -> void:
	assert_true(FileAccess.file_exists("res://" + WIPE_FILE), "the wipe's file is where the filter expects it")
	var presets := ConfigFile.new()
	assert_eq(presets.load(EXPORT_PRESETS), OK)
	var release := ""
	for section in presets.get_sections():
		if presets.get_value(section, "name", "") == "Android release":
			release = section
	assert_ne(release, "", "an Android release preset")
	var excluded := false
	for pattern in str(presets.get_value(release, "exclude_filter", "")).split(","):
		excluded = excluded or WIPE_FILE.match(pattern.strip_edges())
	assert_true(excluded, "the release preset's exclude filter covers " + WIPE_FILE)


## perf.sh refuses --wipe-save with a fixture (a fixture run never reads the
## player's save): exit 2, before it looks for a device. Its acceptance with
## --free-play or --fixture=none needs a device and is checked by hand.
# @test-link [[req_test_level_and_test_mode]]
func test_perf_sh_refuses_the_flag_with_a_fixture() -> void:
	var script := ProjectSettings.globalize_path(PERF_SH)
	for args in [["--fixture=bump", FLAG], [FLAG]]:
		var output := []
		var code := OS.execute("bash", PackedStringArray([script] + args), output, true)
		assert_eq(code, 2, "%s: bad arguments" % str(args))
		assert_string_contains("\n".join(output), FLAG + " is refused with a fixture", "%s: says why" % str(args))


## Every file under `dir` (recursively), or none if it isn't there.
func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		out.append(dir.path_join(file))
	return out
