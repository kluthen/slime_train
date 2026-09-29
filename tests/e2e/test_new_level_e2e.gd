extends GutTest
## Chunk LD1: the new-level scaffolder (tools/new_level.gd), run as a child
## process as a designer runs it. A level of 2 sections is scaffolded under a
## unique test-only ID: the three files are written; a second run refuses
## and changes nothing (and so do an invalid ID, "test", a bad --sections
## and a level whose test is already there); the level loads with no
## errors, LevelCatalog lists it and test mode plays it; the level-rules
## checker finds no FAIL on it (behaviour runs included), nor on levels of 1
## and 4 sections (4 needs species A to F), and no warning: every section
## can fill its basket (LevelProgress, chunk LD3); and the level's generated
## test passes in a child GUT run, playing section 1 to its basket full.
##
## Every level and test this script makes (PREFIX) is removed after it, and
## any an earlier run left behind (a crash) before it.

# @test-link [[req_level_design_rules]]
# @test-link [[req_test_level_and_test_mode]]

const MAIN_SCENE := "res://src/main.tscn"
const SCAFFOLDER := "res://tools/new_level.gd"
## The prefix of the levels this script makes, for the clean-up.
const PREFIX := "zz-scaffold-"
const TESTS_DIR := "res://tests/e2e/levels/"

## The 2-section level's ID, and the first run's exit code and output.
var level_id := ""
var first_code := -1
var first_output := ""
## Whether this script made TESTS_DIR (then it removes it when empty).
var made_tests_dir := false


func before_all() -> void:
	_remove_stale()
	made_tests_dir = not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TESTS_DIR))
	level_id = "%s%d" % [PREFIX, Time.get_ticks_usec()]
	var run := _scaffold(["--id=" + level_id, "--sections=2"])
	first_code = run["code"]
	first_output = run["text"]


func after_all() -> void:
	_remove_stale()
	var tests_dir := ProjectSettings.globalize_path(TESTS_DIR)
	if made_tests_dir and DirAccess.dir_exists_absolute(tests_dir) and DirAccess.get_files_at(tests_dir).is_empty() \
			and DirAccess.get_directories_at(tests_dir).is_empty():
		DirAccess.remove_absolute(tests_dir)


# --- Running things -----------------------------------------------------------------

## Runs the scaffolder with `args`: {"code", "text" (its output)}.
func _scaffold(args: Array) -> Dictionary:
	return _godot(["-s", SCAFFOLDER, "--"] + args)


## Runs a headless Godot on the project with `args`: {"code", "text"}.
func _godot(args: Array) -> Dictionary:
	var all := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	all.append_array(PackedStringArray(args))
	var output := []
	var code := OS.execute(OS.get_executable_path(), all, output, true)
	return {"code": code, "text": "\n".join(output)}


## The files the scaffolder writes for level `id`.
static func _files(id: String) -> Array[String]:
	return [LevelCatalog.scene_path(id), LevelCatalog.fixtures_dir(id) + "fresh" + TestMode.SIDECAR_EXTENSION,
			_test_path(id)]


## Level `id`'s generated test script.
static func _test_path(id: String) -> String:
	return TESTS_DIR + "test_level_%s.gd" % id


## Level `id`'s scene, added to the test (it builds and bakes its terrain).
func _level(id: String) -> Level:
	var level: Level = load(LevelCatalog.scene_path(id)).instantiate()
	add_child_autofree(level)
	return level


## The full checker's results on level `id` (the load check first).
func _check(id: String) -> Array:
	var checker := LevelChecker.new(_level(id))
	var results := [checker.check_load()]
	results.append_array(checker.check_all())
	return results


## Asserts that `results` hold no FAIL, listing them when they do.
func _assert_no_fail(results: Array, what: String) -> void:
	var failed := results.filter(func(result): return result["status"] == LevelChecker.FAIL)
	assert_eq(failed.size(), 0, "%s: the checker's FAILs:\n%s" % [what, LevelChecker.format(failed)])


## Whether `text` holds `fragment`.
func _has(text: String, fragment: String) -> bool:
	return fragment in text


# --- The scaffolder ------------------------------------------------------------------

func test_the_scaffolder_writes_the_level_its_fixture_and_its_test() -> void:
	assert_eq(first_code, 0, first_output)
	for path in _files(level_id):
		assert_true(FileAccess.file_exists(path), "%s written" % path)
		assert_true(_has(first_output, path), "the output names %s" % path)
	assert_eq(DirAccess.get_files_at(LevelCatalog.dir_of(level_id)), PackedStringArray(["level.tscn"]),
			"no script in the level's folder (D6)")
	var sidecar = JSON.parse_string(FileAccess.get_file_as_string(_files(level_id)[1]))
	assert_true(sidecar is Dictionary and sidecar.get("save") == false and sidecar.get("description", "") != "",
			"the fresh fixture: %s" % [sidecar])
	var test_text := FileAccess.get_file_as_string(_test_path(level_id))
	assert_true(_has(test_text, 'const LEVEL_ID := "%s"' % level_id), "the test plays this level")
	assert_false(_has(test_text, "{{"), "no placeholder left")
	for step in ["tools/level.sh check --level=" + level_id, "tools/level.sh report --level=" + level_id,
			"-gselect=test_level_" + level_id,
			"--test-mode --level=%s --seed=1" % level_id]:
		assert_true(_has(first_output, step), "the next steps say: %s" % step)


func test_a_second_run_refuses_and_changes_nothing() -> void:
	var before := {}
	for path in _files(level_id):
		before[path] = FileAccess.get_md5(path)
	var run := _scaffold(["--id=" + level_id, "--sections=3"])
	assert_eq(run["code"], 1, run["text"])
	assert_true(_has(run["text"], "already exists"), run["text"])
	for path in _files(level_id):
		assert_eq(FileAccess.get_md5(path), before[path], "%s unchanged" % path)
	assert_eq(DirAccess.get_files_at(LevelCatalog.fixtures_dir(level_id)), PackedStringArray(["fresh.fixture.json"]))


func test_an_existing_test_alone_is_refused_too() -> void:
	var id := "%s%d-orphan" % [PREFIX, Time.get_ticks_usec()]
	var file := FileAccess.open(_test_path(id), FileAccess.WRITE)
	file.store_string("# a designer's test\n")
	file.close()
	var run := _scaffold(["--id=" + id])
	assert_eq(run["code"], 1, run["text"])
	assert_true(_has(run["text"], _test_path(id) + " already exists"), run["text"])
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LevelCatalog.dir_of(id))),
			"no level folder made")
	assert_eq(FileAccess.get_file_as_string(_test_path(id)), "# a designer's test\n", "the test untouched")


func test_bad_arguments_are_refused_with_what_to_do() -> void:
	var cases := [
		[["--id=Bad_Level"], "invalid level ID"],
		[["--id=test"], "is the test level"],
		[[], "--id=<id>"],
		[["--id=%s%d-x" % [PREFIX, Time.get_ticks_usec()], "--sections=0"], "--sections wants a number from 1 to 4"],
		[["--id=%s%d-y" % [PREFIX, Time.get_ticks_usec()], "--sections=5"], "--sections wants a number from 1 to 4"],
		[["--id=%s%d-z" % [PREFIX, Time.get_ticks_usec()], "--size=2"], "unknown argument"],
	]
	var levels_before := DirAccess.get_directories_at(LevelCatalog.LEVELS_DIR)
	for each in cases:
		var run := _scaffold(each[0])
		assert_eq(run["code"], 2, "%s: %s" % [each[0], run["text"]])
		assert_true(_has(run["text"], each[1]), "%s says '%s': %s" % [each[0], each[1], run["text"]])
		assert_true(_has(run["text"], "usage: "), "and the usage")
	assert_eq(DirAccess.get_directories_at(LevelCatalog.LEVELS_DIR), levels_before, "no level folder made")


# --- The level it writes -------------------------------------------------------------

func test_the_level_loads_and_the_catalog_lists_it() -> void:
	assert_true(level_id in LevelCatalog.ids(), "%s in %s" % [level_id, LevelCatalog.ids()])
	var level := _level(level_id)
	assert_eq(level.level_id, level_id)
	assert_eq(level.level_version, 1)
	assert_eq(level.load_errors, PackedStringArray())
	var ids := level.ids()
	for id in ["start.loop", "start.split-zone", "start.first-slime", "s1.loop", "s1.slide", "s1.sleeper.01",
			"s1.signpost", "s1.switch", "s1.basket", "s1.gate", "s2.loop", "s2.slide", "s2.sleeper.01", "s2.signpost",
			"s2.switch", "s2.basket"]:
		assert_has(ids, id)
	assert_does_not_have(ids, "s2.gate", "the last section has no gate")
	var gate_opener := {}
	for rule in level.data.rules:
		gate_opener[rule["then"]["object"]] = rule["when"]["object"]
	assert_eq(gate_opener, {"s1.gate": "s1.basket"},
			"basket 1 opens gate 1; the last basket opens nothing (its target is the celebration)")


func test_test_mode_plays_it() -> void:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": 1, "time_scale": 0, "level": level_id}), PackedStringArray())
	assert_eq(game.level.level_id, level_id)
	assert_eq(game.simulation.level, game.level.data)
	if game.test_mode != null:
		game.test_mode.run_ticks(600)
		assert_eq(game.simulation.train.stalled, [] as Array[Dictionary])


func test_the_checker_finds_no_fail() -> void:
	var results := _check(level_id)
	gut.p(LevelChecker.format(results))
	_assert_no_fail(results, "2 sections")
	assert_eq(LevelChecker.warning_count(results), 0, "no warning")


# @test-link [[rule_gate_opens_via_switch_basket_set]]
func test_every_sleeper_is_within_a_called_base_slimes_hop_and_every_section_progresses() -> void:
	# Chunk LD3: the first skeleton's sleepers sat on plates 174 to 186 px
	# over the loop, out of a called base slime's reach (about 133 px), so
	# section 1 couldn't fill its basket. Now each rests in a hollow on a
	# dip's rim, reached from the rim.
	var checker := LevelChecker.new(_level(level_id))
	for id in checker.data.sleepers:
		var at: Vector2 = checker.data.sleepers[id]["position"]
		assert_eq(LevelProgress.smallest_size(checker, LevelChecker.section_of(id), at), 1,
				"%s: a called base slime reaches it" % id)
	for section in LevelProgress.estimate(checker):
		assert_true(section["progresses"], str(section))
		assert_eq(section["unreached"], [], "section %d: every sleeper by then can be woken" % section["section"])


func test_one_and_four_sections_pass_the_checker() -> void:
	for sections in [1, 4]:
		var id := "%s%d-s%d" % [PREFIX, Time.get_ticks_usec(), sections]
		var run := _scaffold(["--id=" + id, "--sections=%d" % sections])
		assert_eq(run["code"], 0, run["text"])
		if run["code"] != 0:
			continue
		var level := _level(id)
		assert_eq(level.load_errors, PackedStringArray())
		var checker := LevelChecker.new(level)
		assert_eq(checker.sections().size(), sections)
		var results := [checker.check_load()]
		results.append_array(checker.check_all())
		_assert_no_fail(results, "%d sections" % sections)
		assert_eq(LevelChecker.warning_count(results), 0, "%d sections: every section can progress: %s"
				% [sections, LevelProgress.estimate(checker)])
		if sections == 4:
			var species := {}
			for sleeper in level.data.sleepers.values():
				species[sleeper["species"]] = true
			assert_eq(species.size(), Species.COUNT, "species A to F: %s" % [species.keys()])


func test_the_generated_test_passes() -> void:
	var run := _godot(["-s", "res://addons/gut/gut_cmdln.gd", "-gconfig=", "-gtest=" + _test_path(level_id),
			"-gexit", "-gdisable_colors"])
	assert_eq(run["code"], 0, run["text"])
	assert_true(_has(run["text"], "---- All tests passed! ----"), run["text"])
	var passed := RegEx.create_from_string("Passing Tests\\s+(\\d+)").search(run["text"])
	assert_not_null(passed, "a passing count in:\n%s" % run["text"])
	if passed != null:
		assert_eq(passed.get_string(1).to_int(), 6, "its six tests ran and passed (section 1 played to its basket "
				+ "full among them, chunk LD3)")


# --- Clean-up ---------------------------------------------------------------------------

## Removes every level folder and level test this script makes (PREFIX),
## this run's and any an earlier run left behind.
func _remove_stale() -> void:
	for name in DirAccess.get_directories_at(LevelCatalog.LEVELS_DIR):
		if name.begins_with(PREFIX):
			_remove_tree(ProjectSettings.globalize_path(LevelCatalog.dir_of(name)))
	var tests_dir := ProjectSettings.globalize_path(TESTS_DIR)
	if DirAccess.dir_exists_absolute(tests_dir):
		for file in DirAccess.get_files_at(tests_dir):
			if file.begins_with("test_level_" + PREFIX):
				DirAccess.remove_absolute(tests_dir.path_join(file))


## Removes the folder `path` (absolute) and everything in it.
func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
